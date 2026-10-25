// =============================================================================
// Session 2 - Securing and Shipping on AKS
//
// Adds three things on top of the Session 1 cluster (Automatic or Standard):
//   1. Azure Key Vault (RBAC mode) holding a demo secret
//   2. A workload identity: pods read Key Vault with NO stored secret
//   3. A GitHub deploy identity: GitHub Actions deploys with OIDC, NO stored secret
//
// Deploy with ../scripts/01-deploy-identity.sh (it fills in the parameters).
// =============================================================================

targetScope = 'resourceGroup'

@description('Short prefix used in names. Letters and digits only.')
@minLength(3)
@maxLength(12)
param prefix string = 'aksprod'

param location string = resourceGroup().location

@description('Name of the existing AKS cluster from Session 1.')
param clusterName string

@description('Name of the existing Azure Container Registry from Session 1.')
param acrName string

@description('OIDC issuer URL of the cluster: az aks show --query oidcIssuerProfile.issuerUrl -o tsv')
param oidcIssuerUrl string

@description('Kubernetes namespace of the demo workload.')
param workloadNamespace string = 'secure-demo'

@description('Kubernetes ServiceAccount used by the demo workload.')
param serviceAccountName string = 'secret-reader-sa'

@description('GitHub user or organization that owns your copy of the repo.')
param githubOwner string

@description('Name of your copy of the repo.')
param githubRepo string

@description('Branch that is allowed to deploy.')
param githubBranch string = 'main'

@description('Object ID of the signed-in user. Lets you add the demo secret to Key Vault.')
param adminPrincipalId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param adminPrincipalType string = 'User'

param tags object = {
  project: 'aks-production-platform'
  session: '2-secure-ship'
}

var suffix = uniqueString(resourceGroup().id)
var keyVaultName = take('kv-${prefix}-${suffix}', 24)

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    adminPrincipalId: adminPrincipalId
    adminPrincipalType: adminPrincipalType
  }
}

module workloadIdentity 'modules/workload-identity.bicep' = {
  name: 'workload-identity'
  params: {
    name: 'id-${prefix}-secret-reader'
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.name
    oidcIssuerUrl: oidcIssuerUrl
    workloadNamespace: workloadNamespace
    serviceAccountName: serviceAccountName
  }
}

module githubIdentity 'modules/github-identity.bicep' = {
  name: 'github-identity'
  params: {
    name: 'id-${prefix}-github-deploy'
    location: location
    tags: tags
    acrName: acrName
    clusterName: clusterName
    githubSubject: 'repo:${githubOwner}/${githubRepo}:ref:refs/heads/${githubBranch}'
  }
}

output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri
output workloadIdentityClientId string = workloadIdentity.outputs.clientId
output githubIdentityClientId string = githubIdentity.outputs.clientId
output githubIdentityPrincipalId string = githubIdentity.outputs.principalId
output tenantId string = tenant().tenantId
