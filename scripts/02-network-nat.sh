#!/usr/bin/env bash
# Configura a bridge interna + NAT no host Proxmox para o modo NETWORK_MODE=nat.
# Só é necessário quando o host tem UM único IP público e a VM fica em rede interna.
# Se NETWORK_MODE=bridged (VM com IP público direto), este script NÃO é necessário.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

require_root
require_cmd iptables

if [[ "$NETWORK_MODE" != "nat" ]]; then
  echo "NETWORK_MODE=$NETWORK_MODE (não é 'nat'). Nada a fazer aqui." >&2
  exit 0
fi

INTERFACES_FILE="/etc/network/interfaces"
BRIDGE_BLOCK_MARKER="# vps-host: bridge interna NAT ($NAT_INTERNAL_BRIDGE)"

if ! grep -q "$BRIDGE_BLOCK_MARKER" "$INTERFACES_FILE" 2>/dev/null; then
  log "Adicionando bridge interna $NAT_INTERNAL_BRIDGE em $INTERFACES_FILE..."
  cat >>"$INTERFACES_FILE" <<EOF

$BRIDGE_BLOCK_MARKER
auto $NAT_INTERNAL_BRIDGE
iface $NAT_INTERNAL_BRIDGE inet static
    address ${NAT_HOST_GATEWAY_IP}/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF
  log "Bridge adicionada. Rode 'ifreload -a' (Proxmox usa ifupdown2) ou reinicie a rede para aplicá-la."
else
  log "Bridge $NAT_INTERNAL_BRIDGE já configurada em $INTERFACES_FILE."
fi

log "Habilitando IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
if ! grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf 2>/dev/null; then
  echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
fi

WAN_IFACE="$(ip route show default | awk '/default/ {print $5; exit}')"
if [[ -z "$WAN_IFACE" ]]; then
  echo "Não foi possível detectar a interface WAN automaticamente. Ajuste WAN_IFACE manualmente." >&2
  exit 1
fi
log "Interface WAN detectada: $WAN_IFACE"

log "Configurando MASQUERADE para a sub-rede interna $NAT_SUBNET..."
if ! iptables -t nat -C POSTROUTING -s "$NAT_SUBNET" -o "$WAN_IFACE" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -A POSTROUTING -s "$NAT_SUBNET" -o "$WAN_IFACE" -j MASQUERADE
fi

log "Configurando DNAT (port-forward) das portas do serviço para $VM_IP..."
for entry in $SERVICE_PORTS; do
  port="${entry%%/*}"
  proto="${entry##*/}"
  if ! iptables -t nat -C PREROUTING -i "$WAN_IFACE" -p "$proto" --dport "$port" -j DNAT --to-destination "${VM_IP}:${port}" 2>/dev/null; then
    iptables -t nat -A PREROUTING -i "$WAN_IFACE" -p "$proto" --dport "$port" -j DNAT --to-destination "${VM_IP}:${port}"
    log "  -> $port/$proto encaminhado para ${VM_IP}:${port}"
  fi
  if ! iptables -C FORWARD -p "$proto" -d "$VM_IP" --dport "$port" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -p "$proto" -d "$VM_IP" --dport "$port" -j ACCEPT
  fi
done

log "Persistindo regras com netfilter-persistent (se disponível)..."
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save
else
  log "Instale 'iptables-persistent' (apt install iptables-persistent) para as regras sobreviverem a um reboot."
fi

log "NAT/port-forward configurado. Host público: ${HOST_PUBLIC_IP} -> VM interna: ${VM_IP}"
