// Let the cluster's nodes pull images from ACR using the kubelet managed identity.
// No registry passwords, no imagePullSecrets in your manifests.

param acrName string

@description('Object ID of the cluster kubelet managed identity.')
param kubeletObjectId string

// AcrPull
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, kubeletObjectId, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: kubeletObjectId
    principalType: 'ServicePrincipal'
  }
}
