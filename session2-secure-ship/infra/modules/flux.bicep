// GitOps with Flux, installed as an AKS extension, plus one configuration that keeps the
// cluster in sync with a path in your Git repository.
//
//   Change in Git  ->  Flux pulls it  ->  cluster reconciles
//   Change on the cluster by hand  ->  Flux reverts it (prune + drift correction)

param clusterName string
param gitRepoUrl string
param gitBranch string
param gitopsPath string

@description('Namespace for the Flux controllers and configuration objects.')
param fluxNamespace string = 'flux-system'

resource aks 'Microsoft.ContainerService/managedClusters@2026-04-01' existing = {
  name: clusterName
}

resource fluxExtension 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = {
  name: 'flux'
  scope: aks
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
  }
}

resource fluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2024-11-01' = {
  name: 'secure-demo'
  scope: aks
  dependsOn: [
    fluxExtension
  ]
  properties: {
    scope: 'cluster'
    namespace: fluxNamespace
    sourceKind: 'GitRepository'
    suspend: false
    gitRepository: {
      url: gitRepoUrl
      timeoutInSeconds: 600
      syncIntervalInSeconds: 60
      repositoryRef: {
        branch: gitBranch
      }
    }
    kustomizations: {
      apps: {
        path: gitopsPath
        timeoutInSeconds: 600
        syncIntervalInSeconds: 60
        prune: true // delete from the cluster what you delete from Git
        force: false
      }
    }
  }
}
