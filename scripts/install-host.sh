#!/usr/bin/env bash
# Instala KVM/libvirt, prepara o HD de dados e a rede NAT das VPS's.
# Rode como root, no servidor físico real. NÃO rode em produção sem revisar
# config/vps-defaults.env primeiro (em especial HDD_DEVICE).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$REPO_DIR/config/vps-defaults.env"

if [[ $EUID -ne 0 ]]; then
  echo "Rode como root (sudo $0)." >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Faltou config/vps-defaults.env. Copie de vps-defaults.env.example e ajuste HDD_DEVICE." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

for var in HDD_DEVICE VPS_STORAGE_MOUNT VPS_STORAGE_POOL VPS_NETWORK_NAME VPS_NETWORK_CIDR BASE_IMAGE_URL BASE_IMAGE_NAME; do
  if [[ -z "${!var:-}" ]]; then
    echo "Variável $var não definida em $ENV_FILE" >&2
    exit 1
  fi
done

echo "== 1. Verificando suporte a virtualização =="
if [[ "$(egrep -c '(vmx|svm)' /proc/cpuinfo)" -eq 0 ]]; then
  echo "ERRO: CPU sem VT-x/AMD-V habilitado (ou não suportado). Habilite na BIOS/UEFI." >&2
  exit 1
fi

echo "== 2. Verificando que HDD_DEVICE ($HDD_DEVICE) não é o disco de boot =="
BOOT_DISK="$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null || true)"
TARGET_DISK_NAME="$(basename "$HDD_DEVICE")"
if [[ -n "$BOOT_DISK" && "/dev/$BOOT_DISK" == "$HDD_DEVICE" ]]; then
  echo "ERRO: $HDD_DEVICE parece ser o disco de boot/sistema (SSD). Abortando." >&2
  exit 1
fi
if ! lsblk -dno NAME | grep -qx "$TARGET_DISK_NAME"; then
  echo "ERRO: $HDD_DEVICE não encontrado. Confira com 'lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL'." >&2
  exit 1
fi

echo
echo "Disco escolhido para as VPS's: $HDD_DEVICE"
lsblk "$HDD_DEVICE" -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
echo
if mount | grep -q "^$HDD_DEVICE"; then
  echo "ERRO: $HDD_DEVICE (ou uma partição dele) já está montado. Desmonte antes de continuar." >&2
  exit 1
fi

read -r -p "Isso vai FORMATAR $HDD_DEVICE por completo (ext4). Digite 'FORMATAR' para confirmar: " CONFIRM
if [[ "$CONFIRM" != "FORMATAR" ]]; then
  echo "Abortado pelo usuário."
  exit 1
fi

echo "== 3. Instalando pacotes =="
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients virtinst \
  bridge-utils genisoimage cloud-image-utils ovmf wget

echo "== 4. Formatando e montando $HDD_DEVICE em $VPS_STORAGE_MOUNT =="
wipefs -a "$HDD_DEVICE"
mkfs.ext4 -F -L vps-storage "$HDD_DEVICE"
mkdir -p "$VPS_STORAGE_MOUNT"

UUID="$(blkid -s UUID -o value "$HDD_DEVICE")"
if ! grep -q "$UUID" /etc/fstab; then
  echo "UUID=$UUID  $VPS_STORAGE_MOUNT  ext4  defaults,nofail  0  2" >> /etc/fstab
fi
mount "$VPS_STORAGE_MOUNT"

mkdir -p "$VPS_STORAGE_MOUNT/images" "$VPS_STORAGE_MOUNT/base-images" "$VPS_STORAGE_MOUNT/cloud-init"

echo "== 5. Baixando imagem base (cloud image) =="
BASE_IMAGE_PATH="$VPS_STORAGE_MOUNT/base-images/$BASE_IMAGE_NAME"
if [[ ! -f "$BASE_IMAGE_PATH" ]]; then
  wget -O "$BASE_IMAGE_PATH" "$BASE_IMAGE_URL"
else
  echo "Imagem base já existe em $BASE_IMAGE_PATH, pulando download."
fi

echo "== 6. Criando storage pool do libvirt ($VPS_STORAGE_POOL) =="
if ! virsh pool-info "$VPS_STORAGE_POOL" &>/dev/null; then
  virsh pool-define-as "$VPS_STORAGE_POOL" dir --target "$VPS_STORAGE_MOUNT/images"
  virsh pool-build "$VPS_STORAGE_POOL"
  virsh pool-start "$VPS_STORAGE_POOL"
  virsh pool-autostart "$VPS_STORAGE_POOL"
else
  echo "Pool $VPS_STORAGE_POOL já existe."
fi

echo "== 7. Criando rede NAT isolada para as VPS's ($VPS_NETWORK_NAME) =="
NETWORK_XML="/tmp/${VPS_NETWORK_NAME}.xml"
NET_GATEWAY="${VPS_NETWORK_CIDR%.*}.1"
NET_DHCP_START="${VPS_NETWORK_CIDR%.*}.100"
NET_DHCP_END="${VPS_NETWORK_CIDR%.*}.200"
NET_MASK="255.255.255.0"

cat > "$NETWORK_XML" <<EOF
<network>
  <name>${VPS_NETWORK_NAME}</name>
  <bridge name="${VPS_NETWORK_BRIDGE}"/>
  <forward mode="nat"/>
  <ip address="${NET_GATEWAY}" netmask="${NET_MASK}">
    <dhcp>
      <range start="${NET_DHCP_START}" end="${NET_DHCP_END}"/>
    </dhcp>
  </ip>
</network>
EOF

if ! virsh net-info "$VPS_NETWORK_NAME" &>/dev/null; then
  virsh net-define "$NETWORK_XML"
  virsh net-start "$VPS_NETWORK_NAME"
  virsh net-autostart "$VPS_NETWORK_NAME"
else
  echo "Rede $VPS_NETWORK_NAME já existe."
fi

echo "== 8. Habilitando libvirtd =="
systemctl enable --now libvirtd

REAL_USER="${SUDO_USER:-root}"
if [[ "$REAL_USER" != "root" ]]; then
  usermod -aG libvirt,kvm "$REAL_USER"
  echo "Usuário $REAL_USER adicionado aos grupos libvirt/kvm (faça logout/login para valer)."
fi

echo
echo "== Pronto =="
echo "Storage pool : $VPS_STORAGE_POOL  ($VPS_STORAGE_MOUNT/images)"
echo "Rede VPS     : $VPS_NETWORK_NAME  ($VPS_NETWORK_CIDR via $VPS_NETWORK_BRIDGE)"
echo "Imagem base  : $BASE_IMAGE_PATH"
echo
echo "Próximo passo: sudo ./scripts/harden-host.sh"
