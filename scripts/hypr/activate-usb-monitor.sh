#!/bin/bash
set -euo pipefail

monitor_name='HDMI-A-3'
# Modo fisico estavel neste LG via MS912X USB 2.0: 1280x720@60.
# Com transform,1, a area logica fica 720x1280 em x=3286, y=-100.
# Nao usar 1920x1080@30 aqui: o monitor aceita no driver, mas rejeita com "fora de escala".
monitor_spec='HDMI-A-3,1280x720@60,3286x-100,1,transform,1'
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
    hyprctl monitors all || true
    log_hypr_tail before

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
