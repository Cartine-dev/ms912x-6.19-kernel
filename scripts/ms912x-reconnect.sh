#!/usr/bin/env bash
set -u

# User-session watcher/one-shot recovery for MS912X Hyprland hotplug churn.
# udev should only create /tmp/ms912x-reconnect-pending; this script must run
# as the desktop user so hyprctl talks to the correct Hyprland instance.

TRIGGER_FILE="${MS912X_TRIGGER_FILE:-/tmp/ms912x-reconnect-pending}"
LOG_FILE="${MS912X_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/ms912x-reconnect.log}"
SETTLE_SECONDS="${MS912X_SETTLE_SECONDS:-4}"
MONITOR_SPEC="${MS912X_MONITOR_SPEC:-HDMI-A-3,1280x720@60,3286x-100,1,transform,1}"
GHOST_SPEC="${MS912X_GHOST_SPEC:-HDMI-A-4,disable}"

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
        if strings "$path" 2>/dev/null | grep -qiE 'CPU copy fallback|drm_dumb'; then
            return 0
        fi
    done < <(pacman -Ql aquamarine 2>/dev/null)

    return 1
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

    if ! grep -q 'HDMI-A-3' <<<"$monitors"; then
        log "fail: HDMI-A-3 not present after hotplug; current connectors: $(grep '^Monitor ' <<<"$monitors" | tr '\n' ';')"
        return 1
    fi

    if grep -q 'HDMI-A-4' <<<"$monitors"; then
        if hypr "$instance" keyword monitor "$GHOST_SPEC" >>"$LOG_FILE" 2>&1; then
            log "ghost: disabled $GHOST_SPEC"
        else
            log "warn: failed to disable $GHOST_SPEC"
        fi
    else
        log "ghost: HDMI-A-4 absent"
    fi

    if hypr "$instance" keyword monitor "$MONITOR_SPEC" >>"$LOG_FILE" 2>&1; then
        log "success: applied $MONITOR_SPEC"
    else
        log "fail: could not apply $MONITOR_SPEC"
        return 1
    fi

    sleep 2
    monitors="$(hypr "$instance" monitors all 2>&1 || true)"
    if grep -A12 '^Monitor HDMI-A-3' <<<"$monitors" | grep -q 'disabled: false'; then
        log "verify: HDMI-A-3 enabled after recovery"
    else
        log "warn: HDMI-A-3 present but not verified enabled; connector may have no image"
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
