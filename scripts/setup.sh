#!/usr/bin/env bash
# Assistente interativo de configuração.
# Detecta storages e bridges do próprio host, faz perguntas com valores
# padrão sugeridos e gera config/vm.env sozinho — sem exigir que quem
# executa já saiba o nome dos storages/bridges do Proxmox de antemão.
#
# Rodar no shell do host Proxmox: ./setup.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd .. && pwd)"
ENV_FILE="$ROOT_DIR/config/vm.env"
EXAMPLE_FILE="$ROOT_DIR/config/vm.env.example"

# --- checagens iniciais ---------------------------------------------------

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Este assistente precisa rodar como root, no shell do host Proxmox." >&2
  exit 1
fi

missing=()
for cmd in qm pvesm pvesh wget ssh-keygen; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Comando(s) não encontrado(s): ${missing[*]}" >&2
  echo "Este assistente precisa rodar em um host Proxmox VE real." >&2
  exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
  read -r -p "Já existe config/vm.env. Sobrescrever? [s/N]: " overwrite
  if [[ ! "$overwrite" =~ ^[sS]$ ]]; then
    echo "Mantendo o arquivo atual. Nada foi alterado."
    exit 0
  fi
  backup="${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$ENV_FILE" "$backup"
  echo "Backup salvo em $backup"
fi

# --- funções auxiliares ----------------------------------------------------

ask() {
  # ask "pergunta" "padrão" NOME_DA_VARIAVEL
  local prompt="$1" default="$2" __var="$3" input
  read -r -p "$prompt [$default]: " input
  printf -v "$__var" '%s' "${input:-$default}"
}

valid_ipv4() {
  local ip="$1" o
  [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  for o in "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"; do
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

ask_ipv4() {
  # ask_ipv4 "pergunta" "padrão" NOME_DA_VARIAVEL
  local prompt="$1" default="$2" __var="$3" input
  while true; do
    read -r -p "$prompt [$default]: " input
    input="${input:-$default}"
    if valid_ipv4 "$input"; then
      printf -v "$__var" '%s' "$input"
      return 0
    fi
    echo "Endereço IPv4 inválido: $input" >&2
  done
}

# escolhe um item de uma lista; imprime o menu em stderr e o resultado em stdout
choose_from_list() {
  local prompt="$1"; shift
  local items=("$@")
  if [[ ${#items[@]} -eq 0 ]]; then
    return 1
  fi
  echo "$prompt" >&2
  local i=1 item
  for item in "${items[@]}"; do
    echo "  $i) $item" >&2
    i=$((i + 1))
  done
  local choice
  while true; do
    read -r -p "Escolha [1-${#items[@]}] (padrão: 1): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#items[@]} )); then
      echo "${items[$((choice - 1))]}"
      return 0
    fi
    echo "Opção inválida." >&2
  done
}

next_free_vmid() {
  local id=100
  while qm status "$id" >/dev/null 2>&1; do
    id=$((id + 1))
  done
  echo "$id"
}

echo "=== Assistente de configuração da VPS ==="
echo "As perguntas abaixo têm um valor padrão entre colchetes:"
echo "pressione Enter para aceitá-lo, ou digite outro valor."
echo

# --- identificação da VM ---------------------------------------------------

DEFAULT_VMID="$(next_free_vmid)"
ask "ID da VM (VMID)" "$DEFAULT_VMID" VMID
ask "Nome da VM" "vps-provisionada" VM_NAME

mapfile -t STORAGES < <(pvesm status 2>/dev/null | awk 'NR>1{print $1}')
if [[ ${#STORAGES[@]} -gt 0 ]]; then
  VM_STORAGE="$(choose_from_list "Storage para o disco da VM:" "${STORAGES[@]}")"
  ISO_STORAGE="$(choose_from_list "Storage para a imagem cloud (geralmente 'local'):" "${STORAGES[@]}")"
else
  echo "Não foi possível listar storages automaticamente." >&2
  ask "Storage para o disco da VM" "local-lvm" VM_STORAGE
  ask "Storage para a imagem cloud" "local" ISO_STORAGE
fi

mapfile -t BRIDGES < <(ip -br a 2>/dev/null | awk '{print $1}' | grep '^vmbr' || true)
if [[ ${#BRIDGES[@]} -gt 0 ]]; then
  BRIDGE="$(choose_from_list "Bridge de rede com saída para a internet:" "${BRIDGES[@]}")"
else
  echo "Não foi possível listar bridges automaticamente." >&2
  ask "Bridge de rede com saída para a internet" "vmbr0" BRIDGE
fi

# --- recursos ---------------------------------------------------------------

ask "Núcleos de CPU" "4" VM_CORES
ask "Memória RAM em MB" "8192" VM_MEMORY_MB
ask "Tamanho do disco em GB" "60" VM_DISK_GB

CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
CLOUD_IMAGE_FILE="/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2"

# --- rede ---------------------------------------------------------------

echo
echo "Modo de rede:"
echo "  bridged: a VM recebe um IP público próprio, direto na bridge."
echo "  nat: o host tem um único IP público; as portas do serviço são"
echo "       redirecionadas do host para a VM (rede interna)."
NETWORK_MODE="$(choose_from_list "Escolha o modo de rede:" "bridged" "nat")"

ask "Servidor DNS" "1.1.1.1" DNS_SERVER

if [[ "$NETWORK_MODE" == "bridged" ]]; then
  ask_ipv4 "IP público da VM" "203.0.113.10" VM_IP
  ask "Máscara em CIDR (ex: 24 para /24)" "24" VM_CIDR
  ask_ipv4 "Gateway" "203.0.113.1" VM_GATEWAY
  HOST_PUBLIC_IP="$VM_IP"
  NAT_INTERNAL_BRIDGE="vmbr1"
  NAT_SUBNET="10.10.10.0/24"
  NAT_HOST_GATEWAY_IP="10.10.10.1"
else
  detected_ip="$(curl -4 -s --max-time 3 https://ifconfig.me 2>/dev/null || true)"
  if valid_ipv4 "$detected_ip"; then
    ask_ipv4 "IP público do host Proxmox (detectado automaticamente)" "$detected_ip" HOST_PUBLIC_IP
  else
    ask_ipv4 "IP público do host Proxmox (não foi possível detectar automaticamente)" "203.0.113.5" HOST_PUBLIC_IP
  fi
  ask_ipv4 "IP interno da VM" "10.10.10.10" VM_IP
  ask "Máscara em CIDR" "24" VM_CIDR
  ask "Bridge interna (criada só para as VMs, sem IP público)" "vmbr1" NAT_INTERNAL_BRIDGE
  ask "Sub-rede interna" "10.10.10.0/24" NAT_SUBNET
  ask_ipv4 "Gateway interno (IP do host na bridge interna)" "10.10.10.1" NAT_HOST_GATEWAY_IP
  VM_GATEWAY="$NAT_HOST_GATEWAY_IP"
fi

# --- acesso ---------------------------------------------------------------

echo
ssh_key_file=""
for candidate in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
  if [[ -f "$candidate" ]]; then
    ssh_key_file="$candidate"
    break
  fi
done

if [[ -n "$ssh_key_file" ]]; then
  ask "Chave pública SSH a usar" "$ssh_key_file" SSH_PUBLIC_KEY_FILE
else
  echo "Nenhuma chave SSH encontrada em ~/.ssh." >&2
  read -r -p "Gerar uma chave nova agora? [S/n]: " gen
  if [[ ! "$gen" =~ ^[nN]$ ]]; then
    new_key=~/.ssh/vps_host_key
    ssh-keygen -t ed25519 -N "" -f "$new_key" -C "vps-host"
    SSH_PUBLIC_KEY_FILE="${new_key}.pub"
    echo "Chave gerada em $new_key (privada) e ${new_key}.pub (pública)."
  else
    ask "Caminho da chave pública SSH" "~/.ssh/id_rsa.pub" SSH_PUBLIC_KEY_FILE
  fi
fi

ask "Usuário criado dentro da VM" "vpsuser" CI_USER

detected_admin_ip="$(curl -4 -s --max-time 3 https://ifconfig.me 2>/dev/null || true)"
if valid_ipv4 "$detected_admin_ip"; then
  ask "IP de origem autorizado para SSH administrativo (o seu IP atual foi detectado)" "${detected_admin_ip}/32" ADMIN_SSH_SOURCE_IP
else
  echo "Não foi possível detectar seu IP automaticamente." >&2
  ask "IP de origem autorizado para SSH administrativo (0.0.0.0/0 = qualquer origem, menos seguro)" "0.0.0.0/0" ADMIN_SSH_SOURCE_IP
fi

echo
echo "Portas do serviço a ser hospedado, formato porta/protocolo,"
echo "separadas por espaço quando houver mais de uma (ex: 8080/tcp 8080/udp)."
ask "Portas do serviço" "8080/tcp" SERVICE_PORTS

# --- gravação ---------------------------------------------------------------

mkdir -p "$(dirname "$ENV_FILE")"
cat > "$ENV_FILE" <<EOF
# Gerado por scripts/setup.sh em $(date '+%Y-%m-%d %H:%M:%S').
# Pode ser editado manualmente a qualquer momento; veja config/vm.env.example
# para o significado de cada variável.

VMID=$VMID
VM_NAME=$VM_NAME
VM_STORAGE=$VM_STORAGE
ISO_STORAGE=$ISO_STORAGE
BRIDGE=$BRIDGE

VM_CORES=$VM_CORES
VM_MEMORY_MB=$VM_MEMORY_MB
VM_DISK_GB=$VM_DISK_GB

CLOUD_IMAGE_URL="$CLOUD_IMAGE_URL"
CLOUD_IMAGE_FILE="$CLOUD_IMAGE_FILE"

NETWORK_MODE=$NETWORK_MODE

VM_IP=$VM_IP
VM_CIDR=$VM_CIDR
VM_GATEWAY=$VM_GATEWAY
DNS_SERVER=$DNS_SERVER

HOST_PUBLIC_IP=$HOST_PUBLIC_IP
NAT_INTERNAL_BRIDGE=$NAT_INTERNAL_BRIDGE
NAT_SUBNET=$NAT_SUBNET
NAT_HOST_GATEWAY_IP=$NAT_HOST_GATEWAY_IP

CI_USER=$CI_USER
SSH_PUBLIC_KEY_FILE=$SSH_PUBLIC_KEY_FILE
ADMIN_SSH_SOURCE_IP=$ADMIN_SSH_SOURCE_IP

SERVICE_PORTS="$SERVICE_PORTS"
EOF

echo
echo "config/vm.env gerado."
echo "----------------------------------------"
echo "VMID:            $VMID"
echo "Nome:            $VM_NAME"
echo "Storage:         $VM_STORAGE (disco) / $ISO_STORAGE (imagem)"
echo "Bridge:          $BRIDGE"
echo "Recursos:        ${VM_CORES} vCPU, ${VM_MEMORY_MB}MB RAM, ${VM_DISK_GB}GB disco"
echo "Modo de rede:    $NETWORK_MODE"
echo "IP da VM:        $VM_IP/$VM_CIDR"
if [[ "$NETWORK_MODE" == "nat" ]]; then
  echo "IP público (host): $HOST_PUBLIC_IP"
fi
echo "Usuário:         $CI_USER"
echo "SSH restrito a:  $ADMIN_SSH_SOURCE_IP"
echo "Portas expostas: $SERVICE_PORTS"
echo "----------------------------------------"

read -r -p "Executar o provisionamento agora? [S/n]: " run_now
if [[ ! "$run_now" =~ ^[nN]$ ]]; then
  exec "$ROOT_DIR/scripts/provision.sh"
else
  echo "Configuração salva. Para provisionar depois, rode: ./provision.sh"
fi
