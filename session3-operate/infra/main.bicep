// =============================================================================
// Session 3 - Operating AKS: Observability, Resilience and Cost
//
// Adds to the Session 1 cluster:
//   1. Azure Monitor workspace  (stores Prometheus metrics)
//   2. Azure Managed Grafana    (dashboards)
//   3. An action group + Prometheus alert rules (error rate, crash loops, not-ready nodes)
//   4. A monthly budget on the resource group
//
// The cluster itself is connected to the workspace and Grafana by the script
// ../scripts/01-deploy-monitoring.sh (az aks update --enable-azure-monitor-metrics).
// =============================================================================

targetScope = 'resourceGroup'

@description('Short prefix used in names. Letters and digits only.')
@minLength(3)
@maxLength(12)
param prefix string = 'aksprod'

param location string = resourceGroup().location

@description('Name of the existing AKS cluster from Session 1.')
param clusterName string

@description('Object ID of the person who should be Grafana Admin: az ad signed-in-user show --query id -o tsv')
param adminPrincipalId string

@description('Email address that receives alerts and budget notices.')
param alertEmail string

@description('Monthly budget for this resource group, in your billing currency.')
param budgetAmount int = 100

@description('First day of the month the budget starts. Must be the first day of a month.')
param budgetStartDate string = utcNow('yyyy-MM-01')

param tags object = {
  workload: 'aks-production-platform'
  session: '3'
  purpose: 'training'
}

var monitorWorkspaceName = 'amw-${prefix}'
var grafanaName = 'amg-${prefix}-${take(uniqueString(resourceGroup().id), 5)}'

// Built-in role IDs
var grafanaAdminRoleId = '22926164-76b3-42b3-bc55-97df8dab3e41' // Grafana Admin
var monitoringDataReaderRoleId = 'b0d8363b-8ddd-447d-831f-62ca05bff136' // Monitoring Data Reader

resource cluster 'Microsoft.ContainerService/managedClusters@2026-04-01' existing = {
  name: clusterName
}

// --- 1. Azure Monitor workspace ---------------------------------------------
resource monitorWorkspace 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: monitorWorkspaceName
  location: location
  tags: tags
}

// --- 2. Managed Grafana ------------------------------------------------------
resource grafana 'Microsoft.Dashboard/grafana@2023-09-01' = {
  name: grafanaName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
    grafanaIntegrations: {
      azureMonitorWorkspaceIntegrations: [
        {
          azureMonitorWorkspaceResourceId: monitorWorkspace.id
        }
      ]
    }
  }
}

// Grafana reads Prometheus data with its own identity
resource grafanaReadsMetrics 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(monitorWorkspace.id, grafana.id, monitoringDataReaderRoleId)
  scope: monitorWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringDataReaderRoleId)
    principalId: grafana.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// You can sign in to Grafana as admin
resource grafanaAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(grafana.id, adminPrincipalId, grafanaAdminRoleId)
  scope: grafana
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', grafanaAdminRoleId)
    principalId: adminPrincipalId
    principalType: 'User'
  }
}

// --- 3. Alerting --------------------------------------------------------------
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${prefix}-ops'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: take('${prefix}ops', 12)
    enabled: true
    emailReceivers: [
      {
        name: 'oncall'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource alertRules 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: 'rg-${prefix}-alerts'
  location: location
  tags: tags
  properties: {
    description: 'Session 3 demo alerts: what you would want to be paged for.'
    scopes: [
      monitorWorkspace.id
      cluster.id
    ]
    clusterName: clusterName
    interval: 'PT1M'
    enabled: true
    rules: [
      {
        alert: 'DemoAppHighErrorRate'
        enabled: true
        expression: 'sum(rate(demo_http_requests_total{code=~"5.."}[5m])) / sum(rate(demo_http_requests_total[5m])) > 0.05'
        for: 'PT5M'
        severity: 2
        labels: {
          team: 'platform'
        }
        annotations: {
          summary: 'More than 5 percent of requests to the demo app are failing.'
        }
        actions: [
          {
            actionGroupId: actionGroup.id
          }
        ]
      }
      {
        alert: 'PodCrashLooping'
        enabled: true
        expression: 'increase(kube_pod_container_status_restarts_total[15m]) > 3'
        for: 'PT5M'
        severity: 2
        actions: [
          {
            actionGroupId: actionGroup.id
          }
        ]
      }
      {
        alert: 'NodeNotReady'
        enabled: true
        expression: 'kube_node_status_condition{condition="Ready",status="true"} == 0'
        for: 'PT10M'
        severity: 1
        actions: [
          {
            actionGroupId: actionGroup.id
          }
        ]
      }
    ]
  }
}

// --- 4. Budget -----------------------------------------------------------------
resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: 'budget-${prefix}-monthly'
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      actual80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [
          alertEmail
        ]
      }
      forecast100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [
          alertEmail
        ]
      }
    }
  }
}

output monitorWorkspaceId string = monitorWorkspace.id
output grafanaId string = grafana.id
output grafanaName string = grafana.name
output grafanaUrl string = grafana.properties.endpoint
