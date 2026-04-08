<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# MS912X Driver Fix — Session Summary

## Context

You're running **Arch Linux (Omarchy)** with kernel **6.19**, trying to get a **MacroSilicon MS912X USB display adapter** (VID/PID `534d:6021`, USB 2.0) working as a second monitor on an LG screen.

***

## What We Did

### 1. Fork \& Setup

- Forked [`tiirwaa/ms912x`](https://github.com/tiirwaa/ms912x) (branch `kernel-6.16`) to [`https://github.com/Cartine-dev/ms912x-6.19-kernel`](https://github.com/Cartine-dev/ms912x-6.19-kernel)
- Cloned locally to `~/ms912x-6.19-kernel`
- Created branch `kernel-6.19-ms912x-fix`
- Working folder used for most edits ended up being `~/ms912x-fix` (a parallel copy)


### 2. Kernel 6.19 Compilation Fixes (`ms912x_drv.c`)

- Fixed `timer_container_of` API change
- Fixed `drm_gem_fb_begin_cpu_access` / `drm_gem_fb_end_cpu_access` deprecations
- Fixed other minor kernel API breakages — driver compiled and loaded successfully


### 3. Green Screen Investigation

The monitor was detected, lit up, but showed **solid green with interference pattern**. We tested:

- ❌ Swapping YUV byte order (UYVY → YUYV, YVYU)
- ❌ Changing `unsigned int` to `int` for YUV variables (was a valid bug but not the root cause)
- ✅ **Hardcoded white pixels still showed green** → proved the bug was NOT in color conversion


### 4. Root Cause Found

By reading [`crazedr0m/ms912x`](https://github.com/crazedr0m/ms912x)'s `re_notes/resolutions` hardware dump, we found:


| Mode in driver | Status |
| :-- | :-- |
| `MS912X_MODE(1920, 1080, 60, 0x8100)` | ❌ **Doesn't exist on hardware** |
| `MS912X_MODE(1920, 1080, 30, 0x2200)` | ✅ **Real hardware mode** |

The chip was receiving an invalid mode code `0x8100` and defaulting to green output.

### 5. Fix Applied

```c
// ms912x_drv.c — changed:
MS912X_MODE(1920, 1080, 60, 0x8100, MS912X_PIXFMT_UYVY)
// to:
MS912X_MODE(1920, 1080, 30, 0x2200, MS912X_PIXFMT_UYVY)
```

**After reboot — screen works! Image is correct, no more green!** 🎉

***

## Current Status

✅ Driver loads and displays correctly
⚠️ **Lag/latency** — cursor movement delayed on external monitor
⚠️ **Ghost cursors** — multiple cursor shadows appear during movement

## Next Fix (Pending)

Two timing bugs in `ms912x_transfer.c` identified but **not yet applied**:

```bash
# Fix 1: frame limiter — change 16ms (60fps) to 33ms (30fps)
sed -i 's/msecs_to_jiffies(16)/msecs_to_jiffies(33)/' ms912x_transfer.c

# Fix 2: USB completion timeout — change 1ms to 40ms
sed -i 's/msecs_to_jiffies(1))/msecs_to_jiffies(40))/' ms912x_transfer.c
```

Then rebuild:

```bash
sudo dkms remove ms912x/0.1 --all
sudo dkms install .
hyprctl dispatch exit
```


***

## Key Files

| File | Role |
| :-- | :-- |
| `~/ms912x-6.19-kernel/ms912x_drv.c` | Mode table, kernel API fixes |
| `~/ms912x-6.19-kernel/ms912x_transfer.c` | Frame timing, YUV conversion, USB transfer |
| `~/ms912x-6.19-kernel/ms912x_registers.c` | Chip register init, set_resolution |
| `~/ms912x-fix/` | Parallel working copy (may be the active DKMS one) |

> ⚠️ **Confirm which folder DKMS is using** at the start of the next session with:
> ```bash > grep "1920" ~/ms912x-6.19-kernel/ms912x_drv.c > grep "1920" ~/ms912x-fix/ms912x_drv.c > ```

---
O issue #23 "Performance issues over USB 2.0 on Manjaro Gnome Wayland" é exatamente o seu problema. Infelizmente, está **aberto e sem solução** desde novembro de 2024 .

## A Realidade do Lag com MS912X + USB 2.0

O lag que você sente **é uma limitação física do hardware**, não um bug do driver. A razão é matemática:

| Fator | Valor |
|---|---|
| Resolução | 1920×1080 |
| Bytes por pixel (YUV422) | 2 bytes |
| Tamanho do frame | ~4MB |
| Banda USB 2.0 disponível | ~40MB/s real |
| Tempo de transmissão por frame | ~100ms |
| FPS máximo teórico | ~10fps real |

O chip MS912X usa compressão para chegar nos 30fps, mas há overhead de encode YUV + transferência USB + decode no chip que cria **latência inerente de 100–200ms** .

## O Que Dá Para Tentar Ainda

- **USB 3.0** — Se sua máquina tem porta USB 3.0 e você conectar o adaptador nela (mesmo que o cabo seja 2.0), a banda dobra e o lag cai significativamente
- **Reduzir a resolução** da tela externa para 1280×720 — o frame fica 4x menor, melhorando muito o lag:
  ```bash
  # No ~/.config/hypr/monitors.conf
  monitor=<nome_do_monitor_externo>,1280x720@30,auto,1
  ```
- **Aceitar o lag** — para uso com browser, editor de texto e coisas não interativas, 100-200ms é tolerável

O problema de **mouse clonado** que você tinha (issue #29 no repo) você já resolveu com o full-frame fix. O lag infelizmente é a natureza do USB 2.0 display adapter .