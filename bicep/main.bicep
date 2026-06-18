// ============================================================
// Azure Trusted Signing – Main Deployment Template
// Scope: Azure Subscription
//
// Resources created:
//   1. Resource Group          – via AVM module (avm/res/resources/resource-group)
//   2. Trusted Signing Account – native Bicep (no AVM module available)
//   3. Certificate Profile     – native Bicep (child resource of account)
//
// Azure Verified Modules (AVM) check:
//   - Resource Group : AVM module available → br/public:avm/res/resources/resource-group
//   - Microsoft.CodeSigning/codeSigningAccounts : No AVM module available → native Bicep
// ============================================================

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string = 'eastus'

@description('Name of the resource group to create.')
param resourceGroupName string

@description('Name of the Trusted Signing account (3–24 characters, must start with a letter, alphanumeric and hyphens only).')
@minLength(3)
@maxLength(24)
param accountName string

@description('SKU tier for the Trusted Signing account.')
@allowed(['Basic', 'Premium'])
param accountSku string = 'Basic'

@description('Name of the certificate profile.')
param certificateProfileName string = 'default'

@description('''Certificate profile type.
- PublicTrustTest : Testing only – no identity validation required. Recommended for first-time setup.
- PublicTrust     : Production-grade publicly trusted certificate. Requires completed identity validation.
- PrivateTrust    : Private / internal signing. Requires identity validation.
- PrivateTrustCIPolicy : CI policy signing.
- VBSEnclave      : VBS enclave signing.
''')
@allowed(['PublicTrust', 'PublicTrustTest', 'PrivateTrust', 'PrivateTrustCIPolicy', 'VBSEnclave'])
param profileType string = 'PublicTrustTest'

@description('Identity validation ID from the Trusted Signing portal. Required for PublicTrust and PrivateTrust profiles; leave empty for PublicTrustTest.')
param identityValidationId string = ''

@description('Include street address in the certificate subject.')
param includeStreetAddress bool = false

@description('Include postal code in the certificate subject.')
param includePostalCode bool = false

@description('Tags applied to all created resources.')
param tags object = {
  solution: 'azure-artifact-signing'
  managedBy: 'bicep'
}

// ---------------------------------------------------------------------------
// Resource Group
// AVM module: br/public:avm/res/resources/resource-group
// See: https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group
// Check https://aka.ms/AVM for the latest available version.
// ---------------------------------------------------------------------------
module resourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'resourceGroupDeployment'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
    enableTelemetry: false
  }
}

// ---------------------------------------------------------------------------
// Trusted Signing Account + Certificate Profile
// Deployed into the resource group created above.
// No AVM module exists for Microsoft.CodeSigning – using native Bicep.
// ---------------------------------------------------------------------------
module trustedSigning 'modules/trustedSigningAccount.bicep' = {
  name: 'trustedSigningDeployment'
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [resourceGroup]
  params: {
    location: location
    accountName: accountName
    accountSku: accountSku
    certificateProfileName: certificateProfileName
    profileType: profileType
    identityValidationId: identityValidationId
    includeStreetAddress: includeStreetAddress
    includePostalCode: includePostalCode
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Resource ID of the created resource group.')
output resourceGroupId string = resourceGroup.outputs.resourceId

@description('Resource ID of the Trusted Signing account.')
output trustedSigningAccountId string = trustedSigning.outputs.accountId

@description('Name of the Trusted Signing account.')
output trustedSigningAccountName string = trustedSigning.outputs.accountName

@description('Signing endpoint URI to use with signtool / AzureSignTool.')
output signingEndpoint string = trustedSigning.outputs.accountEndpoint

@description('Name of the certificate profile.')
output certificateProfileName string = trustedSigning.outputs.certificateProfileName
