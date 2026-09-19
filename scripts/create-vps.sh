#!/usr/bin/env bash
# Cria uma nova VPS (VM KVM) para um cliente, com specs padrão 1 vCPU / 2GB / 50GB
# no HD de dados, usando a imagem base + cloud-init para provisionamento automático.
#
# Uso:
#   sudo ./scripts/create-vps.sh <nome-da-vps> [opções]
#
# Opções:
#   --vcpus N          (default: DEFAULT_VCPUS do config)
#   --ram-mb N          (default: DEFAULT_RAM_MB)
#   --disk-gb N         (default: DEFAULT_DISK_GB)
#   --ssh-key PATH      (default: ~/.ssh/id_ed25519.pub ou id_rsa.pub do usuário que chamou sudo)
#   --user NAME         (default: DEFAULT_VPS_USER)
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

VPS_NAME="${1:-}"
[[ -n "$VPS_NAME" ]] || { echo "Uso: $0 <nome-da-vps> [--vcpus N] [--ram-mb N] [--disk-gb N] [--ssh-key PATH] [--user NAME]" >&2; exit 1; }
shift || true

VCPUS="$DEFAULT_VCPUS"
RAM_MB="$DEFAULT_RAM_MB"
DISK_GB="$DEFAULT_DISK_GB"
VPS_USER="$DEFAULT_VPS_USER"
REAL_USER="${SUDO_USER:-root}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
SSH_KEY_PATH=""
for candidate in "$REAL_HOME/.ssh/id_ed25519.pub" "$REAL_HOME/.ssh/id_rsa.pub"; do
  [[ -f "$candidate" ]] && SSH_KEY_PATH="$candidate" && break
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vcpus) VCPUS="$2"; shift 2 ;;
    --ram-mb) RAM_MB="$2"; shift 2 ;;
    --disk-gb) DISK_GB="$2"; shift 2 ;;
    --ssh-key) SSH_KEY_PATH="$2"; shift 2 ;;
    --user) VPS_USER="$2"; shift 2 ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]] || {
  echo "Não encontrei uma chave pública SSH. Passe com --ssh-key /caminho/id_ed25519.pub" >&2
  exit 1
}
SSH_PUBLIC_KEY="$(cat "$SSH_KEY_PATH")"

if virsh dominfo "$VPS_NAME" &>/dev/null; then
  echo "ERRO: já existe uma VM chamada '$VPS_NAME'." >&2
  exit 1
fi

BASE_IMAGE_PATH="$VPS_STORAGE_MOUNT/base-images/$BASE_IMAGE_NAME"
[[ -f "$BASE_IMAGE_PATH" ]] || { echo "Imagem base não encontrada em $BASE_IMAGE_PATH. Rode install-host.sh primeiro." >&2; exit 1; }

DISK_PATH="$VPS_STORAGE_MOUNT/images/${VPS_NAME}.qcow2"
CLOUDINIT_DIR="$VPS_STORAGE_MOUNT/cloud-init/${VPS_NAME}"
SEED_ISO="$CLOUDINIT_DIR/seed.iso"

echo "== Criando disco de $DISK_GB GB (backing file na imagem base) =="
mkdir -p "$CLOUDINIT_DIR"
qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE_PATH" "$DISK_PATH" "${DISK_GB}G"

echo "== Gerando cloud-init =="
sed -e "s/__VPS_NAME__/${VPS_NAME}/g" \
    -e "s/__VPS_USER__/${VPS_USER}/g" \
    -e "s#__SSH_PUBLIC_KEY__#${SSH_PUBLIC_KEY}#g" \
    "$REPO_DIR/cloud-init/user-data.tmpl.yaml" > "$CLOUDINIT_DIR/user-data"
sed -e "s/__VPS_NAME__/${VPS_NAME}/g" \
    "$REPO_DIR/cloud-init/meta-data.tmpl.yaml" > "$CLOUDINIT_DIR/meta-data"

cloud-localds "$SEED_ISO" "$CLOUDINIT_DIR/user-data" "$CLOUDINIT_DIR/meta-data"

echo "== Criando a VM ($VCPUS vCPU / ${RAM_MB}MB RAM / ${DISK_GB}GB disco) =="
virt-install \
  --name "$VPS_NAME" \
  --memory "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --disk path="$DISK_PATH",format=qcow2,bus=virtio \
  --disk path="$SEED_ISO",device=cdisk,bus=sata,readonly=on \
  --os-variant detect=on,require=off \
  --network network="$VPS_NETWORK_NAME",model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --import \
  --noautoconsole

# Limite opcional de I/O em disco (importante em HD mecânico compartilhado entre VPS's).
# Descomente e ajuste bytes/segundo conforme necessário:
# virsh blkiotune "$VPS_NAME" --device-weights-config /dev/null
# virsh blkdeviotune "$VPS_NAME" vda --total-bytes-sec 50000000 --live --config

echo "== Aguardando IP via DHCP (pode levar ~30s no primeiro boot) =="
IP=""
for i in $(seq 1 30); do
  IP="$(virsh domifaddr "$VPS_NAME" 2>/dev/null | awk '/ipv4/{print $4}' | cut -d/ -f1)"
  [[ -n "$IP" ]] && break
  sleep 2
done

echo
echo "== VPS '$VPS_NAME' criada =="
echo "vCPU/RAM/Disco : $VCPUS / ${RAM_MB}MB / ${DISK_GB}GB"
echo "IP interno     : ${IP:-<ainda não obtido, rode: virsh domifaddr $VPS_NAME>}"
echo "Usuário        : $VPS_USER (chave SSH: $SSH_KEY_PATH)"
echo
echo "Para expor SSH ao cliente: sudo ./scripts/manage-vps.sh port-forward $VPS_NAME 22 <porta-no-host>"
