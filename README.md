# ms912x driver for Linux

Linux kernel driver for MacroSilicon USB to VGA/HDMI adapter.

There are two variants:
 - VID/PID is `534d:6021` — USB 2.0
 - VID/PID is `345f:9132` — USB 3.0

- Improved performance and driver adaptation for Linux kernel 6.15+ by Andrey Rodríguez Araya

### Branches by kernel version

| Branch | Kernel |
|---|---|
| `kernel-6.19-lts-hypr-stability` | 6.18.x-lts (Arch linux-lts) |
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

### Build patched aquamarine package

```bash
cp aquamarine-PKGBUILD /tmp/PKGBUILD
cd /tmp
makepkg -si --noconfirm
```

> The patch enables `CPU copy fallback` for secondary DRM devices (card0) without a direct EGL renderer.
> EGL errors (`eglQueryDeviceStringEXT`, `Can't create renderer`) are **expected and normal** on this path.

---

## Hyprland configuration (Omarchy)

### Known working resolution

For the USB 2.0 `534d:6021` adapter with LG 22BN550Y:

- ✅ `1280x720@60` — works reliably
- ✅ `1920x1080@30` — driver accepts but monitor rejects (hsync out of range via USB 2.0)
- ❌ `preferred` / `1680x1050` — freezes USB bus

### Files to configure outside this repo

| File | Purpose | Key setting |
|---|---|---|
| `~/.config/hypr/monitors.conf` | Monitor layout at boot | `eDP-1`, `HDMI-A-1` positions; `HDMI-A-3` starts disabled |
| `~/.config/hypr/autostart.conf` | Autostart USB monitor | `exec-once = sleep 8 && ~/.config/hypr/scripts/activate-usb-monitor.sh` |
| `~/.config/hypr/scripts/activate-usb-monitor.sh` | Activate USB monitor post-login | `monitor_spec`, `sleep 6`, CPU fallback detection |

### monitors.conf (reference layout)

3-monitor setup: notebook (left) → HDMI via GPU (center) → USB→HDMI (right), vertically centered:

```ini
# eDP-1:    1366x768  → x=0,    y=156  (center offset: (1080-768)/2)
# HDMI-A-1: 1920x1080 → x=1366, y=0
# HDMI-A-3: 1280x720  → x=3286, y=180  (center offset: (1080-720)/2, activated by script)
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
2. Runs `hyprctl keyword monitor "HDMI-A-3,1280x720@60,3286x180,1"`
3. Waits 6 seconds for CPU fallback to stabilize
4. Only rolls back if `CPU copy fallback prepared` was **not** logged (real failure)

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Monitor no signal after script | `sleep` too short, fallback not ready | Increase `sleep 6` → `sleep 8` in script |
| Script rolls back after activation | `new_renderer_errors()` triggered before fallback confirmed | Check `sleep 6` is present in script |
| `HDMI-A-4` appears after replug | Ghost connector from kernel after rmmod/modprobe without USB replug | `hyprctl keyword monitor "HDMI-A-4,disable"` |
| `preferred` resolution freezes USB | Chip selects `1680x1050`, exceeds USB 2.0 bandwidth | Always use explicit `1280x720@60` |
| ABI mismatch on `pacman -U` | SONAME/pkgrel mismatch between patched and installed aquamarine | Rebuild with correct `pkgrel`, check `SOVERSION 10` in CMakeLists.txt |
