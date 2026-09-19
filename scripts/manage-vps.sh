#!/usr/bin/env bash
# Operações do dia a dia sobre as VPS's: listar, iniciar, parar, remover,
# redimensionar e expor portas ao mundo externo (essencial para servidor de jogo:
# a maioria usa TCP + UDP).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$REPO_DIR/config/vps-defaults.env"

if [[ $EUID -ne 0 ]]; then
  echo "Rode como root (sudo $0)." >&2
  exit 1
fi
[[ -f "$ENV_FILE" ]] || { echo "Faltou config/vps-defaults.env" >&2; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

usage() {
  cat >&2 <<EOF
Uso: $0 <comando> [args]

  list                                   lista as VPS's e status
  ip <vps>                               mostra o IP interno da VPS
  start|stop|restart|delete <vps>        controla o ciclo de vida
  console <vps>                          abre o console serial (Ctrl+] para sair)
  resize <vps> --vcpus N --ram-mb N      redimensiona (VM precisa estar desligada)
  port-forward <vps> <porta-interna> <porta-host> [tcp|udp|both]
                                          expõe uma porta da VPS numa porta do host
                                          (default: both -- necessário p/ maioria dos jogos)
  port-unforward <vps> <porta-interna> <porta-host> [tcp|udp|both]
                                          remove um port-forward criado antes
  list-forwards                          lista os port-forwards ativos (regras DNAT)
EOF
  exit 1
}

get_ip() {
  local vps="$1" ip=""
  for i in $(seq 1 15); do
    ip="$(virsh domifaddr "$vps" 2>/dev/null | awk '/ipv4/{print $4}' | cut -d/ -f1)"
    [[ -n "$ip" ]] && break
    sleep 1
  done
  [[ -n "$ip" ]] || { echo "Não consegui obter o IP de '$vps' (ela está ligada?)." >&2; exit 1; }
  echo "$ip"
}

wan_iface() {
  if [[ -n "${HOST_WAN_IFACE:-}" ]]; then
    echo "$HOST_WAN_IFACE"
  else
    ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}'
  fi
}

ensure_persistence_pkg() {
  if ! dpkg -s netfilter-persistent &>/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update && apt-get install -y iptables-persistent netfilter-persistent
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  list)
    virsh list --all
    ;;

  ip)
    [[ $# -eq 1 ]] || usage
    get_ip "$1"
    ;;

  start) virsh start "$1" ;;
  stop) virsh shutdown "$1" ;;
  restart) virsh reboot "$1" ;;

  delete)
    vps="${1:?nome da vps}"
    read -r -p "Isso apaga a VM '$vps' e seu disco. Digite 'APAGAR' para confirmar: " c
    [[ "$c" == "APAGAR" ]] || { echo "Abortado."; exit 1; }
    virsh destroy "$vps" 2>/dev/null || true
    virsh undefine "$vps" --nvram 2>/dev/null || virsh undefine "$vps"
    rm -f "$VPS_STORAGE_MOUNT/images/${vps}.qcow2"
    rm -rf "$VPS_STORAGE_MOUNT/cloud-init/${vps}"
    echo "VPS '$vps' removida."
    ;;

  console)
    virsh console "${1:?nome da vps}"
    ;;

  resize)
    vps="${1:?nome da vps}"; shift
    state="$(virsh domstate "$vps")"
    [[ "$state" == "shut off" ]] || { echo "Desligue a VPS antes de redimensionar (virsh shutdown $vps)." >&2; exit 1; }
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --vcpus) virsh setvcpus "$vps" "$2" --config --maximum; virsh setvcpus "$vps" "$2" --config; shift 2 ;;
        --ram-mb) virsh setmaxmem "$vps" "${2}MiB" --config; virsh setmem "$vps" "${2}MiB" --config; shift 2 ;;
        *) usage ;;
      esac
    done
    echo "Redimensionado. Novos valores em: virsh dominfo $vps"
    ;;

  port-forward|port-unforward)
    vps="${1:?nome da vps}"; inport="${2:?porta interna}"; hostport="${3:?porta no host}"; proto="${4:-both}"
    ip="$(get_ip "$vps")"
    iface="$(wan_iface)"
    [[ -n "$iface" ]] || { echo "Não detectei a interface de rede do host. Defina HOST_WAN_IFACE no config." >&2; exit 1; }

    protos=()
    case "$proto" in
      tcp) protos=(tcp) ;;
      udp) protos=(udp) ;;
      both) protos=(tcp udp) ;;
      *) echo "Protocolo inválido: $proto (use tcp, udp ou both)" >&2; exit 1 ;;
    esac

    action="-A"; label="Adicionando"
    if [[ "$cmd" == "port-unforward" ]]; then action="-D"; label="Removendo"; fi

    ensure_persistence_pkg

    for p in "${protos[@]}"; do
      echo "$label forward $p: host:$hostport -> $ip:$inport (iface $iface)"
      iptables -t nat "$action" PREROUTING -i "$iface" -p "$p" --dport "$hostport" \
        -j DNAT --to-destination "${ip}:${inport}"
      iptables "$action" FORWARD -p "$p" -d "$ip" --dport "$inport" -j ACCEPT
      ufw allow "${hostport}/${p}" comment "vps:${vps}" 2>/dev/null || true
    done

    netfilter-persistent save

    if [[ "$cmd" == "port-forward" ]]; then
      echo
      echo "Feito. Agora configure no SEU ROTEADOR (fora do alcance deste script):"
      echo "  encaminhar a porta externa (WAN) desejada -> IP do HOST na LAN : ${hostport} (${proto})"
    fi
    ;;

  list-forwards)
    echo "== NAT (PREROUTING/DNAT) =="
    iptables -t nat -L PREROUTING -n --line-numbers | grep -E 'DNAT|Chain'
    ;;

  *) usage ;;
esac
