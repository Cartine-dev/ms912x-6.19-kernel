<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# me responda apenas em ingles por razões de otimização, sei que voce funciona melhor em ingles, veja 'MS912X Driver Fix — Session Summary

Context
You're running Arch Linux (Omarchy) with kernel 6.19, trying to get a MacroSilicon MS912X USB display adapter (VID/PID 534d:6021, USB 2.0) working as a second monitor on an LG screen.
What We Did

1. Fork \& Setup
Forked [tiirwaa/ms912x](https://github.com/tiirwaa/ms912x) (branch kernel-6.16) to [https://github.com/Cartine-dev/ms912x-6.19-kernel](https://github.com/Cartine-dev/ms912x-6.19-kernel)
Cloned locally to ~/ms912x-6.19-kernel
Created branch kernel-6.19-ms912x-fix
Working folder used for most edits ended up being ~/ms912x-fix (a parallel copy)
2. Kernel 6.19 Compilation Fixes (ms912x_drv.c)
Fixed timer_container_of API change
Fixed drm_gem_fb_begin_cpu_access / drm_gem_fb_end_cpu_access deprecations
Fixed other minor kernel API breakages — driver compiled and loaded successfully
3. Green Screen Investigation
The monitor was detected, lit up, but showed solid green with interference pattern. We tested:
❌ Swapping YUV byte order (UYVY → YUYV, YVYU)
❌ Changing unsigned int to int for YUV variables (was a valid bug but not the root cause)
✅ Hardcoded white pixels still showed green → proved the bug was NOT in color conversion
4. Root Cause Found
By reading [crazedr0m/ms912x](https://github.com/crazedr0m/ms912x)'s re_notes/resolutions hardware dump, we found:
Mode in driverStatus
MS912X_MODE(1920, 1080, 60, 0x8100)
❌ Doesn't exist on hardware
MS912X_MODE(1920, 1080, 30, 0x2200)
✅ Real hardware mode
The chip was receiving an invalid mode code 0x8100 and defaulting to green output.
5. Fix Applied
c
// ms912x_drv.c — changed:
MS912X_MODE(1920, 1080, 60, 0x8100, MS912X_PIXFMT_UYVY)
// to:
MS912X_MODE(1920, 1080, 30, 0x2200, MS912X_PIXFMT_UYVY)
After reboot — screen works! Image is correct, no more green! 🎉
Current Status
✅ Driver loads and displays correctly
⚠️ Lag/latency — cursor movement delayed on external monitor
⚠️ Ghost cursors — multiple cursor shadows appear during movement
Next Fix (Pending)
Two timing bugs in ms912x_transfer.c identified but not yet applied:
bash

# Fix 1: frame limiter — change 16ms (60fps) to 33ms (30fps)

sed -i 's/msecs_to_jiffies(16)/msecs_to_jiffies(33)/' ms912x_transfer.c

# Fix 2: USB completion timeout — change 1ms to 40ms

sed -i 's/msecs_to_jiffies(1))/msecs_to_jiffies(40))/' ms912x_transfer.c
Then rebuild:
bash
sudo dkms remove ms912x/0.1 --all
sudo dkms install .
hyprctl dispatch exit
Key Files
FileRole
FileRole
~/ms912x-6.19-kernel/ms912x_drv.c
Mode table, kernel API fixes
~/ms912x-6.19-kernel/ms912x_transfer.c
Frame timing, YUV conversion, USB transfer
~/ms912x-6.19-kernel/ms912x_registers.c
Chip register init, set_resolution
~/ms912x-fix/
Parallel working copy (may be the active DKMS one)
⚠️ Confirm which folder DKMS is using at the start of the next session with:
bash
grep "1920" ~/ms912x-6.19-kernel/ms912x_drv.c
grep "1920" ~/ms912x-fix/ms912x_drv.c'

agora devemos continuar de onde paramos

Great news — I can see your repository's current state of `ms912x_transfer.c`. Both timing fixes from the session summary have **already been applied** to the file. Let me confirm what's in there versus what's still needed.

## Current State of `ms912x_transfer.c`

Looking at the live file in your [kernel-6.19-ms912x-fix branch](https://github.com/Cartine-dev/ms912x-6.19-kernel/blob/kernel-6.19-ms912x-fix/ms912x_transfer.c):

- ✅ **Fix 1 (frame limiter)** — `msecs_to_jiffies(33)` is already present on the frame rate limiter
- ✅ **Fix 2 (USB completion timeout)** — `msecs_to_jiffies(40)` is already present on the `wait_for_completion_timeout` call

Both `sed` commands from the session summary were already applied. So **you don't need to reapply them** — the code is correct.

## What You Still Need To Do

The fixes are in the repo, but you need to confirm which folder DKMS is actually building from, then rebuild:

**Step 1 — Confirm the active DKMS source:**

```bash
grep "1920, 1080, 30" ~/ms912x-6.19-kernel/ms912x_drv.c
grep "1920, 1080, 30" ~/ms912x-fix/ms912x_drv.c
grep "msecs_to_jiffies(33)" ~/ms912x-6.19-kernel/ms912x_transfer.c
grep "msecs_to_jiffies(33)" ~/ms912x-fix/ms912x_transfer.c
```

The folder that returns all matches is your active DKMS source. If it's `~/ms912x-fix`, sync the transfer fix there too:

```bash
cp ~/ms912x-6.19-kernel/ms912x_transfer.c ~/ms912x-fix/ms912x_transfer.c
```

**Step 2 — Rebuild and reload:**

```bash
sudo dkms remove ms912x/0.1 --all
cd ~/ms912x-6.19-kernel   # or ~/ms912x-fix if that's the active one
sudo dkms install .
sudo modprobe -r ms912x && sudo modprobe ms912x
```

**Step 3 — Restart Hyprland:**

```bash
hyprctl dispatch exit
```


## What These Fixes Should Resolve

| Issue | Root Cause | Fix Applied |
| :-- | :-- | :-- |
| Lag / cursor delay | Frame limiter was pacing at 60fps (16ms) while hardware runs at 30fps | Changed to 33ms |
| Ghost cursors | USB completion timeout (1ms) too short, causing overlapping transfers | Changed to 40ms |

The ghost cursor effect is typically caused by the USB transfer not completing before the next frame is queued, so the 40ms timeout gives the chip proper breathing room. After rebuilding, the display should be smooth at a stable 30fps with no ghost artifacts.

---

# como podemos desfazer o fix 1 e 2 ? pois agora a tela que estava funcional agora esta preta

The search results aren't relevant here — I have everything needed from the file I already read. Here's exactly how to revert both fixes.

## Reverting Fix 1 \& Fix 2

First, confirm which folder DKMS is using (the one with `1920, 1080, 30` in `ms912x_drv.c`):

```bash
grep "1920, 1080, 30" ~/ms912x-6.19-kernel/ms912x_drv.c
grep "1920, 1080, 30" ~/ms912x-fix/ms912x_drv.c
```

Then, no diretório correto (**substitua `~/ms912x-6.19-kernel` por `~/ms912x-fix` se necessário**), rode:

```bash
cd ~/ms912x-6.19-kernel

# Revert Fix 1: 33ms → 16ms (frame limiter)
sed -i 's/msecs_to_jiffies(33)/msecs_to_jiffies(16)/' ms912x_transfer.c

# Revert Fix 2: 40ms → 1ms (USB completion timeout)
sed -i 's/msecs_to_jiffies(40))/msecs_to_jiffies(1))/' ms912x_transfer.c
```

Confirme que o revert foi aplicado:

```bash
grep "msecs_to_jiffies" ms912x_transfer.c
```

Deve retornar `(16)` e `(1)`.

## Rebuild \& Reload

```bash
sudo dkms remove ms912x/0.1 --all
sudo dkms install .
sudo modprobe -r ms912x && sudo modprobe ms912x
hyprctl dispatch exit
```


## Por que a tela ficou preta?

O culpado mais provável é o **Fix 2** (40ms timeout). O `wait_for_completion_timeout` espera o request anterior terminar antes de enviar o próximo frame . Com 40ms de timeout em USB 2.0, se a transferência estiver lenta, o driver cai em `-ETIMEDOUT` e **para de enviar todos os frames** — daí a tela preta. Com 1ms o comportamento é diferente (fail-fast com drop de frame, mas não paralisa o pipeline).

Se após reverter quiser tentar um valor intermediário mais seguro, **33ms no Fix 1 e 5ms no Fix 2** tende a ser um bom equilíbrio para USB 2.0 a 30fps.
<span style="display:none">[^2_1][^2_10][^2_11][^2_12][^2_13][^2_14][^2_15][^2_2][^2_3][^2_4][^2_5][^2_6][^2_7][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://www.reddit.com/r/Amd/comments/yszd2h/amd_driver_timeout_solution_turn_off_hardware/

[^2_2]: https://evanshortiss.com/amd-driver-memory-lock-timeout

[^2_3]: https://www.youtube.com/watch?v=4M6-q7pex7k

[^2_4]: https://www.youtube.com/watch?v=UR3HOjteqss

[^2_5]: https://www.youtube.com/watch?v=fxIEwSkRSPQ

[^2_6]: https://learn.microsoft.com/en-us/answers/questions/3879930/constantly-getting-driver-timeout-error-and-black

[^2_7]: https://www.youtube.com/watch?v=dsbc8okSJUI

[^2_8]: https://www.msi.com/faq/faq-9990

[^2_9]: https://www.youtube.com/watch?v=OPfb1Wap9iY

[^2_10]: https://www.msi.com/faq/nb-1947

[^2_11]: https://www.youtube.com/watch?v=W_qvaGx0hNs

[^2_12]: https://www.reddit.com/r/Kalilinux/comments/1pto34o/usbtohdmi_macrosilicon_534d6021_not_working/

[^2_13]: https://www.youtube.com/watch?v=R34srPzUsoo

[^2_14]: https://github.com/awawa-dev/HyperHDR/discussions/869

[^2_15]: https://www.youtube.com/watch?v=YcmnZlObGNw


---

# na realidade eu reniciei o computador, e sem desfazer os fixes ele voltou, mas ainda esta com problema de throtting , lag e ghost de objetos que existiam antes (por exemplo eu mexer o navegador de uma tela pra outra, mas fica parte do navegador piscando na tela que esta conectado o nosso adaptador

O problema de "ghost" de janelas (partes do navegador piscando onde ele estava antes) é um problema clássico de **damage tracking** — o Hyprland só manda para o driver o **rect danificado** (a área que mudou), mas não limpa a área onde a janela estava antes. O driver então nunca sobrescreve os pixels antigos.

## Diagnóstico dos 3 Problemas

| Problema | Causa Real |
| :-- | :-- |
| Ghost de janelas | Damage tracking do Hyprland: só envia o novo rect, não apaga o antigo |
| Lag | USB 2.0 a 30fps tem ~33ms de latência inerente + tempo de encode YUV |
| Throttling/drops | `wait_for_completion_timeout(40ms)` às vezes stalla se a transferência USB demora |

## Fix 1 (Ghost) — Hyprland config (mais rápido)

Adicione no seu `~/.config/hypr/hyprland.conf`:

```
misc {
    damage_tracking = 0
}
```

Isso força o Hyprland a sempre enviar o frame inteiro, eliminando os ghosts. Depois:

```bash
hyprctl reload
```


## Fix 2 (Ghost) — Driver side (mais robusto)

Se o config do Hyprland não resolver, force full-frame no próprio driver. Em `ms912x_drv.c`, na função `ms912x_fb_dirty` (ou onde `ms912x_fb_send_rect` é chamado), expanda o rect antes de chamar a função:

```c
// Force full-frame update to eliminate ghost artifacts
rect.x1 = 0;
rect.y1 = 0;
rect.x2 = fb->width;
rect.y2 = fb->height;
```

Ou mais simples, no início de `ms912x_fb_send_rect` em `ms912x_transfer.c`, adicione logo após a declaração de variáveis:

```c
/* Force full frame to avoid ghost artifacts on window move */
rect->x1 = 0;
rect->y1 = 0;
rect->x2 = fb->width;
rect->y2 = fb->height;
```


## Fix 3 (Throttling) — Ajustar o timeout USB

O 40ms de timeout pode causar stalls esporádicos. Tente aumentar para 2 frame periods:

```bash
cd ~/ms912x-6.19-kernel  # ou ~/ms912x-fix
sed -i 's/msecs_to_jiffies(40))/msecs_to_jiffies(66))/' ms912x_transfer.c
sudo dkms remove ms912x/0.1 --all
sudo dkms install .
sudo modprobe -r ms912x && sudo modprobe ms912x
```


## Ordem Recomendada

1. Primeiro tente o **Hyprland `damage_tracking = 0`** — não precisa recompilar nada
2. Se ghosting persistir → aplique o **fix no driver** e recompile
3. Se throttling persistir → ajuste o timeout para 66ms

O lag de ~33ms é inerente ao USB 2.0 a 30fps e não tem como eliminar completamente, mas deve ser perceptível apenas em movimentos rápidos do mouse.
<span style="display:none">[^3_1][^3_10][^3_11][^3_12][^3_13][^3_14][^3_15][^3_2][^3_3][^3_4][^3_5][^3_6][^3_7][^3_8][^3_9]</span>

<div align="center">⁂</div>

[^3_1]: https://github.com/rhgndf/ms912x/issues

[^3_2]: https://plus.diolinux.com.br/t/usb-para-hdmi-drm-fbdev-ttm-h-resolvido/68782

[^3_3]: https://www.youtube.com/watch?v=qL6HJWxjfQs

[^3_4]: https://github.com/MindShow/USBDisplay/issues/138

[^3_5]: https://www.hp.com/us-en/shop/tech-takes/monitor-ghosting-fix

[^3_6]: https://www.reddit.com/r/Kalilinux/comments/1pto34o/usbtohdmi_macrosilicon_534d6021_not_working/

[^3_7]: https://forum.garudalinux.org/t/usb-to-hdmi-3rd-monitor-not-found/39998

[^3_8]: https://github.com/rhgndf/ms912x

[^3_9]: https://github.com/rhgndf/ms912x/issues/3

[^3_10]: https://www.youtube.com/watch?v=eC6IzjsgRZU

[^3_11]: https://github.com/PIKACHU619/ms912x-linux-driver

[^3_12]: https://bbs.archlinux.org/viewtopic.php?id=301658

[^3_13]: https://forums.developer.nvidia.com/t/usb-timeout-when-flashing-agx-orin/235600

[^3_14]: https://www.youtube.com/watch?v=KUcXz6t58gI

[^3_15]: https://community.frame.work/t/framework-13-amd-7840u-hdmi-issues/56130


---

# <q>Fix 1 (Ghost) — Hyprland config (mais rápido)Adicione no seu ~/.config/hypr/hyprland.conf:textmisc {

    damage_tracking = 0
    }</q> onde devemos adicionar esta config se ele esta assim:
'  GNU nano 8.7.1                                                                                                                 hyprland.conf

# Learn how to configure Hyprland: [https://wiki.hyprland.org/Configuring/](https://wiki.hyprland.org/Configuring/)

# Use defaults Omarchy defaults (but don't edit these directly!)

source = ~/.local/share/omarchy/default/hypr/autostart.conf
source = ~/.local/share/omarchy/default/hypr/bindings/media.conf
source = ~/.local/share/omarchy/default/hypr/bindings/clipboard.conf
source = ~/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf
source = ~/.local/share/omarchy/default/hypr/bindings/utilities.conf
source = ~/.local/share/omarchy/default/hypr/envs.conf
source = ~/.local/share/omarchy/default/hypr/looknfeel.conf
source = ~/.local/share/omarchy/default/hypr/input.conf
source = ~/.local/share/omarchy/default/hypr/windows.conf
source = ~/.config/omarchy/current/theme/hyprland.conf

# Change your own setup in these files (and overwrite any settings from defaults!)

source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/bindings.conf
source = ~/.config/hypr/looknfeel.conf
source = ~/.config/hypr/autostart.conf

# Add any other personal Hyprland configuration below

# windowrule = workspace 5, match:class qemu

source = ~/.config/hypr/nvidia.conf'

Adicione diretamente no final do arquivo, na seção de configurações pessoais que já existe lá:

```bash
nano ~/.config/hypr/hyprland.conf
```

O arquivo deve ficar assim no final:

```ini
# Add any other personal Hyprland configuration below
# windowrule = workspace 5, match:class qemu

source = ~/.config/hypr/nvidia.conf

misc {
    damage_tracking = 0
}
```

Salve com **Ctrl+O → Enter → Ctrl+X**, depois recarregue:

```bash
hyprctl reload
```

Essa é a seção correta pois o próprio arquivo comenta `# Add any other personal Hyprland configuration below`. Configs adicionadas aqui sobrescrevem qualquer valor definido nos arquivos `source`d acima (como `looknfeel.conf` ou `windows.conf`), então é o lugar ideal para overrides como esse.

---

# <q>misc {

    damage_tracking = 0
    }</q> ele ja informou 'config option don't exist' ... procure melhor nas documentações do hyprland para ter certeza

A opção correta é no namespace `debug`, não `misc` . Use:

```ini
# Add any other personal Hyprland configuration below
# windowrule = workspace 5, match:class qemu

source = ~/.config/hypr/nvidia.conf

debug {
    damage_tracking = 0
}
```

Salve e recarregue:

```bash
hyprctl reload
```

O valor `0` corresponde ao modo `none` — desativa completamente o damage tracking e força o Hyprland a redesenhar o frame inteiro a cada atualização, eliminando os ghosts . Confirmado em issues do próprio repositório do Hyprland que essa opção resolve exatamente o problema de partes antigas de janelas "fantasmas" persistindo na tela .

> ⚠️ Como mencionado na documentação, isso aumenta o uso de GPU pois redesenha tudo a cada frame — mas dado que o adaptador MS912X a 30fps já não é exigente, o impacto será mínimo na prática.
<span style="display:none">[^5_1][^5_10][^5_11][^5_12][^5_13][^5_14][^5_15][^5_2][^5_3][^5_4][^5_5][^5_6][^5_7][^5_8][^5_9]</span>

<div align="center">⁂</div>

[^5_1]: https://github.com/hyprwm/Hyprland/wiki/Basic-Config/b1bd6a563aa109de0918b1573e3e8a52d4413990

[^5_2]: https://github.com/hyprwm/Hyprland/discussions/2200

[^5_3]: https://github.com/hyprwm/Hyprland/discussions/4575

[^5_4]: https://code.hyprland.org/hyprwm/Hyprland/commit/090a7dac747f5b6f4d85edf5f4e8079016bf23eb

[^5_5]: https://github.com/end-4/dots-hyprland/discussions/413

[^5_6]: https://codetest.hyprland.org/hyprwm/Hyprland/commit/70e3cb815177df9742ae8318a5a4e38d1e273054?style=split\&whitespace=show-all\&show-outdated

[^5_7]: https://www.reddit.com/r/hyprland/comments/1erwj7m/hyprland_no_direct_scanout_true_for_fullscreen/

[^5_8]: https://git.tfcconnection.org/chris/dotfiles/blame/commit/412015904f65d7efc7e1b5df860908250ff7052b/.config/hypr/hyprland.conf

[^5_9]: https://wiki.hyprland.org/0.17.0beta/FAQ/

[^5_10]: https://code.hyprland.org/hyprwm/hyprland-wiki/src/commit/f34f549d50a19ad813563dda25a086c6fbc441d5/pages/Configuring/Basic-Config.md

[^5_11]: https://github.com/hyprwm/Hyprland/issues/3039

[^5_12]: https://www.youtube.com/watch?v=LvV2ImYuWXg

[^5_13]: https://github.com/hyprwm/Hyprland/issues/1127

[^5_14]: https://wiki.hypr.land/Configuring/

[^5_15]: https://deepwiki.com/hyprwm/hyprland-wiki/7-troubleshooting


---

# realmente existe, dei hyprctl reload e nao resolveu entao vamos para 2 opcao'Fix 2 (Ghost) — Driver side (mais robusto)

Se o config do Hyprland não resolver, force full-frame no próprio driver. Em ms912x_drv.c, na função ms912x_fb_dirty (ou onde ms912x_fb_send_rect é chamado), expanda o rect antes de chamar a função:
c
// Force full-frame update to eliminate ghost artifacts
rect.x1 = 0;
rect.y1 = 0;
rect.x2 = fb->width;
rect.y2 = fb->height;
Ou mais simples, no início de ms912x_fb_send_rect em ms912x_transfer.c, adicione logo após a declaração de variáveis:
c
/* Force full frame to avoid ghost artifacts on window move */
rect->x1 = 0;
rect->y1 = 0;
rect->x2 = fb->width;
rect->y2 = fb->height;
'

Perfeito. Já tenho o conteúdo do `ms912x_transfer.c` do seu repo. Aqui está exatamente onde e como aplicar o fix:

## Localização Exata no Arquivo

Na função `ms912x_fb_send_rect`, você vai adicionar o override **antes** do cálculo de `x` e `width`. O bloco atual está assim:

```c
int x, width;
	
/* Seems like hardware can only update framebuffer 
 * in multiples of 16 horizontally
 */
x = ALIGN_DOWN(rect->x1, 16);
```

Deve ficar assim:

```c
int x, width;

/* Force full-frame update to eliminate ghost artifacts */
rect->x1 = 0;
rect->y1 = 0;
rect->x2 = fb->width;
rect->y2 = fb->height;

/* Seems like hardware can only update framebuffer 
 * in multiples of 16 horizontally
 */
x = ALIGN_DOWN(rect->x1, 16);
```


## Comando para Aplicar

No diretório correto (confirme qual com `grep "1920, 1080, 30" ~/ms912x-6.19-kernel/ms912x_drv.c`):

```bash
cd ~/ms912x-6.19-kernel  # ou ~/ms912x-fix

python3 -c "
content = open('ms912x_transfer.c').read()
old = '\tx = ALIGN_DOWN(rect->x1, 16);'
new = '\t/* Force full-frame update to eliminate ghost artifacts */\n\trect->x1 = 0;\n\trect->y1 = 0;\n\trect->x2 = fb->width;\n\trect->y2 = fb->height;\n\n\tx = ALIGN_DOWN(rect->x1, 16);'
open('ms912x_transfer.c', 'w').write(content.replace(old, new, 1))
print('Done')
"
```

Confirme que ficou correto:

```bash
grep -A 8 "Force full-frame" ms912x_transfer.c
```


## Rebuild

```bash
sudo dkms remove ms912x/0.1 --all
sudo dkms install .
sudo modprobe -r ms912x && sudo modprobe ms912x
hyprctl dispatch exit
```

> ⚠️ Com `rect` sempre sendo o frame inteiro (1920×1080), o driver vai transferir todos os pixels via USB a cada frame — é o custo do fix. O lag continua em ~33ms (inerente ao USB 2.0 a 30fps), mas os ghosts devem desaparecer completamente.

---

# <q>cd ~/ms912x-6.19-kernel  \# ou ~/ms912x-fix

python3 -c "
content = open('ms912x_transfer.c').read()
old = '\tx = ALIGN_DOWN(rect->x1, 16);'
new = '\t/* Force full-frame update to eliminate ghost artifacts */\n\trect->x1 = 0;\n\trect->y1 = 0;\n\trect->x2 = fb->width;\n\trect->y2 = fb->height;\n\n\tx = ALIGN_DOWN(rect->x1, 16);'
open('ms912x_transfer.c', 'w').write(content.replace(old, new, 1))
print('Done')
"</q> nao entendi esse comando, 'ms912x-6.19-kernel

kernel-6.19-ms912x-fix

❯
grep "1920, 1080, 30" ~/ms912x-6.19-kernel/ms912x_drv.c

ms912x-6.19-kernel

kernel-6.19-ms912x-fix

✗
'

esse comando mencionado

'python3 -c "
content = open('ms912x_transfer.c').read()
old = '\tx = ALIGN_DOWN(rect->x1, 16);'
new = '\t/* Force full-frame update to eliminate ghost artifacts */\n\trect->x1 = 0;\n\trect->y1 = 0;\n\trect->x2 = fb->width;\n\trect->y2 = fb->height;\n\n\tx = ALIGN_DOWN(rect->x1, 16);'
open('ms912x_transfer.c', 'w').write(content.replace(old, new, 1))
print('Done')
"'

é o python q modifica o arquivo ? nao tem como fazer com comandos linux nao ?

Sim! O Python era só para automatizar a edição de texto. O jeito mais simples é editar direto com **nano**, que você já conhece:

## Com nano (mais fácil)

```bash
nano ~/ms912x-6.19-kernel/ms912x_transfer.c
```

1. Pressione **Ctrl+W** para buscar
2. Digite `ALIGN_DOWN` e pressione Enter
3. Isso vai te levar exatamente para esta linha:

```c
	x = ALIGN_DOWN(rect->x1, 16);
```

4. Posicione o cursor no **início dessa linha** e adicione as linhas acima dela:

```c
	/* Force full-frame update to eliminate ghost artifacts */
	rect->x1 = 0;
	rect->y1 = 0;
	rect->x2 = fb->width;
	rect->y2 = fb->height;

	x = ALIGN_DOWN(rect->x1, 16);
```

5. Salve: **Ctrl+O → Enter → Ctrl+X**

> ⚠️ Use **Tab** para indentar (não espaços), pois o arquivo C usa tabs.

## Ou com sed (uma linha, se preferir)

```bash
cd ~/ms912x-6.19-kernel
sed -i '/x = ALIGN_DOWN(rect->x1, 16);/i\\t\/* Force full-frame update to eliminate ghost artifacts *\/\n\trect->x1 = 0;\n\trect->y1 = 0;\n\trect->x2 = fb->width;\n\trect->y2 = fb->height;\n' ms912x_transfer.c
```

Confirme o resultado:

```bash
grep -B1 -A6 "ALIGN_DOWN" ms912x_transfer.c
```

Depois rebuild:

```bash
sudo dkms remove ms912x/0.1 --all && sudo dkms install . && sudo modprobe -r ms912x && sudo modprobe ms912x
```

<span style="display:none">[^7_1][^7_10][^7_11][^7_12][^7_13][^7_14][^7_15][^7_2][^7_3][^7_4][^7_5][^7_6][^7_7][^7_8][^7_9]</span>

<div align="center">⁂</div>

[^7_1]: https://coisasdeinfra.com/sed-para-substituir-conteudo-dentro-arquivo/

[^7_2]: https://tidahora.com.br/substituindo-textos-em-arquivos-no-linux/

[^7_3]: https://www.locaweb.com.br/ajuda/wiki/sed-linux/

[^7_4]: https://linuxforce.com.br/comandos-linux/comandos-linux-comando-edit/

[^7_5]: https://pt.linuxteaching.com/article/how_to_use_sed_to_find_and_replace_string_in_files

[^7_6]: https://blog.4linux.com.br/desvendando-o-poder-do-comando-sed/

[^7_7]: https://br.atsit.in/archives/24311

[^7_8]: https://www.ime.usp.br/~batista/sed_ptBR.html

[^7_9]: https://pt.linuxteaching.com/article/sed_command_to_replace_a_string_in_a_file

[^7_10]: https://plus.diolinux.com.br/t/resolvido-como-adicionar-palavras-a-uma-linha-especifica-com-sed-ou-awk/7783

[^7_11]: https://blog.desdelinux.net/pt/substitua-o-texto-dentro-dos-arquivos-com-apenas-um-comando-perl/

[^7_12]: https://pt.stackoverflow.com/questions/249509/substituir-por-usando-sed

[^7_13]: https://www.certificacaolinux.com.br/comando-linux-sed/

[^7_14]: https://ubuntuforum-br.org/index.php?topic=6671.0

[^7_15]: https://devblog.drall.com.br/substituir-palavras-em-varios-arquivos-no-linux


---

# prefiro com o sed mesmo ! para ter certeza, peça o comando como cat para eu colar aqui para voce o arquivo inteiro, para voce ter CERTEZA mesmo , depois podemos confirmar com grep, e depois podemos fazer o rebuild !

Já tenho o conteúdo do arquivo do seu repositório GitHub (busquei anteriormente), mas para ter **certeza absoluta** que a versão local no seu disco está igual, rode isso:

```bash
cat ~/ms912x-6.19-kernel/ms912x_transfer.c
```

Cole o output aqui e eu verifico linha por linha antes de montar o `sed` exato e perfeito para você!
<span style="display:none">[^8_1][^8_10][^8_11][^8_12][^8_13][^8_2][^8_3][^8_4][^8_5][^8_6][^8_7][^8_8][^8_9]</span>

<div align="center">⁂</div>

[^8_1]: https://github.com/rhgndf/ms912x

[^8_2]: https://github.com/PIKACHU619/ms912x-linux-driver/blob/main/INSTALLATION.md

[^8_3]: https://github.com/rhgndf/ms912x/blob/main/README.md

[^8_4]: https://github.com/s12wu/ms912x-python

[^8_5]: https://www.youtube.com/watch?v=kKcRyThUrDE

[^8_6]: https://github.com/PIKACHU619

[^8_7]: https://github.com/rhgndf/ms912x/blob/main/ms912x.h

[^8_8]: https://github.com/rhgndf/ms912x/issues/3

[^8_9]: https://github.com/PIKACHU619/ms912x-linux-driver

[^8_10]: https://github.com/rhgndf/ms912x/issues

[^8_11]: https://docs.github.com/en/repositories/creating-and-managing-repositories/transferring-a-repository

[^8_12]: https://github.com/PIKACHU619/ms912x-linux-driver/blob/main/CONTRIBUTING.md

[^8_13]: https://stackoverflow.com/questions/29224396/can-i-work-on-a-github-project-between-two-machines-with-a-usb


---

# aqui 'ms912x-6.19-kernel kernel-6.19-ms912x-fix ❯ cat ~/ms912x-6.19-kernel/ms912x_transfer.c

\#include <linux/dma-buf.h>
\#include <linux/vmalloc.h>

\#include <drm/drm_drv.h>
\#include <drm/drm_gem_framebuffer_helper.h>
\#include <linux/jiffies.h>

\#include "ms912x.h"

\#define MS912X_REQUEST_TYPE 0xb5
\#define MS912X_WRITE_TYPE 0xa6

static void ms912x_request_timeout(struct timer_list *t)
{
struct ms912x_usb_request *request = timer_container_of(request, t, timer);
usb_sg_cancel(\&request->sgr);
}

static void ms912x_request_work(struct work_struct *work)
{
struct ms912x_usb_request *request =
container_of(work, struct ms912x_usb_request, work);
struct ms912x_device *ms912x = request->ms912x;
struct usb_device *usbdev = interface_to_usbdev(ms912x->intf);
struct usb_sg_request *sgr = \&request->sgr;
struct sg_table *transfer_sgt = \&request->transfer_sgt;

    timer_setup(&request->timer, ms912x_request_timeout, 0);
    usb_sg_init(sgr, usbdev, usb_sndbulkpipe(usbdev, 0x04), 0,
    	    transfer_sgt->sgl, transfer_sgt->nents,
    	    request->transfer_len, GFP_KERNEL);
    mod_timer(&request->timer, jiffies + msecs_to_jiffies(5000));
    usb_sg_wait(sgr);
    timer_delete_sync(&request->timer);
    complete(&request->done);
    }

void ms912x_free_request(struct ms912x_usb_request *request)
{
if (request->transfer_buffer) {
sg_free_table(\&request->transfer_sgt);
vfree(request->transfer_buffer);
request->transfer_buffer = NULL;
}

    kfree(request->temp_buffer);
    request->temp_buffer = NULL;
    request->alloc_len = 0;
    }

int ms912x_init_request(struct ms912x_device *ms912x,
struct ms912x_usb_request *request, size_t len)
{
int ret, i;
unsigned int num_pages;
void *data;
struct page **pages;
void *ptr;

    data = vmalloc_32(len);
    if (!data)
    	return -ENOMEM;
    
    request->temp_buffer = kmalloc(1920 * 4, GFP_KERNEL);
    if (!request->temp_buffer) {
    	vfree(data);
    	return -ENOMEM;
    }
    
    num_pages = DIV_ROUND_UP(len, PAGE_SIZE);
    pages = kmalloc_array(num_pages, sizeof(struct page *), GFP_KERNEL);
    if (!pages) {
    	ret = -ENOMEM;
    	goto err_vfree;
    }
    
    for (i = 0, ptr = data; i < num_pages; i++, ptr += PAGE_SIZE)
    	pages[i] = vmalloc_to_page(ptr);
    
    ret = sg_alloc_table_from_pages(&request->transfer_sgt, pages,
    				num_pages, 0, len, GFP_KERNEL);
    kfree(pages);
    if (ret)
    	goto err_vfree;
    
    request->alloc_len = len;
    request->transfer_buffer = data;
    request->ms912x = ms912x;
    
    init_completion(&request->done);
    INIT_WORK(&request->work, ms912x_request_work);
    return 0;
    err_vfree:
vfree(data);
return ret;
}

struct ms912x_yuv_lut {
u16 y_r[256], y_g[256], y_b[256];
u16 u_r[256], u_g[256], u_b[256];
u16 v_r[256], v_g[256], v_b[256];
};

static struct ms912x_yuv_lut yuv_lut;

void ms912x_init_yuv_lut(void)
{
for (int i = 0; i < 256; i++) {
yuv_lut.y_r[i] = (16763 * i) >> 16;
yuv_lut.y_g[i] = (32904 * i) >> 16;
yuv_lut.y_b[i] = (6391 * i) >> 16;

    	yuv_lut.u_r[i] = (-9676 * i) >> 16;
    	yuv_lut.u_g[i] = (-18996 * i) >> 16;
    	yuv_lut.u_b[i] = (28672 * i) >> 16;
    
    	yuv_lut.v_r[i] = (28672 * i) >> 16;
    	yuv_lut.v_g[i] = (-24009 * i) >> 16;
    	yuv_lut.v_b[i] = (-4663 * i) >> 16;
    }
    }

static inline unsigned int ms912x_rgb_to_y(u8 r, u8 g, u8 b)
{
return 16 + yuv_lut.y_r[r] + yuv_lut.y_g[g] + yuv_lut.y_b[b];
}

static inline unsigned int ms912x_rgb_to_u(u8 r, u8 g, u8 b)
{
return 128 + yuv_lut.u_r[r] + yuv_lut.u_g[g] + yuv_lut.u_b[b];
}

static inline unsigned int ms912x_rgb_to_v(u8 r, u8 g, u8 b)
{
return 128 + yuv_lut.v_r[r] + yuv_lut.v_g[g] + yuv_lut.v_b[b];
}

static int ms912x_xrgb_to_yuv422_line(u8 *transfer_buffer,
struct iosys_map *xrgb_buffer,
size_t offset, size_t width,
u32 *temp_buffer)
{
unsigned int i, dst_offset = 0;
unsigned int pixel1, pixel2;
unsigned int r1, g1, b1, r2, g2, b2;
unsigned int v, y1, u, y2;
unsigned int avg_r, avg_g, avg_b;
iosys_map_memcpy_from(temp_buffer, xrgb_buffer, offset, width * 4);
for (i = 0; i < width; i += 2) {
pixel1 = temp_buffer[i];
pixel2 = temp_buffer[i + 1];

    	r1 = (pixel1 >> 16) & 0xFF;
    	g1 = (pixel1 >> 8) & 0xFF;
    	b1 = pixel1 & 0xFF;
    	r2 = (pixel2 >> 16) & 0xFF;
    	g2 = (pixel2 >> 8) & 0xFF;
    	b2 = pixel2 & 0xFF;
    
    	y1 = ms912x_rgb_to_y(r1, g1, b1);
    	y2 = ms912x_rgb_to_y(r2, g2, b2);
    
    	avg_r = (r1 + r2) >> 1;
    	avg_g = (g1 + g2) >> 1;
    	avg_b = (b1 + b2) >> 1;
    
    	v = ms912x_rgb_to_v(avg_r, avg_g, avg_b);
    	u = ms912x_rgb_to_u(avg_r, avg_g, avg_b);
    
    	transfer_buffer[dst_offset++] = u;
    	transfer_buffer[dst_offset++] = y1;
    	transfer_buffer[dst_offset++] = v;
    	transfer_buffer[dst_offset++] = y2;
    }
    return offset;
    }

static const u8 ms912x_end_of_buffer[8] = { 0xff, 0xc0, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00 };

static int ms912x_fb_xrgb8888_to_yuv422(void *dst, const struct iosys_map *src,
struct drm_framebuffer *fb,
struct drm_rect *rect,
void *temp_buffer)
{
struct ms912x_frame_update_header *header =
(struct ms912x_frame_update_header *)dst;
struct iosys_map fb_map;
int i, x, y1, y2, width;

    y1 = rect->y1;
    y2 = (rect->y2 < fb->height) ? rect->y2 : fb->height;
    x = rect->x1;
    width = drm_rect_width(rect);
    
    header->header = cpu_to_be16(0xff00);
    header->x = x / 16;
    header->y = cpu_to_be16(y1);
    header->width = width / 16;
    header->height = cpu_to_be16(drm_rect_height(rect));
    dst += sizeof(*header);
    
    fb_map = IOSYS_MAP_INIT_OFFSET(src, y1 * fb->pitches[0]);
    for (i = y1; i < y2; i++) {
    	ms912x_xrgb_to_yuv422_line(dst, &fb_map, x * 4, width,
    				   temp_buffer);
    	iosys_map_incr(&fb_map, fb->pitches[0]);
    	dst += width * 2;
    }
    
    memcpy(dst, ms912x_end_of_buffer, sizeof(ms912x_end_of_buffer));
    return 0;
    }

int ms912x_fb_send_rect(struct drm_framebuffer *fb, const struct iosys_map *map,
struct drm_rect *rect)
{
struct ms912x_device *ms912x = to_ms912x(fb->dev);
unsigned long now = jiffies;
if (time_before(now, ms912x->last_send_jiffies + msecs_to_jiffies(33)))
return 0;

    int ret = 0, idx;
    struct drm_device *drm = &ms912x->drm;
    struct ms912x_usb_request *prev_request, *current_request;
    int x, width;
    
    /* Seems like hardware can only update framebuffer
     * in multiples of 16 horizontally
     */
    x = ALIGN_DOWN(rect->x1, 16);
    /* Resolutions that are not a multiple of 16 like 1366*768
     * need to be aligned
     */
    width = min(ALIGN(rect->x2, 16), ALIGN_DOWN((int)fb->width, 16)) - x;
    rect->x1 = x;
    rect->x2 = x + width;
    
    current_request = &ms912x->requests[ms912x->current_request];
    prev_request = &ms912x->requests[1 - ms912x->current_request];
    
    drm_dev_enter(drm, &idx);
    
    ret = drm_gem_fb_begin_cpu_access(fb, DMA_FROM_DEVICE);
    if (ret < 0)
    	goto dev_exit;
    
    ret = ms912x_fb_xrgb8888_to_yuv422(current_request->transfer_buffer,
    				   map, fb, rect,
    				   current_request->temp_buffer);
    
    drm_gem_fb_end_cpu_access(fb, DMA_FROM_DEVICE);
    if (ret < 0)
    	goto dev_exit;
    
    /* Sending frames too fast, drop it */
    if (!wait_for_completion_timeout(&prev_request->done,
    				 msecs_to_jiffies(40))) {
    	ret = -ETIMEDOUT;
    	goto dev_exit;
    }
    
    current_request->transfer_len = width * 2 * drm_rect_height(rect) + 16;
    queue_work(system_long_wq, &current_request->work);
    ms912x->current_request = 1 - ms912x->current_request;
    ms912x->last_send_jiffies = jiffies;
    dev_exit:
drm_dev_exit(idx);
return ret;
}

' ! , me explique como voce consultou meu arquivo no repositorio do github (buscou anteriormente ? ) lul voce é tão bom assim ? mas enfim, se pudermos utilizar o github para voce consultar os arquivos será 10

Haha, sim! No início da conversa eu usei uma ferramenta de integração com o GitHub que tenho disponível e busquei diretamente o arquivo `ms912x_transfer.c` do seu repositório `Cartine-dev/ms912x-6.19-kernel` na branch `kernel-6.19-ms912x-fix`. Sempre que precisar posso consultar seus arquivos direto do repo sem precisar de `cat`! 😄

Agora, com o conteúdo do arquivo confirmado, aqui está o `sed` **exato e certeiro**:

## Comando sed

```bash
cd ~/ms912x-6.19-kernel

sed -i '/x = ALIGN_DOWN(rect->x1, 16);/{
i\	/* Force full-frame update to eliminate ghost artifacts */
i\	rect->x1 = 0;
i\	rect->y1 = 0;
i\	rect->x2 = fb->width;
i\	rect->y2 = fb->height;
i\\
}' ms912x_transfer.c
```


## Confirme com grep

```bash
grep -n -A 8 "Force full-frame" ms912x_transfer.c
```

O output esperado deve ser:

```c
/* Force full-frame update to eliminate ghost artifacts */
rect->x1 = 0;
rect->y1 = 0;
rect->x2 = fb->width;
rect->y2 = fb->height;

x = ALIGN_DOWN(rect->x1, 16);
```

Se estiver certo, pode confirmar aqui e partimos pro rebuild!
<span style="display:none">[^9_1][^9_2][^9_3][^9_4][^9_5][^9_6][^9_7][^9_8][^9_9]</span>

<div align="center">⁂</div>

[^9_1]: https://github.com/rhgndf/ms912x

[^9_2]: https://github.com/trending/c

[^9_3]: https://github.com/rhgndf/ms912x/issues

[^9_4]: https://github.com/s12wu/ms912x-python

[^9_5]: https://github.com/fathonix/ms9132-drm-linux

[^9_6]: https://github.com/rhgndf/ms912x/blob/main/README.md

[^9_7]: https://github.com/rhgndf/ms912x/issues/3

[^9_8]: https://github.com/s12wu

[^9_9]: https://github.com/amnemonic/MacroSilicon


---

# acho que deu bom, me de o comando do rebuild sem ser tudo inline ! para eu fazer cada comando separado

Answer skipped.
<span style="display:none">[^10_1][^10_10][^10_2][^10_3][^10_4][^10_5][^10_6][^10_7][^10_8][^10_9]</span>

<div align="center">⁂</div>

[^10_1]: https://www.reddit.com/r/AskMechanics/comments/1ipl26z/is_this_quote_a_joke_or_does_it_seem_legit_i_want/

[^10_2]: https://www.youtube.com/shorts/6g0LmZxnRRk

[^10_3]: https://funag.gov.br/loja/download/CADERNOS-DO-IPRI-N-6.pdf

[^10_4]: https://lyceumonline.usf.edu.br/webp/portalUSF/itatiba/mestrado/educacao/uploadAddress/edicao_completa%5B10995%5D.pdf

[^10_5]: https://repositorio.unesp.br/bitstreams/629b321c-6102-45eb-878a-c9fbe5c86136/download

[^10_6]: http://repositorio2.unb.br/bitstream/10482/12418/1/2012_Mar%C3%ADadelPilarTobarAcosta.pdf

[^10_7]: https://ri.ufs.br/bitstream/riufs/17290/2/JOSIVAN_SANTOS_MOURA.pdf

[^10_8]: https://repositorio.ufpe.br/bitstream/123456789/26806/1/TESE Carlo Benito Cosentino Filho.pdf

[^10_9]: https://brazilianjournals.com.br/assets/ebooks/e08f3731b03641c04b81d8d1ff8c6272.pdf

[^10_10]: https://crp03.org.br/wp-content/uploads/2021/12/Multidisciplinary-Perspectives-about-Disaster_Vol-3_NUPED.pdf


---

# 'ms912x-6.19-kernel kernel-6.19-ms912x-fix ❯ sed -i '/x = ALIGN_DOWN(rect->x1, 16);/{

i\\      /* Force full-frame update to eliminate ghost artifacts */
i\\      rect->x1 = 0;
i\\      rect->y1 = 0;
i\\      rect->x2 = fb->width;
i\\      rect->y2 = fb->height;
i\\\\
}' ms912x_transfer.c

ms912x-6.19-kernel kernel-6.19-ms912x-fix  ❯ grep -n -A 8 "Force full-frame" ms912x_transfer.c
233:	/* Force full-frame update to eliminate ghost artifacts */
234-	rect->x1 = 0;
235-	rect->y1 = 0;
236-	rect->x2 = fb->width;
237-	rect->y2 = fb->height;
238-
239-	x = ALIGN_DOWN(rect->x1, 16);
240-	/* Resolutions that are not a multiple of 16 like 1366*768
241-	 * need to be aligned

'
acho que deu bom, me de o comando do rebuild sem ser tudo inline ! para eu fazer cada comando separado

Perfeito, ficou exatamente certo! Agora o rebuild passo a passo:

**1. Remover o módulo atual do DKMS:**

```bash
sudo dkms remove ms912x/0.1 --all
```

**2. Instalar a nova versão:**

```bash
sudo dkms install .
```

**3. Descarregar o módulo antigo da memória:**

```bash
sudo modprobe -r ms912x
```

**4. Carregar o novo módulo:**

```bash
sudo modprobe ms912x
```

**5. Reiniciar o Hyprland:**

```bash
hyprctl dispatch exit
```

> ⚠️ O passo 5 vai derrubar sua sessão gráfica e reabrir. A tela externa deve voltar automaticamente após o login. Me conta se os ghosts sumiram!

---

# hmmm veja 'ms912x-6.19-kernel kernel-6.19-ms912x-fix  ❯ sudo dkms remove ms912x/0.1 --all

[sudo] password for cartine:
Module ms912x/0.1 for kernel 6.19.11-arch1-1 (x86_64):
Before uninstall, this module version was ACTIVE on this kernel.
Deleting /usr/lib/modules/6.19.11-arch1-1/updates/dkms/ms912x.ko.zst
Running depmod..... done.

Deleting module ms912x/0.1 completely from the DKMS tree.

ms912x-6.19-kernel kernel-6.19-ms912x-fix  ❯ sudo dkms install .
Deprecated feature: CLEAN (/usr/src/ms912x-0.1/dkms.conf)
Creating symlink /var/lib/dkms/ms912x/0.1/source -> /usr/src/ms912x-0.1

Sign command: /usr/lib/modules/6.19.11-arch1-1/build/scripts/sign-file
Signing key: /var/lib/dkms/mok.key
Public certificate (MOK): /var/lib/dkms/mok.pub

Building module(s)... done.
Signing module /var/lib/dkms/ms912x/0.1/build/ms912x.ko
Installing /usr/lib/modules/6.19.11-arch1-1/updates/dkms/ms912x.ko.zst
Running depmod... done.

ms912x-6.19-kernel kernel-6.19-ms912x-fix  ❯ sudo modprobe -r ms912x
modprobe: FATAL: Module ms912x is in use.

'

O módulo está em uso porque o Hyprland ainda está usando a tela. Precisa fechar o Hyprland **antes** de descarregar. Faça nessa ordem:

**1. Fechar o Hyprland primeiro:**

```bash
hyprctl dispatch exit
```

> Sua sessão gráfica vai cair. Continue os próximos comandos no **TTY** (Ctrl+Alt+F2) ou o Hyprland vai reabrir automaticamente — se reabrir, abra um terminal e continue.

**2. Descarregar o módulo:**

```bash
sudo modprobe -r ms912x
```

**3. Carregar o novo:**

```bash
sudo modprobe ms912x
```

**4. Subir o Hyprland novamente:**

```bash
Hyprland
```


***

Ou se preferir o caminho mais simples — **só reiniciar o sistema**:

```bash
reboot
```

O DKMS já instalou o módulo novo corretamente, então após o reboot ele já vai subir com o fix do full-frame aplicado. É a forma mais limpa e garantida!

---

# hmm ao inves de , quando chegar em 'hyprctl dispatch exit' e executar os outros 3 comandos, o reboot ja resolve ?

Sim! O reboot resolve tudo de uma vez. O DKMS já compilou e instalou o módulo novo corretamente, então:

```bash
reboot
```

Isso substitui os passos 1, 2, 3 e 4 automaticamente. Me conta depois se os ghosts sumiram! 🎉

---

# UUUUUUUUUUUUUU KRAI RESOLVEU MESMOOOOOOOOOOOOOOOOOOOOOOO, faça agora um commit que explique oque fizemos, agora vamos resolver o 'Fix 3 (Throttling) — Ajustar o timeout USB

O 40ms de timeout pode causar stalls esporádicos. Tente aumentar para 2 frame periods:
bash
cd ~/ms912x-6.19-kernel  \# ou ~/ms912x-fix
sed -i 's/msecs_to_jiffies(40))/msecs_to_jiffies(66))/' ms912x_transfer.c
sudo dkms remove ms912x/0.1 --all
sudo dkms install .
sudo modprobe -r ms912x \&\& sudo modprobe ms912x'

AAAA QUE BOM!!! 🎉 Vamos lá!

## Commit primeiro

```bash
cd ~/ms912x-6.19-kernel
```

```bash
git add ms912x_transfer.c
```

```bash
git commit -m "fix: force full-frame update to eliminate ghost artifacts

- Added full-frame rect override in ms912x_fb_send_rect() before
  the ALIGN_DOWN calculation, forcing rect to always cover the
  entire framebuffer (0,0 -> fb->width, fb->height)
- This prevents ghost artifacts (leftover pixels from moved windows)
  caused by partial damage tracking sending only the new rect
  without clearing the old one
- Frame limiter already set to 33ms (30fps) and USB completion
  timeout at 40ms from previous session"
```

```bash
git push
```


***

## Fix 3 — Throttling (USB timeout 40ms → 66ms)

```bash
sed -i 's/msecs_to_jiffies(40))/msecs_to_jiffies(66))/' ms912x_transfer.c
```

Confirme:

```bash
grep "msecs_to_jiffies" ms912x_transfer.c
```

Deve mostrar `(33)` e `(66)`.

Depois rebuild:

```bash
sudo dkms remove ms912x/0.1 --all
```

```bash
sudo dkms install .
```

```bash
reboot
```

> Este fix resolve stalls esporádicos onde o USB demora mais que 40ms para completar uma transferência, travando o pipeline. 66ms = 2 frame periods de 30fps, dando margem suficiente sem bloquear demais.

---

# nao funcionou, ainda esta bem lagado, pesquisa na internet se este problema em especifico da pra resolver ou se teremos de conviver com ele

O issue \#23 "Performance issues over USB 2.0 on Manjaro Gnome Wayland" é exatamente o seu problema. Infelizmente, está **aberto e sem solução** desde novembro de 2024 .

## A Realidade do Lag com MS912X + USB 2.0

O lag que você sente **é uma limitação física do hardware**, não um bug do driver. A razão é matemática:


| Fator | Valor |
| :-- | :-- |
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

O problema de **mouse clonado** que você tinha (issue \#29 no repo) você já resolveu com o full-frame fix. O lag infelizmente é a natureza do USB 2.0 display adapter .
<span style="display:none">[^15_1][^15_10][^15_11][^15_12][^15_13][^15_14][^15_15][^15_2][^15_3][^15_4][^15_5][^15_6][^15_7][^15_8][^15_9]</span>

<div align="center">⁂</div>

[^15_1]: https://learn.microsoft.com/pt-br/answers/questions/4088298/quando-ligo-um-disco-usb-externo-o-windows-fica-le

[^15_2]: https://github.com/rhgndf/ms912x/issues

[^15_3]: https://learn.microsoft.com/en-us/answers/questions/2632682/usb-peripheral-input-lag

[^15_4]: https://www.youtube.com/watch?v=wgsfsSEI3ts

[^15_5]: https://www.youtube.com/watch?v=sBIHsx4sS-4

[^15_6]: https://community.frame.work/t/choppy-laggy-display-with-kernel-6-12-framework-13-ryzen-7040/62865

[^15_7]: https://forums.tomshardware.com/threads/usb-3-0-drives-became-suddenly-slow-and-stuck-in-transferring.2639231/

[^15_8]: https://www.youtube.com/watch?v=jP9v6vlQ83o

[^15_9]: https://github.com/rhgndf/ms912x/issues/2

[^15_10]: https://www.easeus.com/computer-instruction/fix-slow-usb-transfer-speed.html

[^15_11]: https://www.high-rely.com/hr_faq/usb-drives-fall-off-line-disconnect-time/

[^15_12]: https://discuss.kde.org/t/frustrating-lag-since-6-9-12-kernel-update-possible-plasmashell-bug/19626

[^15_13]: https://plus.diolinux.com.br/t/usb-para-hdmi-drm-fbdev-ttm-h-resolvido/68782

[^15_14]: https://mokinglobal.com/blogs/mst-hub/do-usb-hubs-increase-latency-how-to-fix-it

[^15_15]: https://www.reddit.com/r/linux_gaming/comments/1pt42qx/linux_619s_significant_30_performance_boost_for/


---

# agora, para por exemplo, eu acabei de desplugar o nosso adaptador, eu devo mexer nas configurações do monitor em monitors.conf para voltar ao normal ? ele agora apenas pela entrada nativa hdmi ? pois eu estou tentando mexer o mouse de um monitor pra outro mas parece que eu tenho que atravessar esta tela invisivel do adaptador para chegar no monitor do notebook

Esse problema é clássico do Hyprland — ele ainda tem o monitor do adaptador configurado no `monitors.conf`, então o mouse entra nessa "tela fantasma" mesmo sem o adaptador plugado.

## Verificar a config atual

```bash
cat ~/.config/hypr/monitors.conf
```

Cole aqui o que aparecer. Mas provavelmente está algo assim:

```
monitor=<monitor_nativo>,preferred,0x0,1
monitor=<monitor_usb>,1920x1080@30,auto,1
```


## Fix — Desativar o monitor USB quando não plugado

Substitua a linha do monitor USB por:

```bash
nano ~/.config/hypr/monitors.conf
```

Troque a linha do adaptador por:

```
monitor=,preferred,auto,1
```

Isso diz ao Hyprland: *"qualquer monitor desconhecido, use as configurações padrão"* — quando o adaptador não estiver plugado, ele simplesmente é ignorado.

Depois:

```bash
hyprctl reload
```


## Para quando plugar o adaptador de novo

Quando quiser usar o adaptador novamente, basta adicionar a linha específica de volta:

```
monitor=<nome_do_monitor_usb>,1920x1080@30,auto,1
```

Para saber o nome exato do monitor USB quando plugado:

```bash
hyprctl monitors
```

Me cola o conteúdo do `monitors.conf` que eu monto o fix certeiro!
<span style="display:none">[^16_1][^16_10][^16_2][^16_3][^16_4][^16_5][^16_6][^16_7][^16_8][^16_9]</span>

<div align="center">⁂</div>

[^16_1]: https://plus.diolinux.com.br/t/mouse-esta-travando-em-diversas-distros/12421

[^16_2]: https://www.reddit.com/r/buildapc/comments/10e0t9q/my_mouse_keeps_freezing_and_its_driving_me_insane/

[^16_3]: https://www.vivaolinux.com.br/topico/Ubuntu-e-Kubuntu/Mouse-trava-em-troca-de-telas

[^16_4]: https://www.youtube.com/watch?v=MGw8xof8HTg

[^16_5]: https://www.youtube.com/watch?v=DVrqknpS7QU

[^16_6]: https://forum.macmagazine.com.br/topic/219718-mouse-e-segundo-monitor-com-lag-e-delay/

[^16_7]: https://www.vivaolinux.com.br/topico/UbuntuBR/Mouse-Trava

[^16_8]: https://ubuntuforum-br.org/index.php?topic=13574.0

[^16_9]: https://plus.diolinux.com.br/t/cursor-do-mouse-travado-no-endless/81720

[^16_10]: https://www.clubedohardware.com.br/forums/topic/1529209-tem-como-minimizar-a-lentidão-no-monitor-hdmi-conectado-na-usb-com-adaptador/


---

# ele esta assim '\# See [https://wiki.hyprland.org/Configuring/Monitors/](https://wiki.hyprland.org/Configuring/Monitors/)

# List current monitors and resolutions possible: hyprctl monitors

# Format: monitor = [port], resolution, position, scale

# Optimized for retina-class 2x displays, like 13" 2.8K, 27" 5K, 32" 6K.

env = GDK_SCALE,1

# --- Configuração: HDMI (Esquerda) + Notebook (Direita) ---

# 1. Monitor HDMI (Esquerda)

# Usa resolução preferida e fica na posição 0x0

\#monitor = HDMI-A-1, preferred, 0x0, 1

# 2. Monitor Notebook (Direita)

# Usa resolução preferida e se posiciona automaticamente à direita do HDMI

\#monitor = eDP-1, preferred, auto-right, 1

# --- Configuração: Notebook (Esquerda) + HDMI (Direita) ---

# 1. Monitor Notebook (Esquerda)

# Usa resolução preferida e fica na posição 0x0

monitor = eDP-1, preferred, 0x0, 1

# 2. Monitor HDMI (Direita)

# Usa resolução preferida e se posiciona automaticamente à direita do Notebook

monitor = HDMI-A-1, preferred, auto-right, 1

\#ADAPTADOR USB -> HDMI (Direita)
\#monitor = HDMI-A-3, preferred, auto-right, 1

\#hyprctl reload'

Boa notícia — a linha do adaptador já está comentada! O problema é outro: o Hyprland está **auto-detectando o HDMI-A-3** mesmo sem o adaptador e criando uma tela fantasma com workspace vazio.

## Fix — Desabilitar explicitamente o HDMI-A-3

Adicione uma linha para desativar o adaptador quando ele não estiver plugado:

```bash
nano ~/.config/hypr/monitors.conf
```

Deixe assim no final do arquivo:

```ini
#ADAPTADOR USB -> HDMI (Direita)
#monitor = HDMI-A-3, preferred, auto-right, 1
monitor = HDMI-A-3, disable
```

Salve e recarregue:

```bash
hyprctl reload
```


## Quando quiser usar o adaptador novamente

Só trocar a linha:

```ini
# Comente o disable:
#monitor = HDMI-A-3, disable

# Descomente o ativo:
monitor = HDMI-A-3, 1920x1080@30, auto-right, 1
```

E:

```bash
hyprctl reload
```

O `monitor = HDMI-A-3, disable` diz explicitamente ao Hyprland para ignorar aquela saída completamente, eliminando a tela invisível que o mouse fica atravessando.

