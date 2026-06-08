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

For the known-good `linux-lts` baseline on `6.18.34-1-lts`, build against the target kernel explicitly:

```bash
make clean KVER=6.18.34-1-lts
make KVER=6.18.34-1-lts
sudo dkms remove ms912x/0.1 --all
sudo dkms install . -k 6.18.34-1-lts
sudo depmod 6.18.34-1-lts
modinfo ms912x | grep vermagic
```

Expected `vermagic`: `6.18.34-1-lts`

Known-good boot/runtime check:

```bash
uname -r
pacman -Q linux-lts
modinfo ms912x | rg 'filename|vermagic'
```

Expected output:

```text
6.18.34-1-lts
linux-lts 6.18.34-1
filename:       /lib/modules/6.18.34-1-lts/updates/dkms/ms912x.ko.zst
vermagic:       6.18.34-1-lts SMP preempt mod_unload
```

---

## Aquamarine patch (Hyprland)

This branch includes a patch for `aquamarine` to support the `ms912x` DRM backend via CPU copy fallback (`drm_dumb` buffers).

For this Hyprland setup, the patched Aquamarine package is part of the known-good baseline. The MS912X DRM device may not provide a renderer usable for normal blitting, so Hyprland must be able to fall back to CPU copy into `drm_dumb` scanout buffers.

Known-good package baseline:

```text
aquamarine 0.12.0-2
hyprland 0.55.2-2
linux-lts 6.18.34-1
```

### Build patched aquamarine package

Build from a temporary packaging directory. The file in this repo is named `aquamarine-PKGBUILD` so it does not conflict with the kernel driver's own build files.

```bash
mkdir -p /tmp/aquamarine-ms912x-pkg-0.12.0
cp aquamarine-PKGBUILD /tmp/aquamarine-ms912x-pkg-0.12.0/PKGBUILD
cp aquamarine-ms912x-cpu-fallback.patch /tmp/aquamarine-ms912x-pkg-0.12.0/
cd /tmp/aquamarine-ms912x-pkg-0.12.0
makepkg -si
```

> The patch enables `CPU copy fallback` for secondary DRM devices (card0) without a direct EGL renderer.
> EGL errors (`eglQueryDeviceStringEXT`, `Can't create renderer`) are **expected and normal** on this path.
> Restart Hyprland or reboot after installing: `libaquamarine` is loaded when the compositor starts.

### Verify patched aquamarine is installed

Check package identity:

```bash
pacman -Q aquamarine hyprland linux-lts
```

Check the installed library for the fallback strings:

```bash
strings /usr/lib/libaquamarine.so | rg 'CPU copy fallback'
```

Expected patched-path markers include:

```text
drm: initMgpu: no renderer on {}, enabling CPU copy fallback with drm_dumb buffers
drm: CPU copy fallback prepared a scanout buffer on {}
```

Failure split:

- `CPU copy fallback prepared` in the Hyprland log means the patched path is active and the secondary DRM backend has a prepared scanout buffer.
- `Can't create renderer` or `Failed to initialize renderer backend for blitting` without a later CPU fallback success means the patched package is missing, was replaced, or Hyprland is not loading it.
- `aquamarine-PKGBUILD` is the canonical rebuild source for this repo. Keep it aligned with the repo-supported patched workflow: `pkgver=0.12.0`, `pkgrel=2`, and `provides=("libaquamarine.so=11-64")`.

Runtime log check:

```bash
rg 'CPU copy fallback|Failed to initialize renderer backend for blitting|Can.t create renderer' /run/user/1000/hypr/*/hyprland.log | tail -n 80
```

Expected successful runtime behavior is repeated scanout preparation lines like:

```text
DEBUG from aquamarine ]: drm: CPU copy fallback prepared a scanout buffer on /dev/dri/card0
```

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
| `~/.config/hypr/scripts/activate-usb-monitor.sh` | Activate USB monitor post-login | Selects the current MS912X connector by serial, applies `1280x720@60`, waits for CPU fallback |
| `~/.local/bin/ms912x-reconnect.sh` | Hotplug/replug watcher action | Re-applies the known-good mode after udev trigger, even if `HDMI-A-3` renumbered to `HDMI-A-4` |

Only two scripts are used for the current workflow:

- `scripts/hypr/activate-usb-monitor.sh` -> install to `~/.config/hypr/scripts/activate-usb-monitor.sh`
- `scripts/ms912x-reconnect.sh` -> install to `~/.local/bin/ms912x-reconnect.sh`

Older helper wrappers are intentionally not part of the current documented flow. Use the two scripts above directly so there is one activation path and one hotplug recovery path.

### monitors.conf (reference layout)

3-monitor setup: notebook (left) → HDMI via GPU (center) → USB→HDMI (right), rotated vertically:

```ini
# eDP-1:    1366x768  → x=0,    y=156  (center offset: (1080-768)/2)
# HDMI-A-1: 1920x1080 → x=1366, y=0
# HDMI-A-3: 1280x720@60 physical → x=3286, y=-100, transform,1
#           With transform,1, logical area becomes 720x1280.
#           Do not use 1920x1080@30 here: it causes "fora de escala" on this LG via MS912X USB 2.0.
# HDMI-A-4: may appear after USB/DRM churn; keep disabled at boot,
#           but recovery scripts may activate it if it becomes the current MS912X connector.

monitor = eDP-1,    1366x768@60,  0x156,   1
monitor = HDMI-A-1, 1920x1080@60, 1366x0,  1
monitor = HDMI-A-3, disable
monitor = HDMI-A-4, disable
```

### autostart.conf

```ini
exec-once = sleep 8 && ~/.config/hypr/scripts/activate-usb-monitor.sh
```

Install the activation script:

```bash
install -Dm755 scripts/hypr/activate-usb-monitor.sh ~/.config/hypr/scripts/activate-usb-monitor.sh
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

After USB/DRM churn the same physical LG/MS912X output may come back as `HDMI-A-4` instead of `HDMI-A-3`. The activation script detects the current connector by monitor serial (`207AZBZ77221`) and applies the same safe mode to the highest matching `HDMI-A-N` connector.

Use this first if the repo assets were just added but not installed yet. Files under this repository do not affect the live system until the udev rule is copied to `/etc/udev/rules.d/` and the user watcher is enabled. In that state, a blank `HDMI-A-3` is still the normal manual-activation case, not evidence that hotplug recovery failed.

### Hotplug/replug recovery path

If the monitor works at boot or after manual activation but blanks a few seconds later, the likely failure is MS912X DRM device churn: the USB adapter disappears/reappears, the kernel may temporarily renumber it as a different card, and Hyprland loses the secondary output state. The driver mode should stay unchanged for this failure model.

This repo includes reference assets for manual installation:

| Repo file | Manual install target | Purpose |
|---|---|---|
| `udev/99-ms912x-hotplug.rules` | `/etc/udev/rules.d/99-ms912x-hotplug.rules` | Detect MS912X DRM add/change events and touch `/tmp/ms912x-reconnect-pending` |
| `scripts/ms912x-reconnect.sh` | User or system executable path | Run in the desktop user session, watch the trigger, and re-apply Hyprland monitor state |

The udev rule intentionally does not call `hyprctl` as root. It only updates a trigger file timestamp. The reconnect script should run as the desktop user so it can find the active Hyprland socket, wait for the DRM device to settle, select the current MS912X connector by serial, disable stale MS912X connector names, and re-apply:

```bash
<current-HDMI-A-N>,1280x720@60,3286x-100,1,transform,1
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
- The user watcher should notice that trigger and re-apply `1280x720@60,3286x-100,1,transform,1` to the current MS912X connector without manual intervention.
- If a replug renumbers the adapter, `HDMI-A-4` may be the real current output and `HDMI-A-3` may be stale. In that case the watcher should activate `HDMI-A-4` and disable stale MS912X connector names.

Manual one-shot recovery without udev:

```bash
scripts/ms912x-reconnect.sh --once manual
```

Logs are written to:

```text
~/.local/state/ms912x-reconnect.log
```

The log distinguishes Hyprland not running, missing patched Aquamarine fallback strings, missing selected connector, stale MS912X connector disable attempts, and whether the known-good monitor spec was applied.

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
| `HDMI-A-4` appears after replug | MS912X DRM card renumbered; `HDMI-A-4` may be the current connector, while `HDMI-A-3` may be stale | Run `scripts/ms912x-reconnect.sh --once manual`; it should select the highest matching MS912X connector by serial |
| Monitor works, then blanks a few seconds later | MS912X DRM remove/add or change event during session | Install the reference udev trigger and run `ms912x-reconnect.sh --watch` as the Hyprland user |
| Logs show `card0` removed or the adapter returns as `card3` | Kernel DRM card numbers churned after USB replug | Use `/dev/dri/by-path/...usb...-card` for diagnostics; scripts should select the current `HDMI-A-N` by serial |
| Reconnect script logs Aquamarine fallback absent | Patched `aquamarine` was replaced or is not loaded | Rebuild and reinstall from `aquamarine-PKGBUILD`, then restart Hyprland |
| Reconnect script applies a connector but there is still no image | Connector exists, but fallback scanout did not become usable | Check Hyprland logs for `CPU copy fallback prepared`; check `journalctl` for MS912X USB/DRM churn |
| `preferred` resolution freezes USB | Chip selects `1680x1050`, exceeds USB 2.0 bandwidth | Always use explicit `1280x720@60` |
| ABI mismatch on `pacman -U` | SONAME/provides mismatch between patched and installed Aquamarine/Hyprland | Rebuild with `provides=("libaquamarine.so=11-64")` for Hyprland `0.55.2-2` |

Useful diagnostics:

```bash
ls -l /dev/dri/by-path/*usb*-card
journalctl --user -u ms912x-reconnect.service -b
journalctl -b | grep -iE 'ms912x|534d|6021|345f|9132|drm'
rg 'CPU copy fallback|Failed to initialize renderer backend for blitting|Can.t create renderer' /run/user/1000/hypr/*/hyprland.log | tail -n 80
hyprctl monitors all
```

The `/dev/dri/by-path/...usb...-card` symlink is useful for confirming which DRM card belongs to the USB adapter after renumbering. Hyprland still addresses the output by connector name, but the connector name can move from `HDMI-A-3` to `HDMI-A-4`; the scripts choose the current connector by monitor serial and then apply `1280x720@60,3286x-100,1,transform,1`.
