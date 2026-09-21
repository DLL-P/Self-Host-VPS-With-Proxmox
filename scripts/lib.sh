#!/usr/bin/env bash
# Funções e carregamento de config compartilhadas pelos scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${VPS_ENV_FILE:-$ROOT_DIR/config/vm.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Arquivo de configuração não encontrado: $ENV_FILE" >&2
  echo "Copie config/vm.env.example para config/vm.env e ajuste os valores." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Este script precisa rodar como root no host Proxmox." >&2
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Comando obrigatório não encontrado: $cmd" >&2
    exit 1
  fi
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}
