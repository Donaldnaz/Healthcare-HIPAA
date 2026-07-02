#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# deploy.sh — Build Lambda TypeScript and deploy the S3 auto-remediation stack.
#
# Prerequisites:
#   - AWS CLI configured (AWS_PROFILE / AWS_REGION optional)
#   - Terraform >= 1.5
#   - Node.js >= 18 and npm
#   - CloudTrail with management events delivered to EventBridge
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_ENV_DIR="${PROJECT_ROOT}/terraform/environments/dev"
LAMBDA_DIR="${PROJECT_ROOT}/terraform/modules/lambda"

log() { echo "[deploy] $*"; }
err() { echo "[deploy] ERROR: $*" >&2; exit 1; }

# --- Prerequisite checks ---
command -v terraform >/dev/null 2>&1 || err "terraform is not installed"
command -v aws >/dev/null 2>&1 || err "aws CLI is not installed"
command -v node >/dev/null 2>&1 || err "node is not installed"
command -v npm >/dev/null 2>&1 || err "npm is not installed"

log "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null || err "AWS credentials not configured"

log ""
log "=== PREREQUISITE REMINDER ==="
log "CloudTrail must deliver management events to EventBridge."
log "Verify your trail has eventBridgeEnabled / EnableEventBridge set to true."
log "============================="
log ""

# --- Terraform variables ---
if [[ ! -f "${TF_ENV_DIR}/terraform.tfvars" ]]; then
  log "terraform.tfvars not found — copying from example"
  cp "${TF_ENV_DIR}/terraform.tfvars.example" "${TF_ENV_DIR}/terraform.tfvars"
  log "Edit ${TF_ENV_DIR}/terraform.tfvars to set slack_webhook_url if needed."
fi

# --- Terraform init ---
log "Initializing Terraform..."
cd "${TF_ENV_DIR}"
terraform init -input=false

# --- Materialize TypeScript source from Terraform local_file ---
log "Materializing Lambda TypeScript source..."
terraform apply \
  -target=module.lambda.local_file.lambda_source \
  -auto-approve \
  -input=false

# --- Build Lambda bundle ---
log "Installing Lambda dependencies and building bundle..."
cd "${LAMBDA_DIR}"
npm install
npm run build

if [[ ! -f "${LAMBDA_DIR}/dist/index.js" ]]; then
  err "Lambda build failed — dist/index.js not found"
fi

# --- Deploy full stack ---
log "Planning infrastructure changes..."
cd "${TF_ENV_DIR}"
terraform plan -out=tfplan -input=false

log "Applying infrastructure..."
terraform apply -input=false tfplan
rm -f tfplan

log ""
log "=== Deployment Complete ==="
terraform output
log ""
log "Monitor remediation logs:"
log "  aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow"
