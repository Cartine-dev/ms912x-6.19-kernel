# ms912x driver for Linux

Linux kernel driver for MacroSilicon USB to VGA/HDMI adapter.

There are two variants:
 - VID/PID is `534d:6021` — USB 2.0
 - VID/PID is `345f:9132` — USB 3.0

- Improved performance and driver adaptation for Linux kernel 6.15+ by Andrey Rodríguez Araya

### Branches by kernel version

| Branch | Kernel |
|---|---|
| `kernel-6.18-lts-hypr-stability` | 6.18.x-lts (Arch linux-lts) |
| `kernel-6.16` | 6.16.x |
| `kernel-6.15` | 6.15.x |
| `kernel-6.12` | 6.12.x |
| `kernel-6.8` | 6.8 – 6.10 |

Forked from: https://github.com/rhgndf/ms912x

---

## TODOs

- Detect connector type (VGA, HDMI, etc.)
- More resolutions
- Error handling
- Is RGB to YUV conversion needed?

---

## Development

Driver is written by analyzing Wireshark captures of the device.

---

## Build & Install (manual)

```bash
make clean
make all -j
sudo rmmod ms912x        # Only if already loaded
sudo modprobe drm_shmem_helper
sudo insmod ms912x.ko
```

---

## DKMS (Arch linux-lts)

For `linux-lts` on `6.18.25-1-lts`, build against the target kernel explicitly:

```bash
make clean KVER=6.18.25-1-lts
make KVER=6.18.25-1-lts
sudo dkms remove ms912x/0.1 --all
sudo dkms install . -k 6.18.25-1-lts
sudo depmod 6.18.25-1-lts
modinfo ms912x | grep vermagic
```

Expected `vermagic`: `6.18.25-1-lts`

---

## Aquamarine patch (Hyprland)

This branch includes a patch for `aquamarine` to support the `ms912x` DRM backend via CPU copy fallback (`drm_dumb` buffers).

For this Hyprland setup, the patched Aquamarine package is part of the known-good baseline. The MS912X DRM device may not provide a renderer usable for normal blitting, so Hyprland must be able to fall back to CPU copy into `drm_dumb` scanout buffers.

### Build patched aquamarine package

```bash
cp aquamarine-PKGBUILD /tmp/PKGBUILD
cd /tmp
makepkg -si --noconfirm
```

> The patch enables `CPU copy fallback` for secondary DRM devices (card0) without a direct EGL renderer.
> EGL errors (`eglQueryDeviceStringEXT`, `Can't create renderer`) are **expected and normal** on this path.

### Verify patched aquamarine is installed

Check package identity:

```bash
pacman -Qi aquamarine
pacman -Q aquamarine
```

Check the installed library for the fallback strings:

```bash
strings "$(pacman -Ql aquamarine | awk '/\.so/ {print $2; exit}')" | grep -iE 'cpu copy fallback|drm_dumb|dumb'
```

Expected patched-path markers include:

```text
drm: initMgpu: no renderer on {}, enabling CPU copy fallback with drm_dumb buffers
drm: CPU copy fallback prepared a scanout buffer on {}
```

Failure split:

- `CPU copy fallback prepared` in the Hyprland log means the patched path is active and the secondary DRM backend has a prepared scanout buffer.
- `Can't create renderer` or `Failed to initialize renderer backend for blitting` without a later CPU fallback success means the patched package is missing, was replaced, or Hyprland is not loading it.
- `aquamarine-PKGBUILD` is the canonical rebuild source for this repo. Keep its package identity aligned with the repo-supported patched workflow: `pkgver=0.11.0`, `pkgrel=3`, `provides=("aquamarine=${pkgver}")`, and `conflicts=(aquamarine)`.

---

## Hyprland configuration (Omarchy)

### Known working resolution

For the USB 2.0 `534d:6021` adapter with LG 22BN550Y:

- ✅ `1280x720@60` — works reliably
- ⚠️ `1920x1080@30` — driver accepts, but this LG rejects it via USB 2.0 (`hsync out of range` / `fora de escala`)
- ❌ `preferred` / `1680x1050` — freezes USB bus

### Files to configure outside this repo

| File | Purpose | Key setting |
|---|---|---|
| `~/.config/hypr/monitors.conf` | Monitor layout at boot | `eDP-1`, `HDMI-A-1` positions; `HDMI-A-3` starts disabled |
| `~/.config/hypr/autostart.conf` | Autostart USB monitor | `exec-once = sleep 8 && ~/.config/hypr/scripts/activate-usb-monitor.sh` |
| `~/.config/hypr/scripts/activate-usb-monitor.sh` | Activate USB monitor post-login | `monitor_spec`, `sleep 6`, CPU fallback detection |

### monitors.conf (reference layout)

3-monitor setup: notebook (left) → HDMI via GPU (center) → USB→HDMI (right), rotated vertically:

```ini
# eDP-1:    1366x768  → x=0,    y=156  (center offset: (1080-768)/2)
# HDMI-A-1: 1920x1080 → x=1366, y=0
# HDMI-A-3: 1280x720@60 physical → x=3286, y=-100, transform,1
#           With transform,1, logical area becomes 720x1280.
#           Do not use 1920x1080@30 here: it causes "fora de escala" on this LG via MS912X USB 2.0.
# HDMI-A-4: ghost connector from MS912X replug — always disable

monitor = eDP-1,    1366x768@60,  0x156,   1
monitor = HDMI-A-1, 1920x1080@60, 1366x0,  1
monitor = HDMI-A-3, disable
monitor = HDMI-A-4, disable
```

### autostart.conf

```ini
exec-once = sleep 8 && ~/.config/hypr/scripts/activate-usb-monitor.sh
```

### Activating the USB monitor manually

```bash
~/.config/hypr/scripts/activate-usb-monitor.sh
```

The script:
1. Captures the current hyprland log position
2. Runs `hyprctl keyword monitor "HDMI-A-3,1280x720@60,3286x-100,1,transform,1"`
3. Waits 6 seconds for CPU fallback to stabilize
4. Only rolls back if `CPU copy fallback prepared` was **not** logged (real failure)

Use this first if the repo assets were just added but not installed yet. Files under this repository do not affect the live system until the udev rule is copied to `/etc/udev/rules.d/` and the user watcher is enabled. In that state, a blank `HDMI-A-3` is still the normal manual-activation case, not evidence that hotplug recovery failed.

### Hotplug/replug recovery path

If the monitor works at boot or after manual activation but blanks a few seconds later, the likely failure is MS912X DRM device churn: the USB adapter disappears/reappears, the kernel may temporarily renumber it as a different card, and Hyprland loses the secondary output state. The driver mode should stay unchanged for this failure model.

This repo includes reference assets for manual installation:

| Repo file | Manual install target | Purpose |
|---|---|---|
| `udev/99-ms912x-hotplug.rules` | `/etc/udev/rules.d/99-ms912x-hotplug.rules` | Detect MS912X DRM add/change events and touch `/tmp/ms912x-reconnect-pending` |
| `scripts/ms912x-reconnect.sh` | User or system executable path | Run in the desktop user session, watch the trigger, and re-apply Hyprland monitor state |

The udev rule intentionally does not call `hyprctl` as root. It only updates a trigger file timestamp. The reconnect script should run as the desktop user so it can find the active Hyprland socket, wait for the DRM device to settle, disable the ghost `HDMI-A-4` connector if present, and re-apply:

```bash
HDMI-A-3,1280x720@60,3286x-100,1,transform,1
```

Manual install example:

```bash
sudo install -Dm644 udev/99-ms912x-hotplug.rules /etc/udev/rules.d/99-ms912x-hotplug.rules
sudo udevadm control --reload-rules
install -Dm755 scripts/ms912x-reconnect.sh ~/.local/bin/ms912x-reconnect.sh
```

User-service example:

```ini
# ~/.config/systemd/user/ms912x-reconnect.service
[Unit]
Description=MS912X Hyprland hotplug reconnect watcher

[Service]
ExecStart=%h/.local/bin/ms912x-reconnect.sh --watch
Restart=on-failure

[Install]
WantedBy=default.target
```

Enable it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now ms912x-reconnect.service
```

Confirm the watcher is running:

```bash
systemctl --user status ms912x-reconnect.service
```

Expected installed behavior:

- The current session may still need one manual activation with `~/.config/hypr/scripts/activate-usb-monitor.sh` if `HDMI-A-3` is blank before the watcher is installed.
- After the udev rule and user service are installed, accidental MS912X replug/churn should touch `/tmp/ms912x-reconnect-pending`.
- The user watcher should notice that trigger and re-apply `HDMI-A-3,1280x720@60,3286x-100,1,transform,1` without manual intervention.

Manual one-shot recovery without udev:

```bash
scripts/ms912x-reconnect.sh --once manual
```

Logs are written to:

```text
~/.local/state/ms912x-reconnect.log
```

The log distinguishes Hyprland not running, missing patched Aquamarine fallback strings, missing `HDMI-A-3`, ghost `HDMI-A-4` disable attempts, and whether the known-good monitor spec was applied.

### HDMI-A-3 vertical recovery note (2026-05-19)

If the LG connected through the MS912X adapter shows `fora de escala` after enabling vertical mode, keep the stable physical mode and rotate only in Hyprland:

```bash
hyprctl keyword monitor "HDMI-A-3,disable"
hyprctl keyword monitor "HDMI-A-3,1280x720@60,3286x-100,1,transform,1"
hyprctl monitors all
```

Expected `hyprctl monitors all` state for `HDMI-A-3`:

- `1280x720@60`
- `transform: 1`
- position `3286x-100`

The working persistent script setting is:

```bash
monitor_spec='HDMI-A-3,1280x720@60,3286x-100,1,transform,1'
```

Why this matters: adding `transform,1` to `1920x1080@30` reintroduced the monitor-side `fora de escala` failure. The driver may expose or accept `1920x1080@30`, but this LG/MS912X USB 2.0 setup is stable at `1280x720@60`. If the vertical orientation is inverted, change only `transform,1` to `transform,3`; keep `1280x720@60`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Repo assets added but monitor still blank | Assets are not installed into the live system yet | Run `~/.config/hypr/scripts/activate-usb-monitor.sh` for the current session, then install the udev rule and user service |
| Monitor no signal after script | `sleep` too short, fallback not ready | Increase `sleep 6` → `sleep 8` in script |
| Script rolls back after activation | `new_renderer_errors()` triggered before fallback confirmed | Check `sleep 6` is present in script |
| LG shows `fora de escala` on HDMI-A-3 | Script used `1920x1080@30` with rotation | Use `HDMI-A-3,1280x720@60,3286x-100,1,transform,1` |
| `HDMI-A-4` appears after replug | Ghost connector from kernel after rmmod/modprobe without USB replug | `hyprctl keyword monitor "HDMI-A-4,disable"` |
| Monitor works, then blanks a few seconds later | MS912X DRM remove/add or change event during session | Install the reference udev trigger and run `ms912x-reconnect.sh --watch` as the Hyprland user |
| Logs show `card0` removed or the adapter returns as `card3` | Kernel DRM card numbers churned after USB replug | Use `/dev/dri/by-path/...usb...-card` for diagnostics; keep Hyprland output config as `HDMI-A-3` |
| Reconnect script logs Aquamarine fallback absent | Patched `aquamarine` was replaced or is not loaded | Rebuild and reinstall from `aquamarine-PKGBUILD`, then restart Hyprland |
| Reconnect script applies HDMI-A-3 but there is still no image | Connector exists, but fallback scanout did not become usable | Check Hyprland logs for `CPU copy fallback prepared`; check `journalctl` for MS912X USB/DRM churn |
| `preferred` resolution freezes USB | Chip selects `1680x1050`, exceeds USB 2.0 bandwidth | Always use explicit `1280x720@60` |
| ABI mismatch on `pacman -U` | SONAME/pkgrel mismatch between patched and installed aquamarine | Rebuild with correct `pkgrel`, check `SOVERSION 10` in CMakeLists.txt |

Useful diagnostics:

```bash
ls -l /dev/dri/by-path/*usb*-card
journalctl --user -u ms912x-reconnect.service -b
journalctl -b | grep -iE 'ms912x|534d|6021|345f|9132|drm'
grep -i 'CPU copy fallback' ~/.cache/hyprland/hyprland.log
```

The `/dev/dri/by-path/...usb...-card` symlink is useful for confirming which DRM card belongs to the USB adapter after renumbering. Hyprland still addresses the output by connector name, so the monitor command remains `HDMI-A-3,1280x720@60,3286x-100,1,transform,1`.
