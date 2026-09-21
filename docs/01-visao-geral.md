# Visão geral

Este repositório contém tudo o que é necessário para provisionar, em um host
Proxmox VE já instalado, uma VM (VPS) para um cliente, com acesso via IP
externo, pronta para rodar um servidor de jogos.

## Pré-requisitos

- Um host Proxmox VE já instalado e acessível (via SSH ou console web
  "Shell") — este repositório **não instala o Proxmox em si**, apenas
  provisiona a VM dentro dele. Se ainda não tiver o Proxmox instalado, veja
  a seção "Instalando o Proxmox" abaixo.
- Pelo menos um IP público disponível para a VM (dedicado à VM, ou o IP do
  próprio host caso vá usar NAT/port-forward — veja
  `docs/02-rede-ip-externo.md`).
- Uma chave SSH pública do cliente (`~/.ssh/id_rsa.pub` ou equivalente).
- Acesso root ao host Proxmox para rodar os scripts.

## Passo a passo rápido

1. Copie `config/vm.env.example` para `config/vm.env` e preencha os valores
   (VMID, IP, bridge, portas do jogo, etc). Veja comentários no próprio
   arquivo.
2. Copie a pasta do repositório para o host Proxmox (ex: `git clone` ou
   `scp -r`).
3. No host Proxmox, rode:
   ```bash
   cd vps-host/scripts
   chmod +x *.sh
   ./provision.sh
   ```
   Isso vai: criar a VM (`01-create-vm.sh`), configurar NAT/port-forward se
   necessário (`02-network-nat.sh`) e configurar o firewall (`03-firewall.sh`).
4. Acesse a VM: `ssh cliente@<IP_DA_VM>`.
5. Instale o servidor de jogos desejado — veja `docs/04-servidor-de-jogos.md`
   (há um exemplo pronto de Minecraft em `examples/minecraft/`).

## Instalando o Proxmox (se ainda não tiver)

Se o servidor físico/dedicado ainda não tem o Proxmox VE instalado:

1. Baixe o ISO em https://www.proxmox.com/en/downloads.
2. Grave o ISO em um pendrive (`dd`, Rufus, Balena Etcher) e instale
   normalmente, definindo um IP de gerência para o host.
3. Depois de instalado, acesse `https://<ip-do-host>:8006` para o painel
   web e siga o passo a passo acima para criar a VM.

## Estrutura do repositório

```
config/            variáveis de configuração (vm.env)
cloud-init/        template cloud-init aplicado na primeira boot da VM
scripts/           scripts para rodar NO HOST PROXMOX
examples/minecraft/ exemplo de servidor de jogos rodando na VM via Docker
docs/              esta documentação
```
