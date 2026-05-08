# Aquamarine MS912X CPU-Blit Fallback Plan

## Current State

- Running kernel target: `6.18.25-1-lts`
- Driver repo branch: `kernel-6.18-lts-hypr-stability`
- Kernel-side mode hardening is already in place:
  - `ms912x_drv.c` uses the validated `1920x1080@30` / `0x2200` path
  - `ms912x_transfer.c` keeps the frame limiter / timeout / full-frame fixes
  - `ms912x_connector.c` now exposes only a synthetic safe `1920x1080@30` mode
- Hyprland-side safety changes are already in place:
  - `~/.config/uwsm/env` exports:
    - `AQ_DRM_DEVICES=/dev/dri/card2:/dev/dri/card0`
    - `AQ_NO_MODIFIERS=1`
    - `AQ_MGPU_NO_EXPLICIT=1`
    - `AQ_NO_ATOMIC=1`
  - `~/.config/environment.d/90-aquamarine-drm.conf` no longer injects the old global `AQ_DRM_DEVICES`
  - `~/.config/hypr/monitors.conf` keeps `HDMI-A-3` disabled at login
  - `~/.config/hypr/scripts/activate-usb-monitor.sh` activates `HDMI-A-3` at `1920x1080@30` and rolls back only on new renderer errors

## What Is Already Proven

- DKMS/header mismatch was a real problem earlier, but it is no longer the main blocker.
- Hyprland/Aquamarine can now modeset the MS912X output at the safe mode.
- The remaining failure is after modeset:
  - Aquamarine logs: `CDRMRenderer(drm): Can't create renderer, no matching devices found`
- Root cause:
  - `card0` (`ms912x`) is a KMS output device with no EGL-capable render node
  - Aquamarine's multi-GPU path still tries to create a renderer for that secondary DRM device
  - Result: black screen on the USB monitor even though modesetting succeeds

## Conclusion

The next real repair is not another kernel patch. The next repair is an Aquamarine patch.

## Target Plan

### Stage 1: Cheap Config Check

Before patching source, run one last low-risk runtime check:

- test `AQ_FORCE_LINEAR_BLIT=1` in the Hyprland/Aquamarine environment
- optionally enable trace logging to confirm the exact failure path

If the logs still end in `Can't create renderer, no matching devices found`, continue to source patching.

### Stage 2: Patch Aquamarine 0.11.0

Target package:

- installed package: `aquamarine 0.11.0-2`
- keep ABI/package compatibility with installed `hyprland 0.54.3-4`

Implementation direction:

- patch Aquamarine's DRM backend multi-GPU path
- in `CDRMBackend::initMgpu()`, detect secondary DRM devices with no usable render node
- if `CDRMRenderer::attempt()` fails for such a device, do not fail the output outright
- use a CPU fallback for that device:
  - keep scanout on a dumb DRM buffer (`CDRMDumbAllocator`)
  - render on the primary i915 path
  - read back CPU-visible pixels from the primary rendered frame
  - copy CPU pixel data into the dumb buffer through `beginDataPtr()` / `endDataPtr()`
  - submit through the existing DRM framebuffer path

### Stage 3: Package and Install Correctly

- build a local Arch package with `makepkg`
- install via `pacman`, not by replacing shared libraries manually
- keep rollback simple by restoring the stock `aquamarine` package from pacman cache

## Expected Result

After a successful Aquamarine patch:

- `HDMI-A-3` enables without the repeated renderer failure
- the USB monitor shows real desktop content instead of staying black
- performance may remain modest, which is acceptable for the first working target

## Important Boundary

This repository contains the kernel driver, not Aquamarine itself.

So the work is now split into two tracks:

1. `ms912x-6.19-kernel` remains the driver source of record
2. Aquamarine patching must happen in a separate package source tree

## Next Practical Step

Create or fetch a local `aquamarine 0.11.0-2` package worktree, then implement and test the CPU-blit fallback there.
