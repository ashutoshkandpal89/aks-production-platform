using './main.bicep'

// Values come from environment variables set by scripts/01-deploy-identity.sh
param prefix = readEnvironmentVariable('AKS_PREFIX', 'aksprod')
param clusterName = readEnvironmentVariable('CLUSTER_NAME')
param acrName = readEnvironmentVariable('ACR_NAME')
param oidcIssuerUrl = readEnvironmentVariable('OIDC_ISSUER_URL')
param githubOwner = readEnvironmentVariable('GITHUB_OWNER')
param githubRepo = readEnvironmentVariable('GITHUB_REPO')
param githubBranch = readEnvironmentVariable('GITHUB_BRANCH', 'main')
param adminPrincipalId = readEnvironmentVariable('ADMIN_OBJECT_ID')
