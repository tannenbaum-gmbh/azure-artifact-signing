#!/usr/bin/env bash
# ==============================================================================
# setup-certs-individual.sh
# Azure CLI commands for individual developers to configure Trusted Signing
#
# This script is intended for individual developers who are NOT part of an
# organization. It walks through:
#   1. Registering the resource provider
#   2. Creating a Trusted Signing account (if not already deployed via Bicep)
#   3. Submitting an identity validation request (individual/personal validation)
#   4. Creating a certificate profile once validation is approved
#   5. Assigning the signer role to yourself
#   6. Installing and using AzureSignTool for local signing
#
# Prerequisites:
#   - Azure CLI >= 2.55.0
#   - az extension: trusted-signing  (installed automatically below)
#   - Contributor role on the subscription (for resource creation)
#   - A valid email address associated with your Azure AD account
#
# NOTE: Identity validation for PublicTrust certificates requires Microsoft to
#       verify your identity. This process can take 1–5 business days.
#       For immediate testing use 'PublicTrustTest' profile type (no validation needed).
#
# Usage:
#   chmod +x scripts/setup-certs-individual.sh
#   Edit the "Configuration" section below, then run:
#   ./scripts/setup-certs-individual.sh
# ==============================================================================

set -euo pipefail

# ==============================================================================
# Configuration – edit these values
# ==============================================================================
LOCATION="eastus"                          # Azure region
RESOURCE_GROUP="rg-trusted-signing-dev"   # Resource group name
ACCOUNT_NAME="tsign-myproject-dev"        # Trusted Signing account name
PROFILE_NAME="default"                    # Certificate profile name
# Profile type for testing (no identity validation required):
PROFILE_TYPE="PublicTrustTest"
# For production signing, change to "PublicTrust" (requires identity validation).

# Your identity details for certificate subject (used with PublicTrust).
# These are embedded in the issued certificate.
YOUR_FIRST_NAME="Jane"
YOUR_LAST_NAME="Doe"
YOUR_EMAIL="jane.doe@example.com"
YOUR_COUNTRY="US"
# ==============================================================================

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
step()    { echo -e "\n\033[1;36m==> Step $*\033[0m"; }

# ---------------------------------------------------------------------------
# Step 1: Login and select subscription
# ---------------------------------------------------------------------------
step "1: Azure CLI login"
info "Logging in to Azure CLI..."
az login

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

info "Subscription : ${SUBSCRIPTION_ID}"
info "Tenant       : ${TENANT_ID}"
info "Your user ID : ${USER_OBJECT_ID}"

# ---------------------------------------------------------------------------
# Step 2: Register the resource provider
# ---------------------------------------------------------------------------
step "2: Register Microsoft.CodeSigning resource provider"
az provider register --namespace Microsoft.CodeSigning --wait
success "Resource provider registered."

# ---------------------------------------------------------------------------
# Step 3: Install the trusted-signing CLI extension
# ---------------------------------------------------------------------------
step "3: Install az trusted-signing extension"
if ! az extension show --name trusted-signing &>/dev/null; then
  az extension add --name trusted-signing
  success "Extension installed."
else
  info "Extension already installed. Updating..."
  az extension update --name trusted-signing || true
fi

# ---------------------------------------------------------------------------
# Step 4: Create resource group (skip if already exists)
# ---------------------------------------------------------------------------
step "4: Create resource group"
if az group show --name "${RESOURCE_GROUP}" &>/dev/null; then
  info "Resource group '${RESOURCE_GROUP}' already exists."
else
  az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"
  success "Resource group created."
fi

# ---------------------------------------------------------------------------
# Step 5: Create Trusted Signing account (skip if already exists)
# ---------------------------------------------------------------------------
step "5: Create Trusted Signing account"
ACCOUNT_EXISTS=$(az resource list \
  --resource-group "${RESOURCE_GROUP}" \
  --resource-type "Microsoft.CodeSigning/codeSigningAccounts" \
  --query "[?name=='${ACCOUNT_NAME}'].name" -o tsv)

if [[ -n "${ACCOUNT_EXISTS}" ]]; then
  info "Account '${ACCOUNT_NAME}' already exists."
else
  az trustedsigning account create \
    --name "${ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku-name "Basic"
  success "Trusted Signing account created."
fi

# ---------------------------------------------------------------------------
# Step 6: Submit identity validation (individual / personal)
# ---------------------------------------------------------------------------
# For PublicTrustTest this step is skipped; for PublicTrust it is required.
IDENTITY_VALIDATION_ID=""

if [[ "${PROFILE_TYPE}" == "PublicTrust" ]]; then
  step "6: Submit identity validation (individual developer)"
  warn "Individual identity validation requires Microsoft to review your identity."
  warn "This typically takes 1–5 business days."
  echo ""
  info "Submitting identity validation request for individual developer..."
  # The CLI command for identity validation uses the trusted-signing extension.
  # Replace --first-name, --last-name, etc. with your actual details.
  VALIDATION_RESPONSE=$(az trustedsigning identity-validation create \
    --account-name "${ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --validation-type "Individual" \
    --first-name "${YOUR_FIRST_NAME}" \
    --last-name "${YOUR_LAST_NAME}" \
    --email "${YOUR_EMAIL}" \
    --primary-email "${YOUR_EMAIL}" \
    --country "${YOUR_COUNTRY}" \
    --output json)

  IDENTITY_VALIDATION_ID=$(echo "${VALIDATION_RESPONSE}" | jq -r '.id // empty')
  success "Identity validation request submitted."
  warn "Wait for approval before creating a PublicTrust certificate profile."
  warn "Check status:"
  echo "  az trustedsigning identity-validation show \\"
  echo "    --account-name '${ACCOUNT_NAME}' \\"
  echo "    --resource-group '${RESOURCE_GROUP}' \\"
  echo "    --validation-id '${IDENTITY_VALIDATION_ID}'"
  echo ""
  read -r -p "Press ENTER once your identity validation is approved, or Ctrl+C to stop here and resume later..."
else
  step "6: Skip identity validation (PublicTrustTest does not require it)"
  info "No identity validation needed for PublicTrustTest profiles."
fi

# ---------------------------------------------------------------------------
# Step 7: Create certificate profile
# ---------------------------------------------------------------------------
step "7: Create certificate profile ('${PROFILE_NAME}', type: ${PROFILE_TYPE})"
PROFILE_EXISTS=$(az trustedsigning certificate-profile list \
  --account-name "${ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "[?name=='${PROFILE_NAME}'].name" -o tsv 2>/dev/null || true)

if [[ -n "${PROFILE_EXISTS}" ]]; then
  info "Certificate profile '${PROFILE_NAME}' already exists."
else
  if [[ "${PROFILE_TYPE}" == "PublicTrust" && -n "${IDENTITY_VALIDATION_ID}" ]]; then
    az trustedsigning certificate-profile create \
      --account-name "${ACCOUNT_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${PROFILE_NAME}" \
      --profile-type "${PROFILE_TYPE}" \
      --identity-validation-id "${IDENTITY_VALIDATION_ID}"
  else
    az trustedsigning certificate-profile create \
      --account-name "${ACCOUNT_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${PROFILE_NAME}" \
      --profile-type "${PROFILE_TYPE}"
  fi
  success "Certificate profile created."
fi

# ---------------------------------------------------------------------------
# Step 8: Assign 'Trusted Signing Certificate Profile Signer' role to yourself
# ---------------------------------------------------------------------------
step "8: Assign signer role to your user"
PROFILE_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CodeSigning/codeSigningAccounts/${ACCOUNT_NAME}/certificateProfiles/${PROFILE_NAME}"

info "Assigning 'Trusted Signing Certificate Profile Signer' role..."
az role assignment create \
  --role "Trusted Signing Certificate Profile Signer" \
  --assignee-object-id "${USER_OBJECT_ID}" \
  --assignee-principal-type User \
  --scope "${PROFILE_RESOURCE_ID}" \
  --output none
success "Role assigned."

# ---------------------------------------------------------------------------
# Step 9: Install AzureSignTool for local signing
# ---------------------------------------------------------------------------
step "9: Install AzureSignTool (.NET global tool)"
if command -v dotnet &>/dev/null; then
  if ! command -v AzureSignTool &>/dev/null 2>&1; then
    info "Installing AzureSignTool..."
    dotnet tool install --global AzureSignTool
    success "AzureSignTool installed."
  else
    info "AzureSignTool already installed."
  fi
else
  warn ".NET SDK not found. Install it from https://dotnet.microsoft.com/download"
  warn "Then run: dotnet tool install --global AzureSignTool"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
ENDPOINT="https://${LOCATION}.codesigning.azure.net"

echo ""
echo "============================================================"
success "Setup complete!"
echo "============================================================"
echo ""
echo "  Signing Endpoint : ${ENDPOINT}"
echo "  Account Name     : ${ACCOUNT_NAME}"
echo "  Profile Name     : ${PROFILE_NAME}"
echo ""
echo "To sign a file locally with AzureSignTool (using Azure CLI credential):"
echo ""
echo "  AzureSignTool sign \\"
echo "    --azure-key-vault-url '${ENDPOINT}' \\"
echo "    --trusted-signing-account-name '${ACCOUNT_NAME}' \\"
echo "    --trusted-signing-certificate-profile-name '${PROFILE_NAME}' \\"
echo "    --timestamp-rfc3161 'http://timestamp.acs.microsoft.com' \\"
echo "    --timestamp-digest sha256 \\"
echo "    --file-digest sha256 \\"
echo "    /path/to/your/file.exe"
echo ""
echo "Or with signtool.exe (Windows / Windows Subsystem for Linux):"
echo "  signtool sign /fd SHA256 /tr http://timestamp.acs.microsoft.com /td SHA256 \\"
echo "    /dlib 'Azure.CodeSigning.Dlib.dll' \\"
echo "    /dmdf metadata.json \\"
echo "    /path/to/your/file.exe"
echo ""
echo "  where metadata.json contains:"
echo '  { "Endpoint": "'"${ENDPOINT}"'", "CodeSigningAccountName": "'"${ACCOUNT_NAME}"'", "CertificateProfileName": "'"${PROFILE_NAME}"'" }'
