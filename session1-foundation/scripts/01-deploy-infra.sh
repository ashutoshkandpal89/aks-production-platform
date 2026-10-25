#!/usr/bin/env bash
# Deploys the resource group, ACR and an AKS cluster with Bicep.
# Usage: ./01-deploy-infra.sh [automatic|standard]     (default: automatic)
source "$(dirname "$0")/_common.sh"

TIER="${1:-automatic}"
[[ "$TIER" == "automatic" || "$TIER" == "standard" ]] || { echo "Usage: $0 [automatic|standard]" >&2; exit 1; }

INFRA_DIR="$(cd "$(dirname "$0")/../infra" && pwd)"

echo "Looking up your Entra object ID (you become cluster admin)..."
ADMIN_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv)"
export ADMIN_OBJECT_ID

echo "Creating resource group $RESOURCE_GROUP in $LOCATION..."
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" -o none

echo "Deploying $TIER cluster (this takes about 5-15 minutes)..."
OUT="$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "s1-$TIER" \
  --parameters "$INFRA_DIR/main.$TIER.bicepparam" \
  --query properties.outputs -o json)"

CLUSTER_NAME="$(echo "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["clusterName"]["value"])')"
ACR_NAME="$(echo "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["acrName"]["value"])')"
ACR_LOGIN_SERVER="$(echo "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["acrLoginServer"]["value"])')"

cat > "$STATE_FILE" <<STATE
CLUSTER_NAME=$CLUSTER_NAME
ACR_NAME=$ACR_NAME
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
TIER=$TIER
STATE

echo "Getting kubectl credentials..."
az aks get-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --overwrite-existing
if command -v kubelogin >/dev/null; then
  kubelogin convert-kubeconfig -l azurecli
else
  echo "kubelogin not found. Install it (az aks install-cli), then run: kubelogin convert-kubeconfig -l azurecli" >&2
fi

echo
echo "Done. Cluster: $CLUSTER_NAME   Registry: $ACR_LOGIN_SERVER"
echo "Next: ./02-build-push-image.sh"
