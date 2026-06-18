#!/usr/bin/env bash
# ==============================================================================
# delete.sh – Delete the Azure Trusted Signing resource group and all resources
#
# WARNING: This will permanently delete the resource group and ALL resources
#          within it, including the Trusted Signing account and certificate
#          profiles. This action cannot be undone.
#
# Prerequisites:
#   - Azure CLI installed and logged in  (az login)
#   - Contributor / Owner role on the target resource group or subscription
#
# Usage:
#   chmod +x scripts/delete.sh
#   ./scripts/delete.sh [--rg rg-trusted-signing-dev] [--yes]
#
# Flags:
#   --rg   Name of the resource group to delete (default: rg-trusted-signing-dev)
#   --yes  Skip the interactive confirmation prompt
# ==============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-trusted-signing-dev}"
SKIP_CONFIRM="${SKIP_CONFIRM:-false}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rg)  RESOURCE_GROUP="$2"; shift 2 ;;
    --yes) SKIP_CONFIRM="true"; shift ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# ---------------------------------------------------------------------------
# Verify Azure CLI login
# ---------------------------------------------------------------------------
info "Checking Azure CLI login..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || true)
if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  error "Not logged in to Azure CLI. Run: az login"
  exit 1
fi
info "Subscription : ${SUBSCRIPTION_ID}"

# ---------------------------------------------------------------------------
# Check resource group exists
# ---------------------------------------------------------------------------
info "Checking resource group '${RESOURCE_GROUP}'..."
if ! az group show --name "${RESOURCE_GROUP}" &>/dev/null; then
  warn "Resource group '${RESOURCE_GROUP}' does not exist. Nothing to delete."
  exit 0
fi

# ---------------------------------------------------------------------------
# Confirmation prompt
# ---------------------------------------------------------------------------
if [[ "${SKIP_CONFIRM}" != "true" ]]; then
  warn "You are about to delete resource group '${RESOURCE_GROUP}' and ALL its contents."
  warn "This includes the Trusted Signing account and all certificate profiles."
  read -r -p "Type the resource group name to confirm deletion: " CONFIRM
  if [[ "${CONFIRM}" != "${RESOURCE_GROUP}" ]]; then
    error "Confirmation did not match. Aborting."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------
info "Deleting resource group '${RESOURCE_GROUP}'..."
az group delete \
  --name "${RESOURCE_GROUP}" \
  --yes \
  --no-wait

info "Deletion request submitted (--no-wait). The resource group will be fully deleted within a few minutes."
info "Check status with:"
echo "  az group show --name '${RESOURCE_GROUP}'"
