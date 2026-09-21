# vps-host

Provisionamento de uma VPS (VM) em um host Proxmox VE para servir como
servidor de jogos de um cliente, com acesso via IP externo, firewall e
hardening básico já configurados.

## Início rápido

1. Leia `docs/01-visao-geral.md`.
2. Copie `config/vm.env.example` para `config/vm.env` e preencha os
   valores (VMID, IP, rede, portas do jogo, chave SSH do cliente).
3. No host Proxmox:
   ```bash
   cd scripts
   chmod +x *.sh
   ./provision.sh
   ```
4. Instale o servidor de jogos (exemplo pronto de Minecraft em
   `examples/minecraft/`) — veja `docs/04-servidor-de-jogos.md`.

## Documentação

- [`docs/01-visao-geral.md`](docs/01-visao-geral.md) — pré-requisitos e passo a passo.
- [`docs/02-rede-ip-externo.md`](docs/02-rede-ip-externo.md) — IP público direto (bridged) vs NAT/port-forward.
- [`docs/03-firewall-seguranca.md`](docs/03-firewall-seguranca.md) — firewall do Proxmox, UFW, fail2ban, hardening de SSH.
- [`docs/04-servidor-de-jogos.md`](docs/04-servidor-de-jogos.md) — portas por jogo e exemplo com Docker.
- [`docs/05-passo-a-passo-completo.md`](docs/05-passo-a-passo-completo.md) — guia único do zero até entregar o acesso ao cliente.

## Estrutura

```
config/            vm.env.example -> variáveis de configuração
cloud-init/        template aplicado na primeira boot da VM (usuário, SSH, UFW, fail2ban)
scripts/           scripts para rodar no HOST PROXMOX (criar VM, NAT, firewall)
examples/minecraft/ exemplo de servidor de jogos via Docker
docs/              documentação detalhada
```
