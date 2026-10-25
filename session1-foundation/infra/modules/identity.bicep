// User-assigned managed identity for the AKS control plane (Standard path).
// Created first so it can be granted rights on the VNet BEFORE the cluster exists.

param name string
param location string
param tags object

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output id string = identity.id
output principalId string = identity.properties.principalId
