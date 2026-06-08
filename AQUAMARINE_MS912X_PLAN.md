# Aquamarine MS912X CPU-Copy Fallback Result

## Current Known-Good Baseline

- Kernel: `linux-lts 6.18.34-1-lts`
- Driver module: `/lib/modules/6.18.34-1-lts/updates/dkms/ms912x.ko.zst`
- Aquamarine: patched `aquamarine 0.12.0-2`
- Hyprland: `0.55.2-2`
- USB monitor spec: `HDMI-A-3,1280x720@60,3286x-100,1,transform,1`

Validated runtime output:

```text
drm: CPU copy fallback prepared a scanout buffer on /dev/dri/card0
```

The LG monitor connected through the MS912X USB 2.0 adapter displays image again at the known-good `1280x720@60` physical mode with Hyprland rotation.

## What Was Fixed

The MS912X DRM device is a KMS output device without a usable EGL renderer/render node for Aquamarine's normal multi-GPU blit path. Before the patch, enabling the USB monitor led to repeated renderer failures:

```text
CDRMRenderer(drm): Can't create renderer, no matching devices found
drm: Failed to initialize renderer backend for blitting
```

The Aquamarine patch changes the secondary DRM backend behavior:

1. Try the normal renderer path first.
2. If the secondary backend has no renderer but has `drm_dumb` buffers and a primary renderer is available, enable CPU copy fallback.
3. Render/read from the primary renderer.
4. Copy RGBA pixels into a CPU-mapped `drm_dumb` scanout buffer.
5. Submit that buffer through the existing DRM framebuffer path.

Expected fallback markers:

```text
drm: initMgpu: no renderer on {}, enabling CPU copy fallback with drm_dumb buffers
drm: CPU copy fallback prepared a scanout buffer on {}
```

## Repository Artifacts

Canonical files for the current workflow:

| File | Purpose |
|---|---|
| `aquamarine-PKGBUILD` | Builds patched Aquamarine `0.12.0-2` from upstream tag `v0.12.0` |
| `aquamarine-ms912x-cpu-fallback.patch` | Rebased CPU copy fallback patch for Aquamarine `0.12.0` |
| `scripts/hypr/activate-usb-monitor.sh` | Manual/autostart Hyprland activation for `HDMI-A-3` |
| `scripts/ms912x-reconnect.sh` | User-session hotplug watcher action for MS912X DRM churn |
| `udev/99-ms912x-hotplug.rules` | Root-side udev trigger; touches `/tmp/ms912x-reconnect-pending` only |

The active scripts are only:

- `scripts/hypr/activate-usb-monitor.sh`
- `scripts/ms912x-reconnect.sh`

Older helper wrappers are intentionally not used in the current documented flow.

## Build And Install

Build the patched Aquamarine package from a temporary directory:

```bash
mkdir -p /tmp/aquamarine-ms912x-pkg-0.12.0
cp aquamarine-PKGBUILD /tmp/aquamarine-ms912x-pkg-0.12.0/PKGBUILD
cp aquamarine-ms912x-cpu-fallback.patch /tmp/aquamarine-ms912x-pkg-0.12.0/
cd /tmp/aquamarine-ms912x-pkg-0.12.0
makepkg -si
```

Restart Hyprland or reboot after installing the package. Rebooting into `linux-lts` is preferred because it also verifies the DKMS module target.

Install the live scripts:

```bash
install -Dm755 scripts/hypr/activate-usb-monitor.sh ~/.config/hypr/scripts/activate-usb-monitor.sh
install -Dm755 scripts/ms912x-reconnect.sh ~/.local/bin/ms912x-reconnect.sh
```

## Verification

```bash
uname -r
pacman -Q aquamarine hyprland linux-lts
modinfo ms912x | rg 'filename|vermagic'
strings /usr/lib/libaquamarine.so | rg 'CPU copy fallback'
hyprctl monitors all
rg 'CPU copy fallback|Failed to initialize renderer backend for blitting|Can.t create renderer' /run/user/1000/hypr/*/hyprland.log | tail -n 80
```

Expected:

- `uname -r` is `6.18.34-1-lts`
- `pacman -Q aquamarine` is `aquamarine 0.12.0-2`
- `modinfo ms912x` points under `/lib/modules/6.18.34-1-lts/updates/dkms/`
- `vermagic` is `6.18.34-1-lts`
- `HDMI-A-3` is `1280x720@60`, position `3286x-100`, `transform: 1`, `disabled: false`
- Hyprland log repeatedly shows `CPU copy fallback prepared a scanout buffer on /dev/dri/card0`

## Hotplug Renumbering Note

After USB/DRM churn, the MS912X card can disappear as `card0` and return as a higher DRM minor such as `card3`. Hyprland may then expose the same physical LG monitor as `HDMI-A-4` while the old `HDMI-A-3` entry remains stale.

The reconnect and activation scripts must not assume `HDMI-A-4` is always a ghost. They select the current MS912X connector by monitor serial (`207AZBZ77221`), prefer the highest matching `HDMI-A-N` name after renumbering, disable stale MS912X connector names, and apply:

```text
1280x720@60,3286x-100,1,transform,1
```

## Boundaries

- Keep `1280x720@60` for the USB monitor. Do not use `1920x1080@30` for this LG/MS912X USB 2.0 path; it causes monitor-side `fora de escala`.
- Do not manually replace shared libraries. Always install the patched Aquamarine package through `makepkg`/`pacman`.
- The udev rule must not run `hyprctl` as root. It only updates the trigger file; the user service performs Hyprland actions in the desktop session.
