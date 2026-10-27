// Azure Key Vault in RBAC mode (no legacy access policies).
//
// Lab settings, called out so you change them for real workloads:
//   - public network access is enabled  -> use a private endpoint in production
//   - purge protection is off           -> turn it ON in production
// Soft delete is on, so a deleted vault name stays reserved until the retention ends
// (the teardown script purges it).

param name string
param location string
param tags object
param adminPrincipalId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param adminPrincipalType string

// Key Vault Secrets Officer: lets you create the demo secret
var secretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
  }
}

resource admin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, adminPrincipalId, secretsOfficerRoleId)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsOfficerRoleId)
    principalId: adminPrincipalId
    principalType: adminPrincipalType
  }
}

output name string = kv.name
output id string = kv.id
output uri string = kv.properties.vaultUri
