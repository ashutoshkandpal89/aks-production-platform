// Azure Container Registry.
// Admin user is OFF (anonymous pull is off by default): access is only through Entra ID / managed identity.

param name string
param location string
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

output name string = acr.name
output loginServer string = acr.properties.loginServer
