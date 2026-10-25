// AKS Standard - the same outcome as Automatic, but every choice below is YOURS to make
// and YOURS to keep correct. Read it next to aks-automatic.bicep.

param name string
param location string
param tags object

@description('Leave empty for the AKS default version.')
param kubernetesVersion string = ''

@description('Resource ID of the subnet that hosts the nodes.')
param nodeSubnetId string

@description('Resource ID of the user-assigned managed identity used by the control plane.')
param controlPlaneIdentityId string

param systemNodeVmSize string
param systemNodeCount int
param availabilityZones array

resource aks 'Microsoft.ContainerService/managedClusters@2026-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Standard' // paid tier = financially backed uptime SLA
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${controlPlaneIdentityId}': {}
    }
  }
  properties: {
    dnsPrefix: name
    kubernetesVersion: empty(kubernetesVersion) ? null : kubernetesVersion
    enableRBAC: true

    // Identity: Entra ID sign-in, Azure RBAC for Kubernetes authorization, no shared admin kubeconfig.
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      tenantID: tenant().tenantId
    }

    // System pool: runs cluster add-ons only (CriticalAddonsOnly taint).
    // Your workloads land on nodes created by Node Auto Provisioning.
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        osType: 'Linux'
        count: systemNodeCount
        vmSize: systemNodeVmSize
        vnetSubnetID: nodeSubnetId
        availabilityZones: availabilityZones
        enableAutoScaling: false
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
    ]

    // Networking: Azure CNI Overlay + Cilium.
    // Pods get IPs from podCidr (not from your VNet), so the node subnet stays small
    // and you cannot exhaust VNet addresses by scaling pods.
    // The three CIDRs below must not overlap each other or any network you peer with.
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkDataplane: 'cilium'
      networkPolicy: 'cilium'
      podCidr: '192.168.0.0/16'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }

    // Autoscaling: Node Auto Provisioning adds and removes VMs to fit pending pods;
    // KEDA scales pods from events and metrics.
    nodeProvisioningProfile: {
      mode: 'Auto'
    }
    workloadAutoScalerProfile: {
      keda: {
        enabled: true
      }
    }

    // Prepare for Session 2 (Workload Identity needs both of these).
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    // Ingress with the Kubernetes Gateway API (application routing add-on, Istio-based).
    ingressProfile: {
      gatewayAPI: {
        installation: 'Standard'
      }
      webAppRouting: {
        gatewayAPIImplementations: {
          appRoutingIstio: {
            mode: 'Enabled'
          }
        }
      }
    }
  }
}

output name string = aks.name
output kubeletObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
