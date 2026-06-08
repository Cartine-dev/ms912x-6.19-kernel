#!/bin/bash
set -euo pipefail

monitor_name='HDMI-A-3'
monitor_serial='207AZBZ77221'
# Modo fisico estavel neste LG via MS912X USB 2.0: 1280x720@60.
# Com transform,1, a area logica fica 720x1280 em x=3286, y=-100.
# Nao usar 1920x1080@30 aqui: o monitor aceita no driver, mas rejeita com "fora de escala".
monitor_mode_spec='1280x720@60,3286x-100,1,transform,1'
monitor_spec="$monitor_name,$monitor_mode_spec"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
timestamp="$(date +%Y%m%d-%H%M%S)"
capture_file="$state_dir/usb-monitor-manual-$timestamp.log"
hypr_log=""
hypr_log_start_line=0
renderer_pattern='No renderer attached|Can.t create renderer|Failed to initialize renderer|eglQueryDeviceStringEXT|EGL_BAD_PARAMETER'

mkdir -p "$state_dir"

if [[ -d "$runtime_dir/hypr" ]]; then
    hypr_log="$(
        find "$runtime_dir/hypr" -maxdepth 2 -type f -name hyprland.log -printf '%T@ %p\n' 2>/dev/null \
            | sort -nr \
            | head -n 1 \
            | cut -d' ' -f2-
    )"
fi

if [[ -n "${hypr_log:-}" && -f "$hypr_log" ]]; then
    hypr_log_start_line="$(wc -l < "$hypr_log")"
fi

log_hypr_tail() {
    local label="$1"
    if [[ -n "${hypr_log:-}" && -f "$hypr_log" ]]; then
        printf '\n== hyprland log %s ==\n' "$label"
        grep -E "card0|card2|$monitor_name|$renderer_pattern|Starting backend|Modesetting" "$hypr_log" | tail -n 80 || true
    fi
}

ms912x_monitor_candidates() {
    awk -v serial="$monitor_serial" '
        function flush() {
            if (name ~ /^HDMI-A-[0-9]+$/ && (!serial || serial_seen))
                print name
        }

        /^Monitor / {
            if (name)
                flush()
            name = $2
            serial_seen = 0
        }

        /^[[:space:]]*serial:/ {
            value = $0
            sub(/^[[:space:]]*serial:[[:space:]]*/, "", value)
            if (value == serial)
                serial_seen = 1
        }

        END {
            if (name)
                flush()
        }
    '
}

select_ms912x_monitor() {
    local monitors="$1"
    local selected

    selected="$(
        ms912x_monitor_candidates <<<"$monitors" \
            | awk -F- '{print $3 " " $0}' \
            | sort -n \
            | awk 'END {print $2}'
    )"

    printf '%s\n' "${selected:-$monitor_name}"
}

new_renderer_errors() {
    [[ -n "${hypr_log:-}" && -f "$hypr_log" ]] || return 1
    local new_log
    new_log="$(tail -n +$((hypr_log_start_line + 1)) "$hypr_log")"
    # Erros EGL sao esperados no CPU fallback — so falhar se fallback nao confirmado
    if echo "$new_log" | grep -qE "$renderer_pattern"; then
        echo "$new_log" | grep -q "CPU copy fallback prepared" && return 1
        return 0  # erro real sem fallback
    fi
    return 1
}

{
    printf 'timestamp=%s\n' "$(date --iso-8601=seconds)"
    printf 'monitor_spec=%s\n' "$monitor_spec"
    printf 'hypr_log=%s\n' "${hypr_log:-not-found}"
    printf 'hypr_log_start_line=%s\n' "$hypr_log_start_line"

    printf '\n== hyprctl monitors before ==\n'
    monitors_before="$(hyprctl monitors all 2>&1 || true)"
    printf '%s\n' "$monitors_before"
    log_hypr_tail before

    monitor_name="$(select_ms912x_monitor "$monitors_before")"
    monitor_spec="$monitor_name,$monitor_mode_spec"
    printf '\nselected_monitor=%s\n' "$monitor_name"
    while read -r candidate; do
        [[ -n "$candidate" && "$candidate" != "$monitor_name" ]] || continue
        hyprctl keyword monitor "$candidate,disable" || true
    done < <(ms912x_monitor_candidates <<<"$monitors_before")

    printf '\n== manual activation ==\n'
    hyprctl keyword monitor "$monitor_spec" || true
    sleep 6

    printf '\n== hyprctl monitors after activation ==\n'
    hyprctl monitors all || true
    log_hypr_tail after-activation

    if new_renderer_errors; then
        printf '\n== new renderer errors detected; disabling %s ==\n' "$monitor_name"
        hyprctl keyword monitor "$monitor_name,disable" || true
        sleep 1
        printf '\n== hyprctl monitors after rollback ==\n'
        hyprctl monitors all || true
        log_hypr_tail after-rollback
    fi
} | tee "$capture_file"

printf '\nSaved log snapshot to %s\n' "$capture_file"
