#!/usr/bin/env bash
# Cria a VM da VPS no Proxmox a partir de uma cloud image Debian, com cloud-init.
# Execute no shell do NODE Proxmox (via SSH ou console web -> Shell).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

require_root
require_cmd qm
require_cmd wget

if qm status "$VMID" >/dev/null 2>&1; then
  echo "Já existe uma VM com VMID=$VMID. Escolha outro VMID em config/vm.env ou remova a VM existente." >&2
  exit 1
fi

if [[ ! -f "$CLOUD_IMAGE_FILE" ]]; then
  log "Baixando cloud image Debian 12..."
  mkdir -p "$(dirname "$CLOUD_IMAGE_FILE")"
  wget -q --show-progress -O "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"
else
  log "Cloud image já presente em $CLOUD_IMAGE_FILE, pulando download."
fi

VM_BRIDGE="$BRIDGE"
if [[ "$NETWORK_MODE" == "nat" ]]; then
  VM_BRIDGE="$NAT_INTERNAL_BRIDGE"
  log "Modo NAT selecionado: a VM usará a bridge interna $NAT_INTERNAL_BRIDGE (sem IP público direto)."
fi

log "Criando VM $VMID ($VM_NAME)..."
qm create "$VMID" \
  --name "$VM_NAME" \
  --memory "$VM_MEMORY_MB" \
  --cores "$VM_CORES" \
  --cpu host \
  --net0 "virtio,bridge=${VM_BRIDGE}" \
  --scsihw virtio-scsi-pci \
  --ostype l26 \
  --agent enabled=1

log "Importando disco a partir da cloud image..."
qm importdisk "$VMID" "$CLOUD_IMAGE_FILE" "$VM_STORAGE" --format qcow2

log "Anexando disco e configurando boot..."
qm set "$VMID" --scsi0 "${VM_STORAGE}:vm-${VMID}-disk-0"
qm resize "$VMID" scsi0 "${VM_DISK_GB}G"
qm set "$VMID" --boot c --bootdisk scsi0
qm set "$VMID" --ide2 "${VM_STORAGE}:cloudinit"
qm set "$VMID" --serial0 socket --vga serial0
qm set "$VMID" --agent enabled=1

log "Configurando cloud-init (usuário, chave SSH, rede)..."
qm set "$VMID" --ciuser "$CI_USER"
qm set "$VMID" --sshkeys "$(eval echo "$SSH_PUBLIC_KEY_FILE")"
qm set "$VMID" --nameserver "$DNS_SERVER"

if [[ "$NETWORK_MODE" == "bridged" ]]; then
  qm set "$VMID" --ipconfig0 "ip=${VM_IP}/${VM_CIDR},gw=${VM_GATEWAY}"
else
  qm set "$VMID" --ipconfig0 "ip=${VM_IP}/${VM_CIDR},gw=${NAT_HOST_GATEWAY_IP}"
fi

log "Renderizando cloud-init customizado (usuário/hardening + portas do serviço)..."
UFW_RULES=""
for entry in $SERVICE_PORTS; do
  UFW_RULES="${UFW_RULES}  - ufw allow ${entry}"$'\n'
done

RENDERED="$ROOT_DIR/cloud-init/user-data.generated.yaml"
awk -v rules="$UFW_RULES" '{
  if ($0 ~ /__SERVICE_PORTS_UFW_RULES__/) { printf "%s", rules } else { print }
}' "$ROOT_DIR/cloud-init/user-data.yaml.tmpl" > "$RENDERED"

qm set "$VMID" --cicustom "user=local:snippets/${VM_NAME}-user-data.yaml"
mkdir -p "/var/lib/vz/snippets"
cp "$RENDERED" "/var/lib/vz/snippets/${VM_NAME}-user-data.yaml"

log "Iniciando a VM..."
qm start "$VMID"

log "VM $VMID criada e iniciada. Use 'qm terminal $VMID' ou SSH em ${VM_IP} (usuário: $CI_USER) para acessar."
