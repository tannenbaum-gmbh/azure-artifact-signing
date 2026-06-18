// ============================================================
// Trusted Signing Account + Certificate Profile
// Resource provider: Microsoft.CodeSigning
// No Azure Verified Module (AVM) exists for this resource type,
// so this uses native Bicep resource declarations.
// ============================================================

@description('Azure region for the resources.')
param location string

@description('Name of the Trusted Signing account (3–24 characters, must start with a letter).')
@minLength(3)
@maxLength(24)
param accountName string

@description('SKU tier of the Trusted Signing account.')
@allowed(['Basic', 'Premium'])
param accountSku string = 'Basic'

@description('Name of the certificate profile to create inside the account.')
param certificateProfileName string = 'default'

@description('''Type of certificate profile.
- PublicTrustTest : Testing only – no identity validation required.
- PublicTrust     : Publicly trusted certificate – individual or org identity validation required.
- PrivateTrust    : Private / internal certificates – identity validation required.
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

@description('Tags to apply to all resources.')
param tags object = {}

// ---------------------------------------------------------------------------
// Trusted Signing Account
// API version: 2024-02-05-preview (latest documented preview as of 2024)
// ---------------------------------------------------------------------------
resource trustedSigningAccount 'Microsoft.CodeSigning/codeSigningAccounts@2024-02-05-preview' = {
  name: accountName
  location: location
  tags: tags
  properties: {
    sku: {
      name: accountSku
    }
  }
}

// ---------------------------------------------------------------------------
// Certificate Profile (child of the account)
// ---------------------------------------------------------------------------
resource certificateProfile 'Microsoft.CodeSigning/codeSigningAccounts/certificateProfiles@2024-02-05-preview' = {
  name: certificateProfileName
  parent: trustedSigningAccount
  properties: {
    profileType: profileType
    includeStreetAddress: includeStreetAddress
    includePostalCode: includePostalCode
    // identityValidationId is only required for PublicTrust / PrivateTrust profiles.
    identityValidationId: empty(identityValidationId) ? null : identityValidationId
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Resource ID of the Trusted Signing account.')
output accountId string = trustedSigningAccount.id

@description('Name of the Trusted Signing account.')
output accountName string = trustedSigningAccount.name

@description('Signing endpoint URI (format: https://<region>.codesigning.azure.net).')
output accountEndpoint string = 'https://${location}.codesigning.azure.net'

@description('Resource ID of the certificate profile.')
output certificateProfileId string = certificateProfile.id

@description('Name of the certificate profile.')
output certificateProfileName string = certificateProfile.name
