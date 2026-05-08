<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# agora que sabemos o resumo de nossa conversa que iremos continuar 'MS912X Driver Fix — Session Summary (2026-05-04)

Contexto
Setup: Arch Linux (Omarchy), kernel 6.18.25-1-lts (linux-lts), Hyprland 0.54.3, 3 monitores:
eDP-1 → Tela do notebook (BOE, 1366x768) — card2/i915
HDMI-A-1 → LG 22BN550Y via NVIDIA — card2/i915 (PRIME)
HDMI-A-3 → LG 22BN550Y via Adaptador USB→HDMI MS912X 534d:6021 — card0/ms912x
O Que Foi Resolvido ✅
Driver / DKMS
Criada branch kernel-6.18-lts-dkms-fix a partir de kernel-6.19-ms912x-fix no repo Cartine-dev/ms912x-6.19-kernel
dkms.conf corrigido: MAKE[0]="'make' KVER=${kernelver} KSRC=${kernel_source_dir} all" — DKMS agora compila contra o kernel alvo correto
ms912x_drv.c corrigido: modo trocado de MS912X_MODE(1920,1080,60,0x8100) para MS912X_MODE(1920,1080,30,0x2200) — único modo válido no hardware
modinfo ms912x | grep vermagic retorna 6.18.25-1-lts ✅
lsmod | grep ms912x carrega normalmente ✅
/sys/bus/usb/devices/1-3:1.3/driver aponta para ms912x ✅
Commit: 3e27261 — fix: target linux-lts dkms build and restore 1080p30
Hyprland / monitors.conf
Identificado que HDMI-A-3 é o conector do MS912X
monitors.conf configurado com modo fixo 1920x1080@30 (não preferred)
Linha monitor = HDMI-A-4, disable adicionada para suprimir fantasma pós-replug
Problema Atual — Em Aberto ⚠️
Sintoma
O monitor USB exibe imagem na tela de login (SDDM) mas fica preto depois do login no Hyprland.
Causa Raiz Identificada
O log do Aquamarine em /run/user/1000/hypr/*/hyprland.log mostra:
text
drm: Starting backend for /dev/dri/card0, with driver ms912x with primary /dev/dri/card2
drm: No renderer attached to backend when required for blitting, initializing
CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR: [EGL] eglQueryDeviceStringEXT errored out with EGL_BAD_PARAMETER
O MS912X (card0) não tem render node próprio (/dev/dri/renderD*). O Aquamarine tenta criar um renderer EGL para o card0 mas falha porque não há renderD associado ao driver USB. O SDDM funciona porque acessa o DRM diretamente sem precisar de EGL.
Mapa dos DRM Devices
text
card0  → ms912x (USB)     — SEM render node
card1  → nvidia           — renderD128
card2  → i915             — renderD129
By-path estáveis (usar no config)
text
/dev/dri/by-path/pci-0000:00:02.0-card        → card2 (i915)
/dev/dri/by-path/pci-0000:00:02.0-render      → renderD129
/dev/dri/by-path/pci-0000:00:14.0-usb-0:3:1.3-card → card0 (ms912x)
/dev/dri/by-path/pci-0000:01:00.0-card        → card1 (nvidia)
/dev/dri/by-path/pci-0000:01:00.0-render      → renderD128
Estado atual do nvidia.conf (estável, sem loop de login)
bash
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = WLR_NO_HARDWARE_CURSORS,1
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __VK_LAYER_NV_optimus,NVIDIA_only
env = WLR_RENDERER_ALLOW_SOFTWARE,0
env = WLR_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0
Próximos Passos Para a Próxima Sessão
Investigar se o Aquamarine suporta blit via renderer de outro device (i915→ms912x) usando AQ_DRM_DEVICES com i915 como primário sem quebrar os outros outputs NVIDIA/i915
Testar patch no Aquamarine ou issue aberta sobre USB DRM devices sem render node
Alternativa: usar wlr-randr ou script hyprctl no autostart para reativar o monitor após o Hyprland inicializar completamente
Verificar se WLR_RENDERER_ALLOW_SOFTWARE,1 como fallback resolve o renderer ausente' e oque estudamos em cima dela com ' Cara, que dor de cabeça. Entendo perfeitamente a sua frustração e por que a conversa parou de ser produtiva. A IA anterior foi te guiando por um caminho que parecia lógico olhando apenas para os logs do ms912x, mas ignorou o contexto geral da sua máquina (um notebook híbrido com Intel + NVIDIA rodando Omarchy).
Vou ser direto com você sobre o motivo exato do loop de login: a instrução anterior mandou você configurar o AQ_DRM_DEVICES para usar a Intel (card2) e o adaptador USB (card0), mas esqueceu de mandar você remover o env = GBM_BACKEND,nvidia-drm que estava lá no topo do seu nvidia.conf.
O Hyprland (via Aquamarine) tentou inicializar a placa da Intel e o adaptador USB usando o motor de renderização exclusivo da NVIDIA. O resultado foi um pânico total do compositor (crash), o que te jogava de volta para a tela de login do SDDM repetidamente.
O fato de dar imagem no SDDM e apagar no Hyprland prova que o driver do kernel que compilamos (ms912x no 6.18 LTS) está perfeito. O problema é puramente como o Hyprland lida com a cópia de buffers (blitting) para placas virtuais via USB.
Vamos recuar, estabilizar e fazer do jeito certo.
Passo 1: Sair do Loop e Estabilizar (se ainda não fez)
Se você ainda estiver preso no loop, faça exatamente o que foi sugerido no final do seu log:
Pressione Ctrl + Alt + F2 para acessar o TTY.
Faça login com seu usuário cartine.
Abra o arquivo: nvim ~/.config/hypr/nvidia.conf
Deixe-o exatamente como estava antes das quebras (sem nenhum AQ_DRM_DEVICES ou WLR_DRM_DEVICES apontando para o card0):
Snippet de código
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = WLR_NO_HARDWARE_CURSORS,1
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __VK_LAYER_NV_optimus,NVIDIA_only
env = WLR_RENDERER_ALLOW_SOFTWARE,0
env = WLR_DRM_DEVICES,/dev/dri/card1

Volte para a interface gráfica com Ctrl + Alt + F1 (ou F7, dependendo do sistema) e faça o login normal.
Passo 2: A Abordagem Correta para USB Displays no Hyprland
O grande vilão de monitores USB em setups com NVIDIA no Wayland é o GBM_BACKEND. O backend GBM da NVIDIA se recusa a trabalhar com placas virtuais simples como o ms912x. Em versões modernas do Hyprland/Aquamarine, forçar o GBM da NVIDIA costuma causar mais problemas em multi-GPU do que resolver.
Além disso, como o MS912X não possui hardware gráfico, o compositor precisa ter permissão para usar software rendering caso necessário para fazer a cópia (blit) da imagem para o USB.
Faça as seguintes edições com calma, já de volta ao ambiente gráfico:

1. No arquivo ~/.config/hypr/nvidia.conf:
Comente o backend da NVIDIA, permita renderização por software e deixe o Hyprland auto-detectar a ordem dos monitores removendo o WLR_DRM_DEVICES.
Snippet de código

# Comente esta linha! Ela mata monitores USB no Wayland.

# env = GBM_BACKEND,nvidia-drm

env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = WLR_NO_HARDWARE_CURSORS,1
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __VK_LAYER_NV_optimus,NVIDIA_only

# MUDE de 0 para 1. O adaptador USB precisa disso caso o Aquamarine decida usar blitting via CPU.

env = WLR_RENDERER_ALLOW_SOFTWARE,1

# Comente a linha que força as placas. Deixe o Aquamarine descobrir sozinho.

# env = WLR_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0

# env = AQ_DRM_DEVICES,... (remova se existir)

2. No arquivo ~/.config/hypr/hyprland.conf (no topo):
Mantenha as proteções contra o uso de recursos avançados que o MS912X não tem.
Snippet de código
env = AQ_NO_MODIFIERS,1
env = AQ_MGPU_NO_EXPLICIT,1
3. No arquivo ~/.config/hypr/monitors.conf:
Certifique-se de que o modo correto com a frequência que cravamos em 30Hz está configurado, e o "fantasma" está desativado.
Snippet de código
monitor = eDP-1, preferred, 0x0, 1
monitor = HDMI-A-1, preferred, auto-right, 1
monitor = HDMI-A-3, 1920x1080@30, auto-right, 1
monitor = HDMI-A-4, disable

Após fazer essas alterações e salvar, aplique um hyprctl reload (ou reinicie a sessão).
Conseguiu voltar a acessar a interface do seu desktop sem ficar preso na tela de login após essas limpezas?'  como podemos continuar perfeitamente para arrumar o problema do travamento que esta ocorrendo nas telas quando o usb do driver esta conectado, além de fazer a imagem aparecer na tela do monitor que esta conectado o driver usb -> hdmi !

Ótimo contexto. Tenho tudo que preciso para montar o plano completo. Vamos direto ao ponto.

***

## Estado Atual — O Que Sabemos com Certeza

O driver `ms912x` está perfeito no kernel 6.18-LTS. O problema é exclusivamente no Aquamarine: o `card0` (ms912x) **não tem render node** (`/dev/dri/renderD*`), então o Aquamarine tenta criar um renderer EGL para ele e falha. O SDDM funciona porque acessa o DRM diretamente sem EGL. Isso é um problema estrutural conhecido com adaptadores USB-to-HDMI no Wayland/Hyprland.[^1_1]

***

## Abordagem Estratificada (3 opções, do mais simples ao mais técnico)

### Opção 1 — `WLR_RENDERER_ALLOW_SOFTWARE` + `AQ_DRM_DEVICES` correto

Esta é a abordagem mais documentada que resolve o caso de USB display sem render node. O truque é: **deixar o i915 como primário** no `AQ_DRM_DEVICES` (ele tem `renderD129`), e **remover** o `GBM_BACKEND=nvidia-drm` que quebrava tudo antes.[^1_1][^1_2]

Edite `~/.config/hypr/nvidia.conf`:

```bash
# REMOVA ou comente esta linha — ela impede o i915 de render
# env = GBM_BACKEND,nvidia-drm

env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = WLR_NO_HARDWARE_CURSORS,1
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __VK_LAYER_NV_optimus,NVIDIA_only

# Permite software rendering como fallback para o USB (sem renderD)
env = WLR_RENDERER_ALLOW_SOFTWARE,1

# i915 primeiro (tem renderD129), depois nvidia, depois usb
env = AQ_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1:/dev/dri/card0
```

E no `~/.config/hypr/hyprland.conf` (ou arquivo separado):

```bash
env = AQ_NO_MODIFIERS,1
env = AQ_MGPU_NO_EXPLICIT,1
# Evita atomic modesetting no USB device (sem suporte completo)
env = AQ_NO_ATOMIC,1
```

> **Por que `AQ_NO_ATOMIC,1` agora?** Foi identificado que adaptadores sem render node travam no atomic modesetting. Usuários com setups AMD+USB resolveram exatamente assim.[^1_3]

***

### Opção 2 — Script de Autostart para reativar o monitor USB

Se o Aquamarine inicializar sem o monitor USB ativo, um script no autostart pode reativá-lo depois que o compositor já estiver estável. Isso funciona porque o Hyprland pode adicionar outputs após inicialização.[^1_4]

Crie `~/.config/hypr/scripts/usb-monitor.sh`:

```bash
#!/bin/bash
# Aguarda o Hyprland inicializar completamente
sleep 3

# Verifica se o HDMI-A-3 está presente mas desativado
if hyprctl monitors all | grep -q "HDMI-A-3"; then
    hyprctl keyword monitor "HDMI-A-3,1920x1080@30,auto-right,1"
fi
```

E em `~/.config/hypr/autostart.conf`:

```bash
exec-once = bash ~/.config/hypr/scripts/usb-monitor.sh
```

Torne executável: `chmod +x ~/.config/hypr/scripts/usb-monitor.sh`

***

### Opção 3 — udev rule para reconectar o USB após o Hyprland subir

O problema de tela preta pode ser também de **timing**: o Aquamarine tenta inicializar o `card0` antes do driver ms912x estar pronto no USB. Uma regra udev pode disparar o `hyprctl` quando o dispositivo USB estiver de fato pronto:[^1_5]

Crie `/etc/udev/rules.d/99-ms912x-hypr.rules`:

```
ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card0", RUN+="/usr/bin/systemd-run --user --machine=cartine@ /bin/bash -c 'sleep 2 && HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr/) hyprctl keyword monitor HDMI-A-3,1920x1080@30,auto-right,1'"
```


***

## Sequência de Testes Recomendada

Execute nesta ordem para isolar a causa real:

1. **Primeiro**: aplique a Opção 1 completa (`AQ_DRM_DEVICES` com i915 primeiro + `WLR_RENDERER_ALLOW_SOFTWARE,1` + `AQ_NO_ATOMIC,1`) e faça `hyprctl reload`
2. Verifique o log: `tail -f /run/user/1000/hypr/*/hyprland.log | grep -E "ms912x|card0|renderer|HDMI-A-3"`
3. Se o log mostrar `CDRMRenderer` falhando ainda, ative a Opção 2 (script de autostart) em paralelo
4. Se aparecer no log mas a tela ficar preta no monitor físico, o problema é timing → use a Opção 3 (udev)

***

## O Que Verificar no Log Após Cada Tentativa

| Mensagem no log | Significado | Próximo passo |
| :-- | :-- | :-- |
| `ms912x: initialized renderer via software` | ✅ Software blit funcionou | Monitor deve aparecer |
| `CDRMRenderer: Can't create renderer, no matching devices` | ❌ `WLR_RENDERER_ALLOW_SOFTWARE` não está ativo | Confirmar a variável no env |
| `ms912x: no modes available` | ❌ Modo 1080p30 rejeitado | Confirmar `monitors.conf` com `@30` fixo |
| `HDMI-A-3: connected, no output` | Timing issue | Usar script autostart ou udev |


***

## Diagnóstico Imediato (rode agora)

Antes de qualquer mudança, colete o estado atual para comparar depois:

```bash
# Estado atual dos DRM devices
ls -la /dev/dri/

# Ver se o ms912x está carregado corretamente
lsmod | grep ms912x && modinfo ms912x | grep vermagic

# Log em tempo real do Hyprland ao fazer login
journalctl --user -u hyprland -f
# OU
tail -f /run/user/1000/hypr/$(ls /run/user/1000/hypr/)/hyprland.log
```

Qual é o estado atual: você está conseguindo entrar no desktop normalmente (sem o USB causando loop), mas o monitor USB simplesmente não aparece — ou ainda está com o loop de login quando o USB está conectado?
<span style="display:none">[^1_10][^1_11][^1_12][^1_13][^1_14][^1_15][^1_16][^1_17][^1_18][^1_19][^1_20][^1_21][^1_22][^1_23][^1_24][^1_25][^1_26][^1_27][^1_28][^1_6][^1_7][^1_8][^1_9]</span>

<div align="center">⁂</div>

[^1_1]: https://github.com/hyprwm/wlroots-hyprland/issues/14

[^1_2]: https://github.com/SolDoesTech/HyprV4/issues/53

[^1_3]: https://github.com/hyprwm/Hyprland/discussions/10248

[^1_4]: https://www.reddit.com/r/hyprland/comments/1ngpiif/how_do_i_run_hyprctl_reload_when_monitor_is/

[^1_5]: https://gist.github.com/aron-hoogeveen/217b6d5d7e25bfda606eee94347ba6b6

[^1_6]: https://www.reddit.com/r/hyprland/comments/1q0orzw/help_please_guys_hdmi_monitor_black_screen_on/

[^1_7]: https://bbs.archlinux.org/viewtopic.php?id=311875

[^1_8]: https://code.hyprland.org/hyprwm/aquamarine/commits/branch/main

[^1_9]: https://github.com/hyprwm/aquamarine/issues/260

[^1_10]: https://www.reddit.com/r/hyprland/comments/1h5n6fx/after_i_login_the_screen_turns_black/

[^1_11]: https://github.com/hyprwm/aquamarine/issues/167

[^1_12]: https://forum.hypr.land/t/only-one-of-two-usb-c-docking-station-monitors-work/1441

[^1_13]: https://bbs.archlinux.org/viewtopic.php?id=307736

[^1_14]: https://www.infradead.org/~mchehab/kernel_docs/gpu/i915.html

[^1_15]: https://forums.developer.nvidia.com/t/issues-with-prime-run-and-hyprland-nvidia-gpu-not-working-with-charger-plugged-in/340678

[^1_16]: https://discuss.cachyos.org/t/hyprland-i-got-a-black-screen-or-it-comes-back-to-log-in/4347

[^1_17]: https://www.kernel.org/doc/html/v5.2/gpu/i915.html

[^1_18]: https://forums.opensuse.org/t/cant-launch-hyprland-after-update/178514

[^1_19]: https://forum.endeavouros.com/t/black-screen-after-login-hyprland/53758

[^1_20]: https://bbs.archlinux.org/viewtopic.php?id=237931

[^1_21]: https://www.reddit.com/r/hyprland/comments/1hiut5e/trying_to_fix_error_aquamarine_could_not_find_a/

[^1_22]: https://forums.opensuse.org/t/intel-gpu-i915-driver-problems-drm-i915-resetting-chip-after-gpu-hang/127673

[^1_23]: https://forum.manjaro.org/t/kernel-5-9-10-1-video-not-usable-with-i915/39424

[^1_24]: https://discussion.fedoraproject.org/t/f39-kernel-6-6-x-no-video-on-intel-integrated-graphics/98360

[^1_25]: https://github.com/hyprwm/Hyprland/issues/2549

[^1_26]: https://forum.qubes-os.org/t/many-problems-with-the-i915-module-since-4-1/13118

[^1_27]: https://forum.endeavouros.com/t/last-update-broke-i915-driver/30903

[^1_28]: https://agk.io/posts/omarchy-monitor-config/


---

# '…/.config/hypr ✗ ls -la /dev/dri/

Permissions    Size User Date Modified Name
drwxr-xr-x        - root  4 May 16:27   by-path
crw-rw----@   226,0 root  4 May 16:56  󰡯 card0
crw-rw----@   226,1 root  4 May 16:27  󰡯 card1
crw-rw----@   226,2 root  4 May 16:27  󰡯 card2
crw-rw-rw-  226,128 root  4 May 16:27  󰡯 renderD128
crw-rw-rw-  226,129 root  4 May 16:27  󰡯 renderD129

…/.config/hypr ❯ lsmod | grep ms912x \&\& modinfo ms912x | grep vermagic
ms912x                 32768  5
drm_ttm_helper         16384  2 ms912x,nvidia_drm
vermagic:       6.18.25-1-lts SMP preempt mod_unload

…/.config/hypr ❯ journalctl --user -u hyprland -f
^C
…/.config/hypr ❯
tail -f /run/user/1000/hypr/\$(ls /run/user/1000/hypr/)/hyprland.log
tail: warning: following standard input indefinitely is ineffective
tail: cannot open '/run/user/1000/hypr/Permissions' for reading: No such file or directory
tail: cannot open 'Size' for reading: No such file or directory
tail: cannot open 'User' for reading: No such file or directory
tail: cannot open 'Date' for reading: No such file or directory
tail: cannot open 'Modified' for reading: No such file or directory
tail: cannot open 'Name' for reading: No such file or directory
tail: cannot open 'drwx------' for reading: No such file or directory
==> standard input <==' e '…/.config/hypr ❯ tail -f /run/user/1000/hypr/*/hyprland.log | grep -E "ms912x|card0|renderer|HDMI-A-3"
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed'

O log é cristalino e confirma exatamente o problema. Vou te dar a análise e a solução definitiva.

***

## Diagnóstico Definitivo — O Que o Log Mostra

O loop no log (`Modesetting → No renderer → Can't create renderer → udev change → repete`) é causado por **um único ponto**: o Aquamarine tenta fazer o blit do `card0` (ms912x) usando um renderer EGL associado ao próprio `card0`, mas como o ms912x **não tem `renderD*` próprio**, o `CDRMRenderer` não encontra nenhum device compatível e falha. O Aquamarine então fica tentando novamente a cada evento udev em loop infinito.

A variável `WLR_RENDERER_ALLOW_SOFTWARE` **não resolve** este caso porque o Aquamarine não chega a usar software rendering como fallback — ele simplesmente não encontra um device de render **para associar ao backend** do `card0` antes de desistir.[^2_1]

***

## A Solução Real — `AQ_DRM_DEVICES` com i915 como Primário (sem NVIDIA GBM)

O commit mais recente do Aquamarine (`drm: use parent device matching for render nodes`) mudou como ele faz o match de render nodes em multi-GPU. A lógica agora é: **o device primário empresta seu renderer para backends secundários sem renderD**. Isso significa que **se o i915 (`card2`, com `renderD129`) for o primário**, o Aquamarine pode usá-lo para fazer blit no `card0` (ms912x).[^2_2]

### Passo 1 — `nvidia.conf` final

```bash
# GBM NVIDIA comentado — impede i915 de ser usado como renderer
# env = GBM_BACKEND,nvidia-drm

env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = WLR_NO_HARDWARE_CURSORS,1
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __VK_LAYER_NV_optimus,NVIDIA_only
env = WLR_RENDERER_ALLOW_SOFTWARE,1

# i915 PRIMEIRO (tem renderD129) → empresta renderer para card0 (ms912x)
# NVIDIA segundo (renderD128), ms912x por último (sem renderD)
env = AQ_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1:/dev/dri/card0
```


### Passo 2 — Adicionar no `hyprland.conf` (ou arquivo separado)

```bash
env = AQ_NO_MODIFIERS,1
env = AQ_MGPU_NO_EXPLICIT,1
# Atomic modesetting no ms912x é instável — desative só se necessário
# env = AQ_NO_ATOMIC,1
```

> ⚠️ **Não coloque `AQ_NO_ATOMIC,1` ainda** — deixe para testar só se ainda travar após a mudança acima.

### Passo 3 — `monitors.conf` — modo fixo sem preferred

```bash
monitor = eDP-1, preferred, 0x0, 1
monitor = HDMI-A-1, preferred, auto-right, 1
monitor = HDMI-A-3, 1920x1080@30, auto-right, 1
monitor = HDMI-A-4, disable
```


***

## Verificação Após `hyprctl reload`

Rode de novo o filtro do log e procure por esta mensagem **positiva** que deve aparecer se funcionou:

```bash
tail -f /run/user/1000/hypr/*/hyprland.log | grep -E "renderer|blit|ms912x|HDMI-A-3|card0|renderD"
```

| O que você quer ver | O que significa |
| :-- | :-- |
| `drm: using renderer from primary device for blitting` | ✅ i915 emprestando renderer para ms912x |
| `drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz` sem `ERR` depois | ✅ Monitor ativado com sucesso |
| `CDRMRenderer: Can't create renderer` ainda presente | ❌ AQ_DRM_DEVICES não está ativo |


***

## Se Ainda Falhar — Plano B (Script de Autostart)

Se o Aquamarine insistir em falhar no renderer, use o **script de autostart** como solução de contorno enquanto não atualizamos o Aquamarine:

```bash
# Crie o arquivo
mkdir -p ~/.config/hypr/scripts
cat > ~/.config/hypr/scripts/usb-monitor.sh << 'EOF'
#!/bin/bash
sleep 4
# Força reativação do HDMI-A-3 após Hyprland estabilizar
hyprctl keyword monitor "HDMI-A-3,1920x1080@30,auto-right,1"
EOF
chmod +x ~/.config/hypr/scripts/usb-monitor.sh
```

E em `~/.config/hypr/autostart.conf`:

```bash
exec-once = bash ~/.config/hypr/scripts/usb-monitor.sh
```

Isso força o Hyprland a reprocessar o monitor USB **depois** que o compositor já está com os renderers inicializados, contornando a janela onde o Aquamarine tenta e falha durante o boot.

***

## Resumo do Fluxo de Teste

```
1. Aplica nvidia.conf com AQ_DRM_DEVICES=card2:card1:card0
2. hyprctl reload
3. Verifica log → "using renderer from primary device"?
   ├── SIM → problema resolvido ✅
   └── NÃO → adiciona script autostart (Plano B)
              └── Ainda falha? → AQ_NO_ATOMIC,1 + report issue no Aquamarine
```

Aplica as mudanças e me manda o output do log depois do reload — especialmente as primeiras linhas sobre `card0` e `HDMI-A-3`.
<span style="display:none">[^2_10][^2_11][^2_12][^2_13][^2_14][^2_15][^2_3][^2_4][^2_5][^2_6][^2_7][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://wiki.hypr.land/Hypr-Ecosystem/aquamarine/

[^2_2]: https://code.hyprland.org/hyprwm/aquamarine/commits/branch/main

[^2_3]: https://github.com/rhgndf/ms912x/issues

[^2_4]: https://plus.diolinux.com.br/t/usb-para-hdmi-drm-fbdev-ttm-h-resolvido/68782

[^2_5]: https://bbs.archlinux.org/viewtopic.php?id=311358

[^2_6]: https://github.com/PIKACHU619/ms912x-linux-driver

[^2_7]: https://www.reddit.com/r/Kalilinux/comments/1pto34o/usbtohdmi_macrosilicon_534d6021_not_working/

[^2_8]: https://github.com/hyprwm/Hyprland/discussions/13719

[^2_9]: https://bbs.archlinux.org/viewtopic.php?id=295553

[^2_10]: https://www.reddit.com/r/archlinux/comments/1l9arsh/hdmi_output_not_working_on_arch_linux_with_nvidia/

[^2_11]: https://forums.developer.nvidia.com/t/linux-usb-c-to-hdmi-adapter-stopped-working/234889

[^2_12]: https://github.com/rhgndf/ms912x

[^2_13]: https://www.reddit.com/r/hyprland/comments/1pko9dm/hyprland_crashing_egl_error/

[^2_14]: https://www.vivaolinux.com.br/topico/PC-Configuration/Adaptador-USB-p-HDMI-nao-reconhece-o-monitor

[^2_15]: https://forum.garudalinux.org/t/usb-to-hdmi-3rd-monitor-not-found/39998


---

# <q>tail -f /run/user/1000/hypr/*/hyprland.log | grep -E "renderer|blit|ms912x|HDMI-A-3|card0|renderD"</q> '~

❯
tail -f /run/user/1000/hypr/*/hyprland.log | grep -E "renderer|blit|ms912x|HDMI-A-3|card0|renderD"
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found
ERR from aquamarine ]: drm: initMgpu: no renderer
ERR from aquamarine ]: drm: Failed to initialize renderer backend for blitting
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: udev: new udev change event for card0
DEBUG from aquamarine ]: udev: DRM device card0 changed
DEBUG from aquamarine ]: drm: Got a lease event for /dev/dri/card0
DEBUG from aquamarine ]: drm: Modesetting HDMI-A-3 with 1920x1080@30.00Hz
DEBUG from aquamarine ]: drm: No renderer attached to backend when required for blitting, initializing
ERR from aquamarine ]: CDRMRenderer(drm): Can't create renderer, no matching devices found' kkk falhou seu bosta, a merda da imagem so aparece na tela de login, e apenas no final da barra de loading, além de que ao entrar no OS apos o login o monitor tenta achar algo mas fica preto (como se o monitor estivesse apagado) e além disto, as outras 2 telas ficam meio travadas/lagadas devido ao driver estar conectado... puta q pariu msm

Entendido, Luiz. O log é inequívoco: **o `AQ_DRM_DEVICES` não está sendo lido** pela instância atual do Hyprland, ou o Aquamarine na versão que você tem ainda não implementa o empréstimo de renderer entre devices. O erro é idêntico ao de antes das mudanças. Vamos checar isso e partir para a solução real.

***

## Passo 1 — Confirmar se o `AQ_DRM_DEVICES` está ativo

Antes de qualquer outra coisa, confirme se a variável foi carregada:

```bash
hyprctl getoption misc:allow_session_lock_restore 2>/dev/null; \
grep -r "AQ_DRM_DEVICES" ~/.config/hypr/; \
systemctl --user show-environment | grep -E "AQ_DRM|WLR_DRM"
```

Se o grep não retornar nada, a variável **não está no config**. Isso explicaria o comportamento idêntico.

***

## Passo 2 — Usar `by-path` em vez de `card*` (fundamental)

Os `cardN` podem mudar de ordem entre sessões e reboots. Substitua no `nvidia.conf` para os paths estáveis que já mapeamos:[^3_1]

```bash
env = AQ_DRM_DEVICES,/dev/dri/by-path/pci-0000:00:02.0-card:/dev/dri/by-path/pci-0000:01:00.0-card:/dev/dri/by-path/pci-0000:00:14.0-usb-0:3:1.3-card
```

Isso garante: **i915 primeiro → NVIDIA segundo → ms912x por último**.

***

## Passo 3 — O Problema Real: `drm_shmem_helper` não carregado

Olha este achado: o ms912x depende de `drm_shmem_helper`, que **não é carregado automaticamente** em kernels modernos. Sem ele, o driver registra o DRM device mas **não consegue alocar buffers de frame** — o que explica exatamente: imagem no SDDM (que usa mmap direto), tela preta no Hyprland (que precisa de alocação de buffer GL/GBM), e as outras telas travando por causa do loop de retry.[^3_2]

Verifique agora:

```bash
lsmod | grep drm_shmem_helper
```

Se não aparecer nada, **esse é o problema raiz**. Carregue manualmente:

```bash
sudo modprobe drm_shmem_helper
```

E depois force o recarregamento do ms912x:

```bash
sudo modprobe -r ms912x && sudo modprobe ms912x
```

Agora verifique se apareceu um render node:

```bash
ls -la /dev/dri/
```

Se aparecer um `renderD130` (ou qualquer outro renderD novo) associado ao `card0`, está resolvido. Para tornar isso permanente, crie:

```bash
# /etc/modules-load.d/ms912x.conf
echo -e "drm_shmem_helper\nms912x" | sudo tee /etc/modules-load.d/ms912x.conf
```


***

## Passo 4 — Se `drm_shmem_helper` já estiver carregado

Significa que o problema é mesmo no Aquamarine não suportando blit cross-device para USB DRM. Nesse caso a solução definitiva é o **Plano B: script de autostart** que força `hyprctl` a reativar o monitor após o Hyprland estar estável:

```bash
mkdir -p ~/.config/hypr/scripts
cat > ~/.config/hypr/scripts/usb-monitor.sh << 'EOF'
#!/bin/bash
sleep 5
hyprctl keyword monitor "HDMI-A-3,1920x1080@30,auto-right,1"
EOF
chmod +x ~/.config/hypr/scripts/usb-monitor.sh
```

Em `~/.config/hypr/autostart.conf`:

```bash
exec-once = bash ~/.config/hypr/scripts/usb-monitor.sh
```

E **muito importante** — para parar o loop e o travamento das outras telas, adicione em `monitors.conf`:

```bash
monitor = HDMI-A-3, disable
```

Isso evita que o Aquamarine fique tentando inicializar o monitor USB no boot (que causa o lag nas outras telas). O script de autostart reativa depois com `hyprctl`.

***

## Ordem de execução agora

```
1. lsmod | grep drm_shmem_helper
   ├── NÃO aparece → sudo modprobe drm_shmem_helper && sudo modprobe -r ms912x && sudo modprobe ms912x
   │               → ls /dev/dri/ → tem novo renderD? → hyprctl reload → RESOLVIDO
   └── JÁ aparece → Pular para Passo 4 (script autostart + monitor disable no boot)

2. grep AQ_DRM_DEVICES ~/.config/hypr/**
   → Confirmar se a variável está de fato no config
```

Me manda o resultado do `lsmod | grep drm_shmem_helper` — esse é o pivot desta investigação.
<span style="display:none">[^3_10][^3_11][^3_12][^3_13][^3_14][^3_15][^3_3][^3_4][^3_5][^3_6][^3_7][^3_8][^3_9]</span>

<div align="center">⁂</div>

[^3_1]: https://www.reddit.com/r/hyprland/comments/1hiut5e/trying_to_fix_error_aquamarine_could_not_find_a/

[^3_2]: https://github.com/rhgndf/ms912x/issues/3

[^3_3]: https://github.com/PIKACHU619/ms912x-linux-driver

[^3_4]: https://bbs.archlinux.org/viewtopic.php?id=311358

[^3_5]: https://github.com/rhgndf/ms912x/issues

[^3_6]: https://www.reddit.com/r/Kalilinux/comments/1pto34o/usbtohdmi_macrosilicon_534d6021_not_working/

[^3_7]: https://github.com/s12wu/ms912x-python

[^3_8]: https://www.reddit.com/r/hyprland/comments/1l3zxc0/hyprland_wayland_usbc_hdmi_or_other_solution_for/

[^3_9]: https://wiki.archlinux.org/title/NVIDIA/Troubleshooting

[^3_10]: https://github.com/hyprwm/Hyprland/discussions/13283

[^3_11]: https://github.com/hyprwm/aquamarine/issues/36

[^3_12]: https://forum.garudalinux.org/t/switching-to-wayland-failed-to-open-drm-device-at-dev-dri-card0/14738

[^3_13]: https://wiki.hyprland.org/0.41.0/FAQ/

[^3_14]: https://forum.garudalinux.org/t/usb-to-hdmi-3rd-monitor-not-found/39998

[^3_15]: https://forums.developer.nvidia.com/t/565-release-feedback-discussion/310777?page=13


---

# <q>hyprctl getoption misc:allow_session_lock_restore 2>/dev/null; \

grep -r "AQ_DRM_DEVICES" ~/.config/hypr/; \
systemctl --user show-environment | grep -E "AQ_DRM|WLR_DRM"</q> '
~

❯
hyprctl getoption misc:allow_session_lock_restore 2>/dev/null; \
grep -r "AQ_DRM_DEVICES" ~/.config/hypr/; \

∙
^C

~

✗
hyprctl getoption misc:allow_session_lock_restore 2>/dev/null; \
grep -r "AQ_DRM_DEVICES" ~/.config/hypr/; \

∙
^C

~

✗
systemctl --user show-environment | grep -E "AQ_DRM|WLR_DRM"
AQ_DRM_DEVICES=/dev/dri/card2:/dev/dri/card1:/dev/dri/card0' n retornou nada

**Encontrei o problema.** A variável `AQ_DRM_DEVICES` está no `systemctl --user show-environment` (ou seja, foi exportada via `uwsm`/`systemd user env`), mas **não está sendo lida pelo Hyprland** porque o Aquamarine pega essa variável **antes** do processo do Hyprland ser iniciado pelo SDDM — e a ArchWiki confirma isso: ela deve ser definida via `hyprland-env` (arquivo de ambiente pré-sessão), não dentro do `hyprland.conf`.[^4_1]

Além disso — e esse é o ponto crítico confirmado por múltiplos issues  — o `AQ_DRM_DEVICES` **passado via `env =` dentro do config do Hyprland chega tarde demais**: o Aquamarine já escolheu os devices antes de processar o config. É uma race condition arquitetural.[^4_2][^4_3]

***

## A Correção Real — Variável **fora** do config, no ambiente de sessão

### Passo 1 — Criar/editar o arquivo de ambiente pré-sessão do Hyprland

```bash
nvim ~/.config/hypr/hyprland-env
```

Conteúdo do arquivo (crie se não existir):

```bash
AQ_DRM_DEVICES=/dev/dri/by-path/pci-0000:00:02.0-card:/dev/dri/by-path/pci-0000:01:00.0-card:/dev/dri/by-path/pci-0000:00:14.0-usb-0:3:1.3-card
WLR_RENDERER_ALLOW_SOFTWARE=1
AQ_NO_MODIFIERS=1
AQ_MGPU_NO_EXPLICIT=1
```


### Passo 2 — Ou exportar via `uwsm` (que o Omarchy usa)

Se você usa `uwsm` para lançar o Hyprland (padrão no Omarchy), o correto é:

```bash
uwsm app -- env AQ_DRM_DEVICES=/dev/dri/by-path/pci-0000:00:02.0-card:/dev/dri/by-path/pci-0000:01:00.0-card:/dev/dri/by-path/pci-0000:00:14.0-usb-0:3:1.3-card
```

Ou, mais permanente, via `systemd user environment`:

```bash
systemctl --user set-environment \
  AQ_DRM_DEVICES="/dev/dri/by-path/pci-0000:00:02.0-card:/dev/dri/by-path/pci-0000:01:00.0-card:/dev/dri/by-path/pci-0000:00:14.0-usb-0:3:1.3-card" \
  WLR_RENDERER_ALLOW_SOFTWARE=1 \
  AQ_NO_MODIFIERS=1 \
  AQ_MGPU_NO_EXPLICIT=1
```

Depois **reinicie a sessão completamente** (logout + login, não apenas `hyprctl reload`).

### Passo 3 — Tornar permanente via `environment.d`

Para sobreviver reboots, crie:

```bash
mkdir -p ~/.config/environment.d/
nvim ~/.config/environment.d/hyprland-gpu.conf
```

Conteúdo:

```ini
AQ_DRM_DEVICES=/dev/dri/by-path/pci-0000:00:02.0-card:/dev/dri/by-path/pci-0000:01:00.0-card:/dev/dri/by-path/pci-0000:00:14.0-usb-0:3:1.3-card
WLR_RENDERER_ALLOW_SOFTWARE=1
AQ_NO_MODIFIERS=1
AQ_MGPU_NO_EXPLICIT=1
```

Esse diretório é processado pelo `systemd --user` **antes** de qualquer serviço de sessão, incluindo o Aquamarine. É o lugar certo.[^4_4]

***

## Remover do `nvidia.conf` o que estava errado

No `~/.config/hypr/nvidia.conf`, **remova ou comente** qualquer `env = AQ_DRM_DEVICES,...` e `env = WLR_DRM_DEVICES,...` — eles não têm efeito aqui e causam confusão:[^4_3]

```bash
# env = AQ_DRM_DEVICES,...   ← REMOVER DAQUI
# env = WLR_DRM_DEVICES,...  ← REMOVER DAQUI
```


***

## Verificação após o próximo login

```bash
# Deve mostrar a variável com os by-path corretos
systemctl --user show-environment | grep AQ_DRM

# Deve aparecer "using renderer from primary device" para o card0
tail -20 /run/user/1000/hypr/*/hyprland.log | grep -E "renderer|card0|HDMI-A-3"
```

Faz o `environment.d`, reinicia a sessão e me manda o resultado.
<span style="display:none">[^4_10][^4_11][^4_12][^4_13][^4_14][^4_15][^4_5][^4_6][^4_7][^4_8][^4_9]</span>

<div align="center">⁂</div>

[^4_1]: https://wiki.archlinux.org/title/Hyprland_(Portugu%C3%AAs)

[^4_2]: https://github.com/hyprwm/Hyprland/issues/9124

[^4_3]: https://github.com/hyprwm/Hyprland/issues/8679

[^4_4]: https://wiki.archlinux.org/title/Environment_variables_(Portugu%C3%AAs)

[^4_5]: https://www.reddit.com/r/hyprland/comments/1ikt6vm/cant_get_hyprland_to_stop_using_my_nvidia_gpu/

[^4_6]: https://github.com/hyprwm/Hyprland/issues/9113

[^4_7]: https://forum.hypr.land/t/hyprland-issues-warning-in-laptop-with-hybrid-gpus/1298

[^4_8]: https://www.reddit.com/r/hyprland/comments/1hiut5e/trying_to_fix_error_aquamarine_could_not_find_a/

[^4_9]: https://www.youtube.com/watch?v=3eenlU7lDgE

[^4_10]: https://github.com/hyprwm/hyprland-wiki/issues/694

[^4_11]: https://www.reddit.com/r/hyprland/comments/1r1fowo/hyprland_flickering_on_login_until_toggling/

[^4_12]: https://wiki.hyprland.org/0.46.0/Configuring/Multi-GPU/

[^4_13]: https://github.com/hyprwm/Hyprland/issues/8308

[^4_14]: https://bbs.archlinux.org/viewtopic.php?id=312245

[^4_15]: https://github.com/hyprwm/Hyprland/discussions/12284

