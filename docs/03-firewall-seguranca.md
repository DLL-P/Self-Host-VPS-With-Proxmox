# Firewall e segurança

Como a VPS vai ficar exposta à internet para um servidor de jogos, é
importante limitar a superfície de ataque. O provisionamento já aplica as
seguintes camadas:

## 1. Firewall do Proxmox (`scripts/03-firewall.sh`)

- Habilita o firewall do Proxmox no nível do Datacenter e da VM.
- Política padrão de entrada: **DROP** (bloqueia tudo por padrão).
- Libera **SSH (22/tcp)** apenas para `ADMIN_SSH_SOURCE_IP` (defina o IP do
  administrador em `config/vm.env` — evite deixar `0.0.0.0/0` em produção).
- Libera as portas listadas em `GAME_PORTS` para qualquer origem (é assim
  que os jogadores conectam).

## 2. Firewall dentro da VM (UFW, via cloud-init)

- `ufw default deny incoming` + libera OpenSSH e as portas de jogo
  configuradas (aplicado automaticamente no primeiro boot).
- Camada extra de defesa caso o firewall do Proxmox seja alterado sem
  querer.

## 3. Fail2ban

- Instalado e habilitado por padrão dentro da VM, bloqueia IPs após
  tentativas de login SSH malsucedidas repetidas.

## 4. Hardening de SSH

- Login root desabilitado (`PermitRootLogin no`).
- Autenticação por senha desabilitada (`PasswordAuthentication no`) —
  **só funciona login com a chave SSH** informada em `config/vm.env`.
- Usuário `cliente` criado com sudo sem senha (ajuste `CI_USER` se quiser
  outro nome).

## Recomendações adicionais

- **Restrinja `ADMIN_SSH_SOURCE_IP`** ao seu IP fixo sempre que possível.
  Se não tiver IP fixo, considere uma VPN (Wireguard/Tailscale) para
  administração em vez de deixar SSH aberto ao mundo.
- **Atualizações automáticas**: `unattended-upgrades` já vem instalado.
- **Backups**: configure backup da VM no Proxmox (Datacenter -> Backup)
  antes de colocar o servidor em produção para o cliente.
- **Isolamento**: se o mesmo host Proxmox hospedar VMs de outros clientes,
  garanta que a bridge/rede da VM do servidor de jogos não tenha rota para
  as redes internas de outros clientes.
- **Limite de recursos**: use `--cpulimit` / `--memory` (já configurado em
  `vm.env`) para o servidor de jogos não impactar outras VMs no mesmo host.
