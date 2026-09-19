#!/usr/bin/env bash
# Hardening básico do HOST (não da VPS). Rode como root, depois de install-host.sh.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Rode como root (sudo $0)." >&2
  exit 1
fi

SSH_PORT="${SSH_PORT:-22}"

echo "== 1. Firewall (ufw): nega tudo por padrão, libera SSH e o que for necessário =="
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ufw fail2ban unattended-upgrades

ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp" comment 'SSH do host'
# Portas de VPS expostas via manage-vps.sh port-forward precisam ser liberadas aqui
# também, ex: ufw allow 2201/tcp comment 'cliente1 ssh'
ufw --force enable

echo "== 2. fail2ban no SSH =="
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = 5
bantime = 1h
findtime = 10m
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

echo "== 3. Updates automáticos de segurança =="
dpkg-reconfigure -f noninteractive unattended-upgrades || true

echo "== 4. Hardening do SSH do host =="
SSHD_CONFIG=/etc/ssh/sshd_config
cp -n "$SSHD_CONFIG" "${SSHD_CONFIG}.bak-$(date +%s)" || true
sed -i \
  -e 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' \
  -e 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' \
  "$SSHD_CONFIG"
systemctl reload ssh || systemctl reload sshd || true

echo
echo "== Pronto =="
echo "ATENÇÃO: PasswordAuthentication foi desativado no host. Confirme que sua chave"
echo "pública SSH já está em ~/.ssh/authorized_keys ANTES de encerrar esta sessão,"
echo "ou você pode ficar trancado para fora do servidor."
