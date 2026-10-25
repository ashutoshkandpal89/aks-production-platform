#!/usr/bin/env bash
# OPTIONAL. Runs a managed pod-kill experiment with Azure Chaos Studio (Chaos Mesh fault).
# Read chaos/README.md first. Needs: helm, a cluster that allows Chaos Mesh, and the right to assign roles.
# AKS Automatic's safeguards may block Chaos Mesh (its daemon needs elevated rights). Try on a Standard cluster.
source "$(dirname "$0")/_common.sh"
command -v helm >/dev/null || { echo "helm not found. Install helm first." >&2; exit 1; }

if [[ "$(cluster_sku)" == "Automatic" && "${FORCE:-0}" != "1" ]]; then
  echo "This cluster is AKS Automatic. Chaos Mesh may be blocked by safeguards, and Chaos Studio's AKS faults"
  echo "may not work with every Automatic setup. Run with FORCE=1 to try anyway, or use ./04-resilience-drill.sh." >&2
  exit 1
fi

SUB="$(az account show --query id -o tsv)"
LOCATION="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query location -o tsv)"
CLUSTER_ID="/subscriptions/$SUB/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME"
EXPERIMENT="chaos-${AKS_PREFIX}-podkill"
CAP_VERSION="${CAP_VERSION:-2.2}"     # confirm in the Chaos Studio fault library
API_TARGET="2024-01-01"

echo "1/5 Installing Chaos Mesh with Helm..."
helm repo add chaos-mesh https://charts.chaos-mesh.org >/dev/null
helm repo update >/dev/null
kubectl get ns chaos-testing >/dev/null 2>&1 || kubectl create ns chaos-testing
helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh -n chaos-testing \
  --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock
kubectl -n chaos-testing rollout status deploy/chaos-controller-manager --timeout=5m

echo "2/5 Enabling the Chaos Studio target and capability..."
TARGET_URL="https://management.azure.com${CLUSTER_ID}/providers/Microsoft.Chaos/targets/Microsoft-AzureKubernetesServiceChaosMesh"
az rest --method put --url "${TARGET_URL}?api-version=${API_TARGET}" --body '{"properties":{}}' >/dev/null
az rest --method put --url "${TARGET_URL}/capabilities/PodChaos-${CAP_VERSION}?api-version=${API_TARGET}" --body '{"properties":{}}' >/dev/null

echo "3/5 Creating the experiment..."
BODY="$(mktemp)"
sed -e "s|__LOCATION__|$LOCATION|g" -e "s|__TARGET_ID__|${CLUSTER_ID}/providers/Microsoft.Chaos/targets/Microsoft-AzureKubernetesServiceChaosMesh|g" \
    -e "s|__CAP_VERSION__|$CAP_VERSION|g" "$S3_DIR/chaos/experiment-podkill.json.template" > "$BODY"
az rest --method put \
  --uri "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/$EXPERIMENT?api-version=2023-11-01" \
  --body @"$BODY" >/dev/null
rm -f "$BODY"

echo "4/5 Giving the experiment's identity access to the cluster (lab only: this is a powerful role)..."
PRINCIPAL="$(az rest --method get --uri "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/$EXPERIMENT?api-version=2024-01-01" --query identity.principalId -o tsv)"
for role in "Azure Kubernetes Service RBAC Cluster Admin" "Azure Kubernetes Service Cluster User Role"; do
  az role assignment create --role "$role" --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal --scope "$CLUSTER_ID" >/dev/null
done
save_state CHAOS_EXPERIMENT "$EXPERIMENT"

echo "5/5 Starting the experiment (it kills one ops-demo pod)..."
sleep 30   # let the role assignments propagate
az rest --method post --uri "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/$EXPERIMENT/start?api-version=2024-01-01"
echo
echo "Watch:  kubectl -n $NAMESPACE get pods -w      and the Chaos Studio experiment in the portal."
