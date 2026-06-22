/* Content data for the Azure Trusted Signing interactive guide.
   Kept separate from rendering logic so it is easy to review and extend.
   Sources: Microsoft Learn (azure/trusted-signing, azure/container-registry),
   Win32 signtool docs, and the tannenbaum-gmbh/azure-artifact-signing repo. */

const FLOW_STEPS = [
  {
    title: 'Authenticate with Microsoft Entra ID',
    body:
      'A developer, build agent or pipeline obtains a token from Microsoft Entra ID. ' +
      'No certificates or private keys are distributed — identity is the credential. ' +
      'GitHub Actions and Azure DevOps can use OIDC (workload identity federation) to avoid storing secrets.'
  },
  {
    title: 'Authorize via RBAC',
    body:
      'Access is granted with the "Trusted Signing Certificate Profile Signer" role, scoped to a ' +
      'specific certificate profile. You decide exactly which identities may sign with which profile.'
  },
  {
    title: 'Sign the artifact',
    body:
      'The signing tool (signtool, AzureSignTool, Notation, etc.) sends a digest to the service. ' +
      'Microsoft mints a short-lived certificate, signs the digest inside a FIPS 140-2 Level 3 HSM, ' +
      'and returns the signature. The private key never leaves the HSM and is never exposed to you.'
  },
  {
    title: 'Timestamp the signature',
    body:
      'An RFC 3161 timestamp (http://timestamp.acs.microsoft.com) is countersigned. ' +
      'Because the signature is timestamped, it remains valid after the short-lived signing ' +
      'certificate expires — a core design principle of the service.'
  },
  {
    title: 'Verify anywhere',
    body:
      'Consumers verify the signature with standard tooling — Windows Authenticode / ' +
      'Get-AuthenticodeSignature, Notation for OCI artifacts, or platform trust stores. ' +
      'Public Trust certificates chain to the Microsoft root already trusted by Windows.'
  }
];

const USE_CASES = [
  {
    tag: 'classic', icon: '🪟', title: 'Windows application signing',
    body: 'Sign .exe, .dll, .msi, .msix, .cab, .sys and other PE files with Authenticode so Windows ' +
          'SmartScreen and Defender trust them and the "unknown publisher" warning disappears.'
  },
  {
    tag: 'classic', icon: '🧩', title: 'Drivers & kernel-mode code',
    body: 'Private Trust and CI policy profiles support driver and kernel scenarios, including ' +
          'Windows Hardware Quality Labs (WHQL) attestation flows.'
  },
  {
    tag: 'classic', icon: '📦', title: 'NuGet & app packages',
    body: 'Sign NuGet packages, MSIX/AppX bundles and ClickOnce manifests for trusted distribution ' +
          'through internal feeds or the Microsoft Store.'
  },
  {
    tag: 'supply-chain', icon: '🐳', title: 'Container images & OCI artifacts',
    body: 'Use Notation with the Azure Trusted Signing plugin to sign images in Azure Container ' +
          'Registry, then enforce verified-only deployment with admission controllers.'
  },
  {
    tag: 'supply-chain', icon: '🔗', title: 'Software supply-chain provenance',
    body: 'Provide tamper-evidence and verifiable provenance across your SBOM / SLSA story so ' +
          'consumers can prove an artifact came from you and was not altered in transit.'
  },
  {
    tag: 'classic', icon: '🏢', title: 'CI/CD pipeline signing',
    body: 'Centralize signing in GitHub Actions or Azure DevOps using OIDC. Build agents sign on ' +
          'demand without any certificate ever being copied onto a runner.'
  },
  {
    tag: 'emerging', icon: '🤝', title: 'Private/enterprise trust',
    body: 'Private Trust profiles let an organization sign internal tools and line-of-business apps ' +
          'against a trust anchor it controls and distributes to managed devices.'
  },
  {
    tag: 'emerging', icon: '🛡️', title: 'VBS enclave signing',
    body: 'Dedicated VBSEnclave profiles support signing Virtualization-Based Security enclave images ' +
          'for high-assurance, isolated workloads.'
  },
  {
    tag: 'emerging', icon: '🧪', title: 'Test & pre-production trust',
    body: 'PublicTrustTest profiles give a realistic signing experience for demos, training and ' +
          'pipeline validation without consuming Public Trust quota or identity validation.'
  }
];

const INTEGRATIONS = [
  {
    id: 'signtool', label: 'Windows binaries (signtool)', icon: '🪟',
    summary: 'The classic Windows SDK tool, now driven by the Trusted Signing dlib + metadata.json.',
    lang: 'bat',
    code:
      'signtool sign /fd SHA256 /tr http://timestamp.acs.microsoft.com /td SHA256 ^\n' +
      '  /dlib "Azure.CodeSigning.Dlib.dll" /dmdf metadata.json ^\n' +
      '  path\\to\\your\\app.exe',
    note: 'metadata.json holds the Endpoint, CodeSigningAccountName and CertificateProfileName.'
  },
  {
    id: 'azuresigntool', label: 'Cross-platform (AzureSignTool)', icon: '🐧',
    summary: 'A .NET global tool that signs PE files from Linux, macOS or Windows agents.',
    lang: 'bash',
    code:
      'AzureSignTool sign \\\n' +
      '  --azure-key-vault-url "https://eastus.codesigning.azure.net" \\\n' +
      '  --trusted-signing-account-name "tsign-myproject-dev" \\\n' +
      '  --trusted-signing-certificate-profile-name "default" \\\n' +
      '  --timestamp-rfc3161 "http://timestamp.acs.microsoft.com" \\\n' +
      '  --timestamp-digest sha256 --file-digest sha256 \\\n' +
      '  ./bin/app.exe',
    note: 'Install once with: dotnet tool install --global AzureSignTool.'
  },
  {
    id: 'notation', label: 'Container images (Notation + ACR)', icon: '🐳',
    summary: 'Sign OCI artifacts in Azure Container Registry and attach the signature as a manifest.',
    lang: 'bash',
    code:
      '# Install the Trusted Signing plugin, then:\n' +
      'notation sign \\\n' +
      '  $REGISTRY/$REPO@$DIGEST \\\n' +
      '  --plugin azure-codesigning \\\n' +
      '  --id "https://eastus.codesigning.azure.net/codesigningaccounts/acct/certificateprofiles/default"',
    note: 'Verify with: notation verify $REGISTRY/$REPO@$DIGEST. Always sign by digest, not tag.'
  },
  {
    id: 'github', label: 'CI/CD (GitHub Actions)', icon: '🚀',
    summary: 'Sign artifacts during a workflow using OIDC — no secrets stored in the repository.',
    lang: 'yaml',
    code:
      '- uses: azure/trusted-signing-action@v0\n' +
      '  with:\n' +
      '    endpoint: https://eastus.codesigning.azure.net\n' +
      '    trusted-signing-account-name: tsign-myproject-dev\n' +
      '    certificate-profile-name: default\n' +
      '    files-folder: ./publish\n' +
      '    files-folder-filter: exe,dll',
    note: 'Pair with azure/login@v3 (id-token: write) for keyless OIDC authentication.'
  }
];

const FIT_GOOD = [
  'Signing Windows executables, drivers, installers and packages at scale',
  'Centralized, keyless signing from CI/CD with Entra ID + OIDC',
  'Organizations wanting Microsoft to manage certificate lifecycle and HSM key storage',
  'Container / OCI artifact signing with Notation and ACR',
  'Meeting compliance needs for FIPS 140-2 Level 3 protected keys'
];

const FIT_BAD = [
  'Encrypting data or protecting secrets — signing is integrity, not confidentiality',
  'A malware scanner — a valid signature does not mean the code is safe',
  'General-purpose TLS / web server certificates (use Key Vault / public CAs)',
  'Email (S/MIME) or document e-signature workflows (use the right product for those)',
  'Storing arbitrary keys you control — you cannot export or directly access the private key',
  'Anonymous publishing — Public Trust requires verifiable identity validation'
];

const QUIZ = [
  {
    q: 'What kind of artifact do you need to sign?',
    options: [
      { t: 'Windows apps, drivers or installers', score: 'yes' },
      { t: 'Container images / OCI artifacts', score: 'yes' },
      { t: 'TLS certificates for a web server', score: 'no-tls' },
      { t: 'Emails or PDF documents', score: 'no-doc' }
    ]
  },
  {
    q: 'How do you want to manage signing keys?',
    options: [
      { t: 'Let Microsoft manage keys in an HSM', score: 'yes' },
      { t: 'I must export and hold the private key myself', score: 'no-key' },
      { t: 'I just want simple, secret-free CI signing', score: 'yes' }
    ]
  },
  {
    q: 'What is your trust requirement?',
    options: [
      { t: 'Public trust on Windows (remove SmartScreen warnings)', score: 'yes' },
      { t: 'Internal / enterprise-only trust', score: 'yes' },
      { t: 'Just experimenting / a demo', score: 'test' }
    ]
  }
];

const QUIZ_RESULTS = {
  yes: {
    icon: '✅', title: 'Trusted Signing is a strong fit',
    body: 'Your scenario aligns with the service\'s core strengths: managed keys, RBAC-controlled, ' +
          'keyless signing of code and artifacts. Start with a PublicTrustTest profile, then move to ' +
          'Public or Private Trust once identity validation is complete.'
  },
  test: {
    icon: '🧪', title: 'Start with a PublicTrustTest profile',
    body: 'Perfect for learning and demos. PublicTrustTest profiles need no identity validation and ' +
          'behave like the real thing — but are not trusted by Windows for production. Use the ' +
          'hands-on repo to deploy one in minutes.'
  },
  'no-tls': {
    icon: '🚫', title: 'Use a different service for TLS',
    body: 'Trusted Signing is for code/artifact signing, not web server certificates. Use Azure Key ' +
          'Vault certificates or a public TLS CA instead.'
  },
  'no-doc': {
    icon: '🚫', title: 'Not built for documents or email',
    body: 'Trusted Signing does not handle S/MIME email or PDF/document e-signatures. Choose a ' +
          'dedicated e-signature or S/MIME solution.'
  },
  'no-key': {
    icon: '⚠️', title: 'Key export is not supported',
    body: 'You can never export or directly access the private key — it stays in Microsoft\'s HSM. ' +
          'If you must hold the key yourself, use Azure Key Vault (Premium/HSM) or your own PKI instead.'
  }
};

const RESOURCES = [
  { t: 'Azure Trusted Signing — overview & docs', u: 'https://learn.microsoft.com/en-us/azure/trusted-signing/' },
  { t: 'Artifact Signing documentation', u: 'https://learn.microsoft.com/en-us/azure/artifact-signing/' },
  { t: 'Signing integrations (how-to)', u: 'https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations' },
  { t: 'Sign & verify a container image (Notation + ACR)', u: 'https://learn.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-sign-verify-notation-artifact-signing?tabs=linux' },
  { t: 'SignTool reference (Win32)', u: 'https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool' },
  { t: 'Hands-on repo: tannenbaum-gmbh/azure-artifact-signing', u: 'https://github.com/tannenbaum-gmbh/azure-artifact-signing' },
  { t: 'AzureSignTool', u: 'https://github.com/vcsjones/AzureSignTool' },
  { t: 'azure/trusted-signing-action', u: 'https://github.com/Azure/trusted-signing-action' }
];
