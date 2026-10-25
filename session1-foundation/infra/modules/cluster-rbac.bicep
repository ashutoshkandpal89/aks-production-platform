// Give a person (or group) cluster-admin through Azure RBAC for Kubernetes.
// Local Kubernetes accounts are disabled, so without this role kubectl is denied.

param clusterName string

@description('Object ID of the user, group or service principal.')
param principalId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param principalType string = 'User'

// Azure Kubernetes Service RBAC Cluster Admin
var rbacClusterAdminRoleId = 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'

resource aks 'Microsoft.ContainerService/managedClusters@2026-04-01' existing = {
  name: clusterName
}

resource clusterAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, principalId, rbacClusterAdminRoleId)
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', rbacClusterAdminRoleId)
    principalId: principalId
    principalType: principalType
  }
}
