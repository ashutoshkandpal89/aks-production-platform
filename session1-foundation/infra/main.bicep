// =============================================================================
// Session 1 - Building a Production-Ready AKS Foundation
//
// One template, two paths:
//   clusterTier = 'automatic'  -> Azure manages nodes, networking, scaling, safeguards
//   clusterTier = 'standard'   -> you own the VNet, identity, node pool and add-on choices
//
// Both paths also create an Azure Container Registry (ACR) and let the cluster
// pull images from it with a managed identity (no passwords, no image pull secrets).
//
// Deploy with the helper script:  ../scripts/01-deploy-infra.sh
// =============================================================================

targetScope = 'resourceGroup'

@description('Which AKS flavour to deploy.')
@allowed([
  'automatic'
  'standard'
])
param clusterTier string = 'automatic'

@description('Short prefix used in resource names. Letters and digits only (it is reused in the ACR name).')
@minLength(3)
@maxLength(12)
param prefix string = 'aksprod'

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Object ID of the user (or group) that becomes cluster admin through Azure RBAC. Get yours with: az ad signed-in-user show --query id -o tsv')
param adminPrincipalId string

@description('Type of the principal in adminPrincipalId.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param adminPrincipalType string = 'User'

@description('Kubernetes version, for example 1.34. Leave empty to use the AKS default for the region.')
param kubernetesVersion string = ''

@description('Standard only: VM size for the system node pool. Check quota in your region first.')
param systemNodeVmSize string = 'Standard_D2s_v5'

@description('Standard only: number of system nodes.')
@minValue(1)
param systemNodeCount int = 2

@description('Standard only: availability zones for the system pool. Use an empty array [] in regions without zones.')
param availabilityZones array = [
  '1'
  '2'
  '3'
]

@description('Tags applied to every resource.')
param tags object = {
  project: 'aks-production-platform'
  session: '1-foundation'
}

// -----------------------------------------------------------------------------
// Names
// -----------------------------------------------------------------------------
var suffix = uniqueString(resourceGroup().id)
var clusterName = 'aks-${prefix}-${clusterTier}'
var acrName = toLower(take('acr${prefix}${suffix}', 50))

// -----------------------------------------------------------------------------
// Standard path only: identity + network that YOU own
// (Automatic creates and manages these for you.)
// -----------------------------------------------------------------------------
module identity 'modules/identity.bicep' = if (clusterTier == 'standard') {
  name: 'identity'
  params: {
    name: 'id-${clusterName}'
    location: location
    tags: tags
  }
}

module network 'modules/network.bicep' = if (clusterTier == 'standard') {
  name: 'network'
  params: {
    name: 'vnet-${clusterName}'
    location: location
    tags: tags
    controlPlanePrincipalId: identity!.outputs.principalId
  }
}

// -----------------------------------------------------------------------------
// Container registry (both paths)
// -----------------------------------------------------------------------------
module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    name: acrName
    location: location
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// The cluster - compare these two modules side by side
// -----------------------------------------------------------------------------
module aksAutomatic 'modules/aks-automatic.bicep' = if (clusterTier == 'automatic') {
  name: 'aks-automatic'
  params: {
    name: clusterName
    location: location
    tags: tags
    kubernetesVersion: kubernetesVersion
  }
}

module aksStandard 'modules/aks-standard.bicep' = if (clusterTier == 'standard') {
  name: 'aks-standard'
  params: {
    name: clusterName
    location: location
    tags: tags
    kubernetesVersion: kubernetesVersion
    nodeSubnetId: network!.outputs.nodeSubnetId
    controlPlaneIdentityId: identity!.outputs.id
    systemNodeVmSize: systemNodeVmSize
    systemNodeCount: systemNodeCount
    availabilityZones: availabilityZones
  }
}

var aksName = clusterTier == 'standard' ? aksStandard!.outputs.name : aksAutomatic!.outputs.name
var kubeletObjectId = clusterTier == 'standard' ? aksStandard!.outputs.kubeletObjectId : aksAutomatic!.outputs.kubeletObjectId

// -----------------------------------------------------------------------------
// Access
// -----------------------------------------------------------------------------

// Nodes pull images from ACR as the kubelet managed identity (AcrPull).
module acrPull 'modules/acr-pull.bicep' = {
  name: 'acr-pull'
  params: {
    acrName: acr.outputs.name
    kubeletObjectId: kubeletObjectId
  }
}

// You administer the cluster through Entra ID + Azure RBAC (local accounts are off).
module clusterRbac 'modules/cluster-rbac.bicep' = {
  name: 'cluster-rbac'
  params: {
    clusterName: aksName
    principalId: adminPrincipalId
    principalType: adminPrincipalType
  }
}

// -----------------------------------------------------------------------------
// Outputs (the deploy script saves these for the next steps)
// -----------------------------------------------------------------------------
output clusterName string = aksName
output acrName string = acr.outputs.name
output acrLoginServer string = acr.outputs.loginServer
