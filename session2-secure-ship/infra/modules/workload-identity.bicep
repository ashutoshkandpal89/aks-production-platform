// Workload identity for pods: a managed identity that ONE Kubernetes ServiceAccount
// can become, with read-only access to secrets in ONE Key Vault.
//
// How it works:
//   pod -> projected ServiceAccount token (signed by the cluster OIDC issuer)
//       -> Entra ID checks the federated credential below (issuer + subject match)
//       -> returns an Entra token for this managed identity
//       -> Key Vault accepts it because of the role assignment below
// Nothing secret is stored anywhere.

param name string
param location string
param tags object
param keyVaultName string

@description('OIDC issuer URL of the AKS cluster.')
param oidcIssuerUrl string

param workloadNamespace string
param serviceAccountName string

// Key Vault Secrets User: read secret values, nothing else
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: 'aks-${workloadNamespace}-${serviceAccountName}'
  properties: {
    issuer: oidcIssuerUrl
    subject: 'system:serviceaccount:${workloadNamespace}:${serviceAccountName}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, identity.id, secretsUserRoleId)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
