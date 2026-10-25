// AKS Automatic - this is the whole cluster.
//
// Azure manages for you (defaults you do NOT have to configure):
//   - managed system node pools and Node Auto Provisioning (NAP) for your workloads
//   - Azure CNI Overlay with the Cilium data plane
//   - KEDA, Workload Identity, Entra ID + Azure RBAC, managed Prometheus
//   - Deployment Safeguards (policy that rejects risky manifests)
//   - automatic Kubernetes and node image upgrades
//
// You still own: workloads, resource requests, ingress routes, cost, and security posture.

param name string
param location string
param tags object

@description('Leave empty for the AKS default version.')
param kubernetesVersion string = ''

resource aks 'Microsoft.ContainerService/managedClusters@2026-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Automatic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: empty(kubernetesVersion) ? null : kubernetesVersion

    // Ingress with the Kubernetes Gateway API (application routing add-on, Istio-based).
    // Newer AKS Automatic versions enable this by default; setting it here keeps the
    // template independent of the Kubernetes version you land on.
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
