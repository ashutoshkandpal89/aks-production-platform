#!/usr/bin/env bash
# Confirms the Session 1 cluster is ready for Session 3. Changes nothing except requesting provider registration.
source "$(dirname "$0")/_common.sh"

echo "Cluster: $CLUSTER_NAME (resource group $RESOURCE_GROUP)"
echo "  SKU: $(cluster_sku)"
FAIL=0

if kubectl get ns >/dev/null 2>&1; then
  echo "  [ok]   kubectl can reach the cluster"
else
  echo "  [FAIL] kubectl cannot reach the cluster. Run: az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME && kubelogin convert-kubeconfig -l azurecli" >&2
  FAIL=1
fi

# The Azure Monitor metrics docs ask you to remove the aks-preview extension before enabling managed Prometheus.
if az extension show --name aks-preview >/dev/null 2>&1; then
  echo "  [warn] The aks-preview CLI extension is installed. The managed Prometheus docs say to remove it first:"
  echo "         az extension remove --name aks-preview"
fi

echo "Requesting resource provider registration (needed for Prometheus, Grafana, alerts, budgets)..."
for p in Microsoft.ContainerService Microsoft.Insights Microsoft.AlertsManagement Microsoft.Monitor Microsoft.Dashboard Microsoft.Consumption Microsoft.Chaos; do
  az provider register -n "$p" >/dev/null && echo "  [ok]   $p"
done
exit $FAIL
