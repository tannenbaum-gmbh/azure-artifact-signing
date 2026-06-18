# Azure Artifact Signing (Azure Trusted Signing)

Playground and reference implementation for [Azure Trusted Signing](https://learn.microsoft.com/en-us/azure/trusted-signing/overview) (formerly Azure Code Signing / Azure Artifact Signing).

This repository provides:

- **Bicep infrastructure templates** – resource group (via AVM), Trusted Signing account and certificate profile (native Bicep, no AVM module exists for `Microsoft.CodeSigning`)
- **Convenience shell scripts** – deploy, delete, and individual-developer certificate setup
- **GitHub Actions workflows** – deployment and deletion workflows using `workflow_dispatch` and OIDC authentication

---

## Table of Contents

1. [Architecture](#architecture)
2. [Prerequisites](#prerequisites)
3. [OIDC Setup (GitHub Actions)](#oidc-setup-github-actions)
4. [Deploying with GitHub Actions](#deploying-with-github-actions)
5. [Deploying Manually (scripts)](#deploying-manually-scripts)
6. [Individual Developer Certificate Setup](#individual-developer-certificate-setup)
7. [Signing Artifacts](#signing-artifacts)
8. [Deleting Resources](#deleting-resources)
9. [Repository Structure](#repository-structure)

---

## Architecture

```
Subscription
└── Resource Group  (created via AVM: avm/res/resources/resource-group)
    └── Microsoft.CodeSigning/codeSigningAccounts  (native Bicep – no AVM module exists)
        └── certificateProfiles/<profile-name>
```

### AVM module check

| Resource | AVM module available? | Used module |
|---|---|---|
| Resource Group | ✅ Yes | `br/public:avm/res/resources/resource-group:0.4.0` |
| `Microsoft.CodeSigning/codeSigningAccounts` | ❌ No | Native Bicep resource declaration |
| `Microsoft.CodeSigning/codeSigningAccounts/certificateProfiles` | ❌ No | Native Bicep resource declaration |

---

## Prerequisites

| Tool | Minimum version | Install |
|---|---|---|
| Azure CLI | 2.55.0 | <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli> |
| Bicep CLI | latest | `az bicep install` |
| Azure subscription | – | Contributor or Owner role required |
| .NET SDK *(optional, for local signing)* | 6.0 | <https://dotnet.microsoft.com/download> |

---

## OIDC Setup (GitHub Actions)

Both workflows authenticate to Azure using **OpenID Connect (OIDC)** – no long-lived secrets are stored in GitHub.

### 1 – Create an App Registration

```bash
# Log in and note your tenant and subscription IDs
az login
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create the app registration
APP_NAME="github-actions-trusted-signing"
APP_ID=$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)
SP_OBJECT_ID=$(az ad sp create --id "${APP_ID}" --query id -o tsv)

echo "Client ID (APP_ID)  : ${APP_ID}"
echo "Tenant ID           : ${TENANT_ID}"
echo "Subscription ID     : ${SUBSCRIPTION_ID}"
```

### 2 – Add a Federated Credential

Replace `<owner>` and `<repo>` with your GitHub organisation/user and repository name.

```bash
GITHUB_OWNER="<owner>"   # e.g. myorg or myusername
GITHUB_REPO="<repo>"     # e.g. azure-artifact-signing

# Federated credential for the main branch (optional; only needed if you later add push/pull_request triggers on main)
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_OWNER}/${GITHUB_REPO}"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Federated credential for the 'azure' GitHub environment
# (used by workflow_dispatch jobs that set `environment: azure`)
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-actions-environment-azure",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_OWNER}/${GITHUB_REPO}"':environment:azure",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 3 – Assign the Contributor Role

```bash
# Contributor on the subscription (needed to create resource groups and resources)
az role assignment create \
  --role "Contributor" \
  --assignee-object-id "${SP_OBJECT_ID}" \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/${SUBSCRIPTION_ID}"
```

### 4 – Set GitHub Actions Variables

Go to your repository → **Settings** → **Secrets and variables** → **Actions** → **Variables** tab and add:

| Variable name | Value |
|---|---|
| `AZURE_CLIENT_ID` | The `APP_ID` (client ID) from step 1 |
| `AZURE_TENANT_ID` | The `TENANT_ID` from step 1 |
| `AZURE_SUBSCRIPTION_ID` | The `SUBSCRIPTION_ID` from step 1 |

> **Why variables, not secrets?** The client ID and tenant ID are not secret values; storing them as plain variables makes the workflow easier to inspect and audit. The OIDC token exchange does not require a client secret.

---

## Deploying with GitHub Actions

1. Complete the [OIDC Setup](#oidc-setup-github-actions) above.
2. Go to **Actions** → **Deploy – Azure Trusted Signing** → **Run workflow**.
3. Fill in the inputs (all have sensible defaults) and click **Run workflow**.

The workflow will:
- Register the `Microsoft.CodeSigning` resource provider
- Deploy the Bicep template at subscription scope
- Print the signing endpoint and resource IDs in the job summary

---

## Deploying Manually (scripts)

### Option A – Using the deploy script

```bash
chmod +x scripts/deploy.sh scripts/delete.sh scripts/setup-certs-individual.sh

# Deploy with defaults (matches main.bicepparam)
./scripts/deploy.sh

# Or override specific parameters
./scripts/deploy.sh \
  --location westeurope \
  --rg rg-trusted-signing-prod \
  --account tsign-myapp-prod \
  --sku Premium \
  --profile-type PublicTrustTest
```

### Option B – Using Azure CLI directly

```bash
az login

# Register provider (idempotent)
az provider register --namespace Microsoft.CodeSigning --wait

# Install Bicep CLI
az bicep install

# Deploy at subscription scope
az deployment sub create \
  --location eastus \
  --template-file bicep/main.bicep \
  --parameters bicep/main.bicepparam
```

---

## Individual Developer Certificate Setup

If you are an individual developer (not an organisation), run the interactive setup script:

```bash
chmod +x scripts/setup-certs-individual.sh

# Edit the "Configuration" section at the top of the script first, then:
./scripts/setup-certs-individual.sh
```

The script performs the following steps automatically:

| Step | Description |
|---|---|
| 1 | Log in to Azure CLI |
| 2 | Register `Microsoft.CodeSigning` provider |
| 3 | Install the `trusted-signing` CLI extension |
| 4 | Create resource group |
| 5 | Create Trusted Signing account |
| 6 | Submit individual identity validation *(PublicTrust only)* |
| 7 | Create certificate profile |
| 8 | Assign `Trusted Signing Certificate Profile Signer` role to you |
| 9 | Install `AzureSignTool` .NET global tool |

> **Note on identity validation:** For `PublicTrustTest` profiles no identity validation is needed and you can sign immediately. For `PublicTrust` certificates, Microsoft verifies your personal identity (typically 1–5 business days).

---

## Signing Artifacts

### With AzureSignTool (cross-platform, recommended)

```bash
# Install once
dotnet tool install --global AzureSignTool

# Sign a file
AzureSignTool sign \
  --azure-key-vault-url "https://eastus.codesigning.azure.net" \
  --trusted-signing-account-name "tsign-myproject-dev" \
  --trusted-signing-certificate-profile-name "default" \
  --timestamp-rfc3161 "http://timestamp.acs.microsoft.com" \
  --timestamp-digest sha256 \
  --file-digest sha256 \
  /path/to/your/file.exe
```

### With signtool.exe (Windows)

1. Download the Azure Code Signing dlib from the [Azure Trusted Signing SDK](https://www.nuget.org/packages/Microsoft.Trusted.Signing.Client).
2. Create `metadata.json`:
   ```json
   {
     "Endpoint": "https://eastus.codesigning.azure.net",
     "CodeSigningAccountName": "tsign-myproject-dev",
     "CertificateProfileName": "default"
   }
   ```
3. Sign:
   ```bat
   signtool sign /fd SHA256 /tr http://timestamp.acs.microsoft.com /td SHA256 ^
     /dlib "Azure.CodeSigning.Dlib.dll" /dmdf metadata.json ^
     path\to\your\file.exe
   ```

---

## Deleting Resources

### Via GitHub Actions

Go to **Actions** → **Delete – Azure Trusted Signing** → **Run workflow**.  
Enter the resource group name twice (the second field acts as a confirmation safeguard).

### Via the delete script

```bash
# Interactive (prompts for confirmation)
./scripts/delete.sh --rg rg-trusted-signing-dev

# Non-interactive (for automation)
./scripts/delete.sh --rg rg-trusted-signing-dev --yes
```

### Via Azure CLI directly

```bash
az group delete --name rg-trusted-signing-dev --yes
```

---

## Repository Structure

```
.
├── bicep/
│   ├── main.bicep               # Subscription-scope entry point
│   ├── main.bicepparam          # Default parameter values
│   └── modules/
│       └── trustedSigningAccount.bicep  # Signing account + certificate profile
├── scripts/
│   ├── deploy.sh                # Convenience deployment script
│   ├── delete.sh                # Resource deletion script
│   └── setup-certs-individual.sh  # Individual developer cert setup (Azure CLI)
├── .github/
│   └── workflows/
│       ├── deploy.yml           # Deploy workflow (workflow_dispatch + OIDC)
│       └── delete.yml           # Delete workflow (workflow_dispatch + OIDC)
└── README.md
```

---

## References

- [Azure Trusted Signing documentation](https://learn.microsoft.com/en-us/azure/trusted-signing/)
- [Azure Trusted Signing quickstart](https://learn.microsoft.com/en-us/azure/trusted-signing/quickstart)
- [Microsoft.CodeSigning Bicep reference](https://learn.microsoft.com/en-us/azure/templates/microsoft.codesigning/codesigningaccounts)
- [Azure Verified Modules (AVM)](https://aka.ms/AVM)
- [AVM resource-group module](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group)
- [AzureSignTool](https://github.com/vcsjones/AzureSignTool)
- [Connect GitHub Actions to Azure with OIDC](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
