#!/usr/bin/env bash
# Creates the Azure Monitor workspace, Managed Grafana, alert rules and a budget,
# then connects the cluster so it ships Prometheus metrics.
# Usage: ALERT_EMAIL=you@example.com ./01-deploy-monitoring.sh
source "$(dirname "$0")/_common.sh"
: "${ALERT_EMAIL:?Set ALERT_EMAIL, for example: ALERT_EMAIL=you@example.com ./01-deploy-monitoring.sh}"

export ADMIN_OBJECT_ID="${ADMIN_OBJECT_ID:-$(az ad signed-in-user show --query id -o tsv)}"
export ALERT_EMAIL BUDGET_AMOUNT="${BUDGET_AMOUNT:-100}"

echo "Deploying monitoring resources (takes a few minutes)..."
az deployment group create -g "$RESOURCE_GROUP" -n "s3-monitoring" \
  -f "$S3_DIR/infra/main.bicep" -p "$S3_DIR/infra/main.bicepparam" \
  --query "properties.outputs" -o json > "$S3_DIR/scripts/.outputs.json"

WORKSPACE_ID="$(python3 -c "import json;print(json.load(open('$S3_DIR/scripts/.outputs.json'))['monitorWorkspaceId']['value'])")"
GRAFANA_ID="$(python3 -c "import json;print(json.load(open('$S3_DIR/scripts/.outputs.json'))['grafanaId']['value'])")"
GRAFANA_URL="$(python3 -c "import json;print(json.load(open('$S3_DIR/scripts/.outputs.json'))['grafanaUrl']['value'])")"
rm -f "$S3_DIR/scripts/.outputs.json"
save_state MONITOR_WORKSPACE_ID "$WORKSPACE_ID"
save_state GRAFANA_ID "$GRAFANA_ID"
save_state GRAFANA_URL "$GRAFANA_URL"

echo "Connecting the cluster to Managed Prometheus and Grafana..."
az aks update -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
  --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id "$WORKSPACE_ID" \
  --grafana-resource-id "$GRAFANA_ID"

echo "Turning on AKS control plane metrics (API server, etcd)..."
az aks update -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --enable-control-plane-metrics || \
  echo "  (control plane metrics not enabled; this is optional)"

echo
echo "Done. Grafana: $GRAFANA_URL"
echo "In Grafana open Dashboards, then Azure Managed Prometheus, to find the Kubernetes dashboards."
echo "Check the agent pods:  kubectl get pods -n kube-system | grep ama-metrics"
echo "Next: ./02-deploy-app.sh"
