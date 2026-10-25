#!/usr/bin/env bash
# Removes ONLY what Session 3 added (app, monitoring resources, budget, optional chaos and spot pieces).
# To delete everything, including the Session 1 cluster, run ../../session1-foundation/scripts/99-teardown.sh
source "$(dirname "$0")/_common.sh"

echo "This removes the Session 3 resources from resource group $RESOURCE_GROUP."
read -r -p "Type 'yes' to continue: " OK
[[ "$OK" == "yes" ]] || { echo "Cancelled."; exit 1; }

echo "Removing app and spot pieces..."
kubectl delete -f "$S3_DIR/k8s/optional/batch-on-spot.yaml" --ignore-not-found 2>/dev/null || true
kubectl delete -f "$S3_DIR/k8s/optional/nodepool-spot.yaml" --ignore-not-found 2>/dev/null || true
kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait=false
az aks nodepool delete -g "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" -n spot1 2>/dev/null || true

if command -v helm >/dev/null && helm status chaos-mesh -n chaos-testing >/dev/null 2>&1; then
  echo "Removing Chaos Mesh..."
  helm uninstall chaos-mesh -n chaos-testing || true
  kubectl delete namespace chaos-testing --ignore-not-found --wait=false
fi
EXP="$(get_state CHAOS_EXPERIMENT)"
if [[ -n "$EXP" ]]; then
  SUB="$(az account show --query id -o tsv)"
  echo "Removing Chaos Studio experiment $EXP..."
  az rest --method delete --uri "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/$EXP?api-version=2023-11-01" || true
fi

echo "Turning off managed Prometheus on the cluster..."
az aks update -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --disable-azure-monitor-metrics --yes || true

echo "Deleting alert rules, action group, Grafana, workspace and budget..."
az resource delete -g "$RESOURCE_GROUP" --resource-type Microsoft.AlertsManagement/prometheusRuleGroups -n "rg-${AKS_PREFIX}-alerts" || true
az monitor action-group delete -g "$RESOURCE_GROUP" -n "ag-${AKS_PREFIX}-ops" || true
GRAFANA_NAME="$(az resource list -g "$RESOURCE_GROUP" --resource-type Microsoft.Dashboard/grafana --query "[?starts_with(name,'amg-${AKS_PREFIX}')].name | [0]" -o tsv 2>/dev/null || true)"
[[ -n "$GRAFANA_NAME" ]] && az resource delete -g "$RESOURCE_GROUP" --resource-type Microsoft.Dashboard/grafana -n "$GRAFANA_NAME" || true
az resource delete -g "$RESOURCE_GROUP" --resource-type Microsoft.Monitor/accounts -n "amw-${AKS_PREFIX}" || true
az consumption budget delete --resource-group "$RESOURCE_GROUP" --budget-name "budget-${AKS_PREFIX}-monthly" 2>/dev/null || true

echo
echo "Data collection rules and endpoints created by the Prometheus setup (names start with MSProm-) may remain:"
az monitor data-collection rule list -g "$RESOURCE_GROUP" --query "[?starts_with(name,'MSProm-')].name" -o tsv 2>/dev/null || true
az monitor data-collection endpoint list -g "$RESOURCE_GROUP" --query "[?starts_with(name,'MSProm-')].name" -o tsv 2>/dev/null || true
echo "Delete them in the portal if you do not need them. Everything is removed if you delete the whole resource group."
rm -f "$S3_STATE"
echo "Done."
