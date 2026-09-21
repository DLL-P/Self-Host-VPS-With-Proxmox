# vps-host

Provisionamento automatizado de uma VM em Proxmox VE, com acesso externo
configurado, destinada a hospedar um serviço exposto à internet.

## O que este repositório faz

- Cria uma VM no Proxmox VE a partir de uma imagem cloud do Debian, via cloud-init.
- Configura o acesso externo à VM em um de dois modos: IP público atribuído
  diretamente à VM, ou NAT com redirecionamento de portas a partir do IP do host.
- Aplica hardening inicial: firewall do Proxmox, firewall interno (UFW),
  fail2ban e autenticação SSH restrita a chave pública.
- Documenta o processo completo, do provisionamento à concessão de acesso a
  terceiros.

## Tecnologias utilizadas

- **Proxmox VE / QEMU-KVM** — virtualização e gerência da VM, via `qm` e `pvesh`.
- **Debian 12 (cloud image)** — sistema operacional base da VM.
- **cloud-init** — configuração da VM na primeira inicialização.
- **Bash** — scripts de provisionamento, executados no host.
- **iptables / netfilter** — NAT e redirecionamento de portas (modo NAT).
- **UFW** e **fail2ban** — firewall interno e proteção contra tentativas de força bruta.
- **Docker / Docker Compose** — execução do serviço hospedado dentro da VM.

## Uso

1. Copie `config/vm.env.example` para `config/vm.env` e ajuste os valores.
2. No host Proxmox:
   ```bash
   cd scripts
   chmod +x *.sh
   ./provision.sh
   ```
3. Instale o serviço desejado dentro da VM — ver `docs/04-portas-e-servicos.md`.

## Documentação

- [`docs/01-visao-geral.md`](docs/01-visao-geral.md) — pré-requisitos e passo a passo resumido.
- [`docs/02-rede-ip-externo.md`](docs/02-rede-ip-externo.md) — IP público direto (bridged) vs NAT/port-forward.
- [`docs/03-firewall-seguranca.md`](docs/03-firewall-seguranca.md) — firewall do Proxmox, UFW, fail2ban, hardening de SSH.
- [`docs/04-portas-e-servicos.md`](docs/04-portas-e-servicos.md) — configuração de portas e instalação do serviço via Docker.
- [`docs/05-passo-a-passo-completo.md`](docs/05-passo-a-passo-completo.md) — guia detalhado do provisionamento à concessão de acesso.

## Reutilização como modelo

Todo o comportamento variável fica isolado em `config/vm.env` (arquivo
local, não versionado) e no arquivo de rede/portas descrito nos docs. Para
replicar este provisionamento em outro caso:

1. Clone ou faça um fork do repositório.
2. Copie `config/vm.env.example` para `config/vm.env` e preencha com os
   valores do novo ambiente (rede, recursos, portas, chave SSH).
3. Nada em `scripts/`, `cloud-init/` ou `docs/` precisa ser alterado para
   um novo caso de uso — esses arquivos são genéricos por design.
4. Caso o repositório deva funcionar como ponto de partida para múltiplas
   pessoas/times, habilite "Template repository" nas configurações do
   GitHub (Settings → General → Template repository). Isso adiciona o
   botão "Use this template", que cria uma cópia independente do
   repositório sem herdar histórico de commits.

## Estrutura

```
config/            variáveis de configuração (vm.env)
cloud-init/        template de configuração inicial da VM
scripts/           scripts de provisionamento, executados no host Proxmox
examples/          modelo de execução de um serviço via Docker dentro da VM
docs/              documentação
CLAUDE.md          contexto do repositório para agentes Claude Code
```

`CLAUDE.md` é lido por agentes do Claude Code ao trabalhar neste repositório
e não interfere na execução dos scripts.
