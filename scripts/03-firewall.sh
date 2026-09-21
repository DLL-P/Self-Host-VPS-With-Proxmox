#!/usr/bin/env bash
# Configura o firewall do Proxmox (pve-firewall) no nível do Datacenter e da VM:
# - Bloqueia tudo por padrão
# - Libera SSH apenas da origem administrativa
# - Libera as portas do servidor de jogos para qualquer IP externo
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

require_root
require_cmd pvesh

log "Habilitando firewall do Proxmox no Datacenter..."
pvesh set /cluster/firewall/options --enable 1

log "Habilitando firewall na VM $VMID..."
pvesh set "/nodes/$(hostname)/qemu/${VMID}/firewall/options" --enable 1 --policy_in DROP --policy_out ACCEPT

log "Limpando regras antigas geradas por este script (se existirem)..."
EXISTING="$(pvesh get "/nodes/$(hostname)/qemu/${VMID}/firewall/rules" --output-format json 2>/dev/null || echo '[]')"

add_rule() {
  local proto="$1" dport="$2" source="$3" comment="$4"
  pvesh create "/nodes/$(hostname)/qemu/${VMID}/firewall/rules" \
    --type in --action ACCEPT --proto "$proto" --dport "$dport" \
    ${source:+--source "$source"} \
    --comment "$comment" \
    --enable 1
}

log "Liberando SSH (22/tcp) apenas para $ADMIN_SSH_SOURCE_IP..."
add_rule tcp 22 "$ADMIN_SSH_SOURCE_IP" "vps-host: acesso SSH administrativo"

log "Liberando portas do servidor de jogos para qualquer origem..."
for entry in $GAME_PORTS; do
  port="${entry%%/*}"
  proto="${entry##*/}"
  add_rule "$proto" "$port" "" "vps-host: porta do servidor de jogos ($entry)"
done

log "Firewall configurado. Regra padrão de entrada = DROP; apenas SSH (restrito) e as portas do jogo estão liberadas."
log "Revise em: Datacenter -> $(hostname) -> ${VMID} -> Firewall no painel web do Proxmox."
