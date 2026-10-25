using './main.bicep'

// Values come from environment variables set by scripts/01-deploy-monitoring.sh
param prefix = readEnvironmentVariable('AKS_PREFIX', 'aksprod')
param clusterName = readEnvironmentVariable('CLUSTER_NAME')
param adminPrincipalId = readEnvironmentVariable('ADMIN_OBJECT_ID')
param alertEmail = readEnvironmentVariable('ALERT_EMAIL')
param budgetAmount = int(readEnvironmentVariable('BUDGET_AMOUNT', '100'))
