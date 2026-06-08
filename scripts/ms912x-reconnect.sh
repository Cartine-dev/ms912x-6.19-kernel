#!/usr/bin/env bash
set -u

# User-session watcher/one-shot recovery for MS912X Hyprland hotplug churn.
# udev should only create /tmp/ms912x-reconnect-pending; this script must run
# as the desktop user so hyprctl talks to the correct Hyprland instance.

TRIGGER_FILE="${MS912X_TRIGGER_FILE:-/tmp/ms912x-reconnect-pending}"
LOG_FILE="${MS912X_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/ms912x-reconnect.log}"
SETTLE_SECONDS="${MS912X_SETTLE_SECONDS:-4}"
MONITOR_MODE_SPEC="${MS912X_MONITOR_MODE_SPEC:-1280x720@60,3286x-100,1,transform,1}"
MONITOR_SERIAL="${MS912X_MONITOR_SERIAL:-207AZBZ77221}"
FALLBACK_MONITOR_NAME="${MS912X_MONITOR_NAME:-HDMI-A-3}"

log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG_FILE"
}

find_hypr_instance() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local instance=""

    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -S "$runtime_dir/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]]; then
        printf '%s\n' "$HYPRLAND_INSTANCE_SIGNATURE"
        return 0
    fi

    for sock in "$runtime_dir"/hypr/*/.socket.sock; do
        [[ -S "$sock" ]] || continue
        instance="${sock%/.socket.sock}"
        printf '%s\n' "${instance##*/}"
        return 0
    done

    return 1
}

hypr() {
    local instance="$1"
    shift

    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    HYPRLAND_INSTANCE_SIGNATURE="$instance" \
        hyprctl "$@"
}

aquamarine_fallback_present() {
    command -v pacman >/dev/null 2>&1 || return 2
    command -v strings >/dev/null 2>&1 || return 2

    while read -r _ path; do
        [[ -r "$path" && "$path" == *.so* ]] || continue
        local markers
        markers="$(strings "$path" 2>/dev/null || true)"
        if grep -q 'CPU copy fallback' <<<"$markers" && grep -q 'CPU copy fallback prepared' <<<"$markers"; then
            return 0
        fi
    done < <(pacman -Ql aquamarine 2>/dev/null)

    return 1
}

monitor_block() {
    local monitor_name="$1"

    awk -v monitor="$monitor_name" '
        /^Monitor / {
            in_block = ($2 == monitor)
        }
        in_block {
            print
        }
    '
}

ms912x_monitor_candidates() {
    awk -v serial="$MONITOR_SERIAL" '
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

    printf '%s\n' "${selected:-$FALLBACK_MONITOR_NAME}"
}

recover_once() {
    local trigger="${1:-manual}"
    local instance
    local monitors

    log "trigger: $trigger"
    sleep "$SETTLE_SECONDS"

    if ! instance="$(find_hypr_instance)"; then
        log "skip: Hyprland socket not found for user $(id -un)"
        return 0
    fi

    case "$(aquamarine_fallback_present; printf '%s' "$?")" in
        0) log "aquamarine: CPU copy fallback markers present" ;;
        1) log "aquamarine: CPU copy fallback markers absent; rebuild patched package from aquamarine-PKGBUILD" ;;
        2) log "aquamarine: fallback marker check skipped; pacman or strings unavailable" ;;
    esac

    if ! monitors="$(hypr "$instance" monitors all 2>&1)"; then
        log "fail: hyprctl monitors all failed: $monitors"
        return 1
    fi

    local monitor_name
    local monitor_spec
    monitor_name="$(select_ms912x_monitor "$monitors")"
    monitor_spec="$monitor_name,$MONITOR_MODE_SPEC"

    if ! grep -q "^Monitor $monitor_name" <<<"$monitors"; then
        log "fail: $monitor_name not present after hotplug; current connectors: $(grep '^Monitor ' <<<"$monitors" | tr '\n' ';')"
        return 1
    fi

    while read -r candidate; do
        [[ -n "$candidate" && "$candidate" != "$monitor_name" ]] || continue
        if hypr "$instance" keyword monitor "$candidate,disable" >>"$LOG_FILE" 2>&1; then
            log "stale: disabled $candidate"
        else
            log "warn: failed to disable stale $candidate"
        fi
    done < <(ms912x_monitor_candidates <<<"$monitors")

    if hypr "$instance" keyword monitor "$monitor_spec" >>"$LOG_FILE" 2>&1; then
        log "success: applied $monitor_spec"
    else
        log "fail: could not apply $monitor_spec"
        return 1
    fi

    sleep 2
    monitors="$(hypr "$instance" monitors all 2>&1 || true)"
    if monitor_block "$monitor_name" <<<"$monitors" | grep -Eq '^[[:space:]]*disabled:[[:space:]]*false[[:space:]]*$'; then
        log "verify: $monitor_name enabled after recovery"
    else
        log "warn: $monitor_name present but not verified enabled; connector may have no image"
    fi
}

watch_triggers() {
    local last_trigger_stamp=""

    log "watch: started for $TRIGGER_FILE"

    while true; do
        if [[ -e "$TRIGGER_FILE" ]]; then
            local trigger_stamp
            trigger_stamp="$(stat -c 'mtime=%y size=%s' "$TRIGGER_FILE" 2>/dev/null || true)"
            if [[ -n "$trigger_stamp" && "$trigger_stamp" != "$last_trigger_stamp" ]]; then
                last_trigger_stamp="$trigger_stamp"
                recover_once "udev trigger $trigger_stamp"
            fi
        fi
        sleep 2
    done
}

case "${1:---once}" in
    --watch)
        watch_triggers
        ;;
    --once)
        recover_once "${2:-manual}"
        ;;
    *)
        printf 'Usage: %s [--once [reason]|--watch]\n' "$0" >&2
        exit 2
        ;;
esac
