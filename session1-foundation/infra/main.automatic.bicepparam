using './main.bicep'

// AKS Automatic path. Values come from environment variables set by scripts/01-deploy-infra.sh
param clusterTier = 'automatic'
param prefix = readEnvironmentVariable('AKS_PREFIX', 'aksprod')
param adminPrincipalId = readEnvironmentVariable('ADMIN_OBJECT_ID')
