#!/usr/bin/env bash
# Orquestra o provisionamento completo: cria a VM, configura rede (se NAT) e firewall.
# Rode no shell do host Proxmox, após preencher config/vm.env.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

log "=== 1/3: Criando a VM ==="
./01-create-vm.sh

if [[ "$NETWORK_MODE" == "nat" ]]; then
  log "=== 2/3: Configurando NAT/port-forward ==="
  ./02-network-nat.sh
else
  log "=== 2/3: Modo bridged, pulando configuração de NAT ==="
fi

log "=== 3/3: Configurando firewall do Proxmox ==="
./03-firewall.sh

log "Provisionamento concluído."
log "Acesse com: ssh ${CI_USER}@${VM_IP}"
