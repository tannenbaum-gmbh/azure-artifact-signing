// ============================================================
// Parameter file for Azure Trusted Signing deployment
// Edit these values before deploying.
// ============================================================

using './main.bicep'

// Azure region – choose a region where Trusted Signing is available.
// Supported regions: eastus, westus2, westeurope, northeurope, eastasia, australiaeast, uksouth, canadacentral
param location = 'eastus'

// Name of the resource group that will be created to hold all resources.
param resourceGroupName = 'rg-trusted-signing-dev'

// Name of the Trusted Signing account.
// Must be globally unique, 3–24 chars, start with a letter, alphanumeric + hyphens.
param accountName = 'tsign-myproject-dev'

// SKU: 'Basic' (4 signing requests/minute) or 'Premium' (higher throughput).
param accountSku = 'Basic'

// Certificate profile name (logical label within the account).
param certificateProfileName = 'default'

// Profile type:
//   'PublicTrustTest' – recommended for initial testing (no identity validation needed).
//   'PublicTrust'     – production, publicly trusted; requires identity validation.
//   'PrivateTrust'    – internal/private; requires identity validation.
param profileType = 'PublicTrustTest'

// Leave empty for PublicTrustTest.
// For PublicTrust / PrivateTrust, paste the identity validation ID from the portal.
param identityValidationId = ''

// Subject name fields (optional, only relevant for PublicTrust / PrivateTrust).
param includeStreetAddress = false
param includePostalCode = false

// Tags applied to every resource.
param tags = {
  solution: 'azure-artifact-signing'
  environment: 'dev'
  managedBy: 'bicep'
}
