# CLAUDE.md

Contexto do repositório para agentes Claude Code. Não é lido pelos scripts
nem interfere na execução do provisionamento.

## Propósito do repositório

Scripts e templates para provisionar, em um host Proxmox VE já instalado,
uma VM com acesso externo configurado (IP público direto ou NAT/port-forward),
destinada a hospedar um serviço exposto à internet.

## Estrutura

- `config/vm.env.example` — variáveis de configuração; o arquivo real
  (`config/vm.env`) não é versionado (`.gitignore`) e é criado localmente
  por quem executa o provisionamento.
- `cloud-init/user-data.yaml.tmpl` — template cloud-config. O placeholder
  `__SERVICE_PORTS_UFW_RULES__` é substituído, em tempo de execução, pelas
  regras de UFW correspondentes a `SERVICE_PORTS` (ver
  `scripts/01-create-vm.sh`); o resultado renderizado
  (`user-data.generated.yaml`) também não é versionado.
- `scripts/` — executados no host Proxmox. `setup.sh` é o ponto de
  entrada recomendado: assistente interativo que detecta storages/bridges
  do próprio host, faz perguntas com valores padrão e gera
  `config/vm.env` sem exigir conhecimento prévio de Proxmox. Ele delega
  para `provision.sh`, que roda nesta ordem: `01-create-vm.sh` (cria a
  VM), `02-network-nat.sh` (bridge interna + DNAT, só em
  `NETWORK_MODE=nat`), `03-firewall.sh` (regras no firewall do Proxmox
  via `pvesh`). `lib.sh` carrega `config/vm.env` e define helpers (`log`,
  `require_root`, `require_cmd`) — usado por `01`, `02` e `03`, não por
  `setup.sh` (que ainda não tem `config/vm.env` para carregar).
- `examples/` — modelo genérico de `docker-compose.yml` e um instalador de
  Docker, para uso dentro da VM após o provisionamento. Não referenciar
  serviços ou jogos específicos aqui — o modelo deve permanecer genérico.
- `docs/` — documentação numerada, pensada para leitura sequencial (01 a 05).

## Convenções

- Documentação e mensagens de log em português, tom direto e técnico —
  sem linguagem promocional, sem exemplos amarrados a um caso de uso
  específico (ex.: não citar jogos por nome).
- Scripts com `set -euo pipefail`; validar sintaxe com `bash -n` antes de
  considerar uma alteração pronta.
- Alterações em `cloud-init/user-data.yaml.tmpl` devem manter o
  placeholder `__SERVICE_PORTS_UFW_RULES__` — é ele que recebe as regras
  de UFW geradas a partir de `SERVICE_PORTS`.
- Nomes de variáveis de configuração usam maiúsculas com underscore
  (`SERVICE_PORTS`, `NETWORK_MODE`, `CI_USER`, etc.); ao renomear uma,
  atualizar todas as referências em `scripts/`, `cloud-init/` e `docs/`.
- Sem comentários explicando o óbvio; comentário só quando há uma decisão
  não evidente (ex.: por que um placeholder existe, por que uma ordem de
  execução importa).
- O requisito de design de `setup.sh` é não exigir de quem executa nenhum
  conhecimento prévio de Proxmox (nomes de storage, bridges, sintaxe de
  `qm`/`pvesh`) — qualquer novo prompt adicionado a ele deve manter essa
  premissa (detectar automaticamente quando possível, sugerir um padrão
  sensato, validar a entrada antes de aceitar).
