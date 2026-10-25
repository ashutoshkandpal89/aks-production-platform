using './main.bicep'

// AKS Standard path. Values come from environment variables set by scripts/01-deploy-infra.sh
param clusterTier = 'standard'
param prefix = readEnvironmentVariable('AKS_PREFIX', 'aksprod')
param adminPrincipalId = readEnvironmentVariable('ADMIN_OBJECT_ID')

// Edit these if your region or quota needs it.
param systemNodeVmSize = readEnvironmentVariable('AKS_SYSTEM_VM_SIZE', 'Standard_D2s_v5')
param systemNodeCount = 2
param availabilityZones = [
  '1'
  '2'
  '3'
]
