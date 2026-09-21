# Visão geral

Este repositório provisiona, em um host Proxmox VE já instalado, uma VM
configurada para acesso externo, destinada a hospedar um serviço exposto à
internet.

## Pré-requisitos

- Host Proxmox VE já instalado e acessível (via SSH ou console web
  "Shell"). Este repositório não instala o Proxmox — apenas provisiona a VM
  dentro dele. Se ainda não houver uma instalação, ver a seção "Instalando
  o Proxmox" abaixo.
- Ao menos um IP público disponível: dedicado à VM, ou o IP do próprio
  host, caso o modo de rede seja NAT (ver `docs/02-rede-ip-externo.md`).
- Acesso root ao host Proxmox para executar os scripts.
- Uma chave SSH pública para acesso à VM. Não é obrigatório ter uma
  previamente — `setup.sh` gera uma automaticamente se não encontrar
  nenhuma.

## Passo a passo resumido

1. Copiar o repositório para o host Proxmox (`git clone` ou `scp -r`).
2. No host Proxmox:
   ```bash
   cd vps-host/scripts
   chmod +x *.sh
   ./setup.sh
   ```
   O assistente detecta storages e bridges já existentes no host, sugere
   um valor padrão para cada pergunta e gera `config/vm.env` sozinho. Ao
   final, oferece para já executar o provisionamento (`provision.sh`),
   que cria a VM (`01-create-vm.sh`), configura NAT/port-forward quando
   necessário (`02-network-nat.sh`) e configura o firewall
   (`03-firewall.sh`).

   Alternativa manual, para quem preferir editar a configuração à mão:
   copiar `config/vm.env.example` para `config/vm.env`, preencher os
   valores (os comentários no arquivo descrevem cada variável) e rodar
   `./provision.sh` diretamente.
3. Acessar a VM via SSH, com o usuário definido em `CI_USER`.
4. Instalar o serviço desejado — ver `docs/04-portas-e-servicos.md`.

## Instalando o Proxmox

Caso o servidor ainda não tenha o Proxmox VE instalado:

1. Baixar o ISO em https://www.proxmox.com/en/downloads.
2. Gravar o ISO em um pendrive e instalar, definindo um IP de gerência
   para o host.
3. Acessar `https://<ip-do-host>:8006` e seguir o passo a passo acima.

## Estrutura do repositório

```
config/            variáveis de configuração (vm.env)
cloud-init/        template cloud-init aplicado na primeira inicialização da VM
scripts/           scripts executados no host Proxmox
examples/          modelo de execução de um serviço via Docker dentro da VM
docs/              esta documentação
CLAUDE.md          contexto do repositório para agentes Claude Code
```
