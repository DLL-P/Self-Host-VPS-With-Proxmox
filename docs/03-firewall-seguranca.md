# Firewall e segurança

A VPS fica exposta à internet para hospedar o serviço configurado, o que
exige limitar a superfície de ataque. O provisionamento aplica as camadas
descritas abaixo.

## 1. Firewall do Proxmox (`scripts/03-firewall.sh`)

- Habilita o firewall do Proxmox no nível do Datacenter e da VM.
- Política padrão de entrada: **DROP**.
- Libera **SSH (22/tcp)** apenas para `ADMIN_SSH_SOURCE_IP` (definido em
  `config/vm.env`; evitar `0.0.0.0/0` em produção).
- Libera as portas listadas em `SERVICE_PORTS` para qualquer origem — é
  assim que as conexões externas chegam ao serviço.

## 2. Firewall dentro da VM (UFW, via cloud-init)

- `ufw default deny incoming`, com liberação de OpenSSH e das portas do
  serviço configuradas (aplicado automaticamente na primeira
  inicialização).
- Camada adicional de defesa, caso o firewall do Proxmox seja alterado.

## 3. Fail2ban

- Instalado e habilitado por padrão dentro da VM. Bloqueia IPs após
  tentativas de login SSH malsucedidas repetidas.

## 4. Hardening de SSH

- Login root desabilitado (`PermitRootLogin no`).
- Autenticação por senha desabilitada (`PasswordAuthentication no`) — o
  acesso é feito apenas com a chave SSH informada em `config/vm.env`.
- Usuário definido em `CI_USER` criado com sudo sem senha.

## Recomendações adicionais

- Restringir `ADMIN_SSH_SOURCE_IP` a um IP fixo, sempre que possível. Na
  ausência de IP fixo, considerar uma VPN (Wireguard, Tailscale) para
  administração, em vez de deixar SSH aberto.
- `unattended-upgrades` já vem instalado, para atualizações automáticas.
- Configurar backup da VM no Proxmox (Datacenter → Backup) antes de
  colocar o serviço em produção.
- Caso o mesmo host hospede outras VMs, garantir que a bridge/rede desta
  VM não tenha rota para redes internas de outras VMs.
- Ajustar `--cpulimit` / `--memory` (definidos em `vm.env`) para que o
  serviço não afete outras VMs no mesmo host.
