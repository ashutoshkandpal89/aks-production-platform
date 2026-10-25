// Virtual network for the Standard path.
// With Azure CNI Overlay only NODES consume subnet addresses, so a /22 (about 1,000 nodes)
// is plenty. Pod IPs come from the cluster podCidr instead.

param name string
param location string
param tags object

param vnetAddressPrefix string = '10.10.0.0/16'
param nodeSubnetPrefix string = '10.10.0.0/22'

@description('Principal ID of the cluster control plane identity. It needs Network Contributor on the VNet.')
param controlPlanePrincipalId string

// Network Contributor
var networkContributorRoleId = '4d97b98b-1d4f-4787-a291-c67834d212e7'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-aks-nodes'
        properties: {
          addressPrefix: nodeSubnetPrefix
        }
      }
    ]
  }
}

resource networkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, controlPlanePrincipalId, networkContributorRoleId)
  scope: vnet
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkContributorRoleId)
    principalId: controlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

output nodeSubnetId string = vnet.properties.subnets[0].id
