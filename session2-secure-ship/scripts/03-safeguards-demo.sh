#!/usr/bin/env bash
# Shows Deployment Safeguards blocking unsafe pods.
#   AKS Automatic: safeguards are already on (Enforce).
#   AKS Standard:  this script turns them on first (Azure Policy add-on + safeguards).
source "$(dirname "$0")/_common.sh"

SKU="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query sku.name -o tsv)"

if [[ "$SKU" != "Automatic" ]]; then
  echo "Standard cluster: enabling the Azure Policy add-on and Deployment Safeguards (Enforce)..."
  az aks enable-addons -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --addons azure-policy -o none
  if ! az aks safeguards create -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --level Enforce -o none; then
    echo "'az aks safeguards' failed. You may need the preview extension: az extension add --name aks-preview" >&2
    exit 1
  fi
  echo "Safeguards can take 5 to 15 minutes to reach the cluster. If the pods below are NOT denied, wait and run this script again."
else
  echo "Automatic cluster: Deployment Safeguards are already enforced."
fi

try_apply() {
  echo
  echo "=== kubectl apply -f $1 ==="
  if kubectl apply -f "$S2_DIR/k8s/bad/$1"; then
    echo ">>> NOT blocked. The pod was created."
  else
    echo ">>> Blocked, as intended."
  fi
}

try_apply privileged-pod.yaml
try_apply latest-tag.yaml

echo
echo "Cleaning up anything that slipped through..."
kubectl delete -f "$S2_DIR/k8s/bad/" --ignore-not-found
echo "Done. Read the error text above: it names the policy that denied each pod."
