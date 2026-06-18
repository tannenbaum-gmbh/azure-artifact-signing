#!/usr/bin/env bash
# ==============================================================================
# deploy.sh – Convenience script to deploy Azure Trusted Signing infrastructure
#
# Prerequisites:
#   - Azure CLI installed and logged in  (az login)
#   - Bicep CLI installed or az bicep install
#   - Contributor role on the target subscription
#   - Microsoft.CodeSigning resource provider registered (done automatically below)
#
# Usage:
#   chmod +x scripts/deploy.sh
#   ./scripts/deploy.sh [--location eastus] [--rg rg-trusted-signing-dev] \
#                       [--account tsign-myproject-dev] [--sku Basic] \
#                       [--profile-name default] [--profile-type PublicTrustTest] \
#                       [--identity-validation-id <id>]
#
# All flags are optional; defaults match main.bicepparam.
# ==============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults (override with flags or environment variables)
# ---------------------------------------------------------------------------
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-trusted-signing-dev}"
ACCOUNT_NAME="${ACCOUNT_NAME:-tsign-myproject-dev}"
ACCOUNT_SKU="${ACCOUNT_SKU:-Basic}"
PROFILE_NAME="${PROFILE_NAME:-default}"
PROFILE_TYPE="${PROFILE_TYPE:-PublicTrustTest}"
IDENTITY_VALIDATION_ID="${IDENTITY_VALIDATION_ID:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --location)               LOCATION="$2";               shift 2 ;;
    --rg)                     RESOURCE_GROUP="$2";          shift 2 ;;
    --account)                ACCOUNT_NAME="$2";            shift 2 ;;
    --sku)                    ACCOUNT_SKU="$2";             shift 2 ;;
    --profile-name)           PROFILE_NAME="$2";            shift 2 ;;
    --profile-type)           PROFILE_TYPE="$2";            shift 2 ;;
    --identity-validation-id) IDENTITY_VALIDATION_ID="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }

# ---------------------------------------------------------------------------
# Verify Azure CLI login
# ---------------------------------------------------------------------------
info "Checking Azure CLI login..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || true)
if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  warn "Not logged in to Azure CLI. Run: az login"
  exit 1
fi
TENANT_ID=$(az account show --query tenantId -o tsv)
info "Subscription : ${SUBSCRIPTION_ID}"
info "Tenant       : ${TENANT_ID}"

# ---------------------------------------------------------------------------
# Register Microsoft.CodeSigning resource provider
# ---------------------------------------------------------------------------
info "Registering Microsoft.CodeSigning resource provider..."
az provider register --namespace Microsoft.CodeSigning --wait
success "Resource provider registered."

# ---------------------------------------------------------------------------
# Ensure Bicep CLI is available
# ---------------------------------------------------------------------------
if ! az bicep version &>/dev/null; then
  info "Installing Bicep CLI..."
  az bicep install
fi

# ---------------------------------------------------------------------------
# Build inline parameter overrides (use array to preserve quoting)
# ---------------------------------------------------------------------------
PARAMS=(
  "location=${LOCATION}"
  "resourceGroupName=${RESOURCE_GROUP}"
  "accountName=${ACCOUNT_NAME}"
  "accountSku=${ACCOUNT_SKU}"
  "certificateProfileName=${PROFILE_NAME}"
  "profileType=${PROFILE_TYPE}"
)
if [[ -n "${IDENTITY_VALIDATION_ID}" ]]; then
  PARAMS+=("identityValidationId=${IDENTITY_VALIDATION_ID}")
fi

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
DEPLOYMENT_NAME="trusted-signing-$(date +%Y%m%d%H%M%S)"

info "Starting deployment '${DEPLOYMENT_NAME}'..."
info "  Location       : ${LOCATION}"
info "  Resource Group : ${RESOURCE_GROUP}"
info "  Account Name   : ${ACCOUNT_NAME}"
info "  SKU            : ${ACCOUNT_SKU}"
info "  Profile Name   : ${PROFILE_NAME}"
info "  Profile Type   : ${PROFILE_TYPE}"

az deployment sub create \
  --name "${DEPLOYMENT_NAME}" \
  --location "${LOCATION}" \
  --template-file "${REPO_ROOT}/bicep/main.bicep" \
  --parameters "${REPO_ROOT}/bicep/main.bicepparam" \
  --parameters "${PARAMS[@]}" \
  --output table

success "Deployment completed successfully."
echo ""
info "Outputs:"
az deployment sub show \
  --name "${DEPLOYMENT_NAME}" \
  --query properties.outputs \
  --output table

echo ""
info "Next steps:"
echo "  1. If using PublicTrust/PrivateTrust, complete identity validation in the portal:"
echo "     https://portal.azure.com/#browse/Microsoft.CodeSigning%2FcodeSigningAccounts"
echo "  2. Assign the 'Trusted Signing Certificate Profile Signer' role to identities that"
echo "     need to sign artifacts:"
echo "     az role assignment create --role 'Trusted Signing Certificate Profile Signer' \\"
echo "       --assignee <user-or-sp-object-id> \\"
echo "       --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CodeSigning/codeSigningAccounts/${ACCOUNT_NAME}/certificateProfiles/${PROFILE_NAME}"
echo "  3. Run setup-certs-individual.sh for additional signing tool configuration."
