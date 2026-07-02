#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# destroy.sh — Tear down the S3 auto-remediation Terraform stack.
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_ENV_DIR="${PROJECT_ROOT}/terraform/environments/dev"
LAMBDA_DIR="${PROJECT_ROOT}/terraform/modules/lambda"

AUTO_APPROVE=false

usage() {
  echo "Usage: $0 [-y]"
  echo "  -y  Skip confirmation prompt and destroy immediately"
}

while getopts "yh" opt; do
  case "${opt}" in
    y) AUTO_APPROVE=true ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

log() { echo "[destroy] $*"; }
err() { echo "[destroy] ERROR: $*" >&2; exit 1; }

command -v terraform >/dev/null 2>&1 || err "terraform is not installed"

if [[ ! -d "${TF_ENV_DIR}/.terraform" ]]; then
  log "Terraform not initialized — running init"
  cd "${TF_ENV_DIR}"
  terraform init -input=false
fi

# Ensure Lambda zip source exists if state references it
if [[ -f "${LAMBDA_DIR}/package.json" ]]; then
  if [[ ! -f "${LAMBDA_DIR}/dist/index.js" ]]; then
    log "Building Lambda bundle for consistent destroy..."
    cd "${LAMBDA_DIR}"
    if [[ -f "${LAMBDA_DIR}/src/index.ts" ]]; then
      npm install --silent 2>/dev/null || npm install
      npm run build
    fi
  fi
fi

cd "${TF_ENV_DIR}"

if [[ "${AUTO_APPROVE}" != "true" ]]; then
  echo ""
  echo "WARNING: This will destroy all resources in the S3 auto-remediation stack."
  echo "Environment: ${TF_ENV_DIR}"
  echo ""
  read -r -p "Type 'yes' to confirm destruction: " confirm
  if [[ "${confirm}" != "yes" ]]; then
    log "Aborted."
    exit 0
  fi
fi

log "Destroying infrastructure..."
terraform destroy -auto-approve -input=false

# --- Optional local cleanup ---
log "Cleaning local build artifacts..."
rm -rf "${LAMBDA_DIR}/dist" "${LAMBDA_DIR}/build" "${LAMBDA_DIR}/node_modules"

log "Teardown complete."
