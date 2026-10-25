// Deploy identity for GitHub Actions: no client secret, no certificate.
//
// GitHub issues a short-lived OIDC token to the workflow run. Entra ID trusts it ONLY if
// the token's subject matches the federated credential below (your repo + branch).
//
// Rights granted here are deliberately small:
//   - AcrPush on the registry (push images)
//   - AKS Cluster User Role on the cluster (download kubeconfig, nothing more)
// Rights inside Kubernetes are granted per NAMESPACE by scripts/01-deploy-identity.sh.

param name string
param location string
param tags object
param acrName string
param clusterName string

@description('OIDC subject, for example repo:OWNER/REPO:ref:refs/heads/main')
param githubSubject string

// AcrPush
var acrPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'
// Azure Kubernetes Service Cluster User Role
var aksClusterUserRoleId = '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: 'github-actions'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: githubSubject
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource aks 'Microsoft.ContainerService/managedClusters@2026-04-01' existing = {
  name: clusterName
}

resource acrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, identity.id, acrPushRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource clusterUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, identity.id, aksClusterUserRoleId)
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', aksClusterUserRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
