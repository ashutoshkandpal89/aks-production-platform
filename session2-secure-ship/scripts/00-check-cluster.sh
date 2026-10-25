#!/usr/bin/env bash
# Confirms the Session 1 cluster is ready for Session 2. Changes nothing.
source "$(dirname "$0")/_common.sh"

echo "Cluster: $CLUSTER_NAME (resource group $RESOURCE_GROUP)"
SKU="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query sku.name -o tsv)"
OIDC="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query oidcIssuerProfile.issuerUrl -o tsv)"
WI="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query securityProfile.workloadIdentity.enabled -o tsv)"

echo "  SKU:                  $SKU  (Automatic = safeguards on by default)"
echo "  OIDC issuer:          ${OIDC:-NOT ENABLED}"
echo "  Workload identity:    ${WI:-not reported}"

FAIL=0
[[ -n "$OIDC" ]] || { echo "  [FAIL] OIDC issuer is off. Workload identity cannot work without it." >&2; FAIL=1; }
if kubectl get ns >/dev/null 2>&1; then
  echo "  [ok]   kubectl can reach the cluster"
else
  echo "  [FAIL] kubectl cannot reach the cluster. Run: az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME && kubelogin convert-kubeconfig -l azurecli" >&2
  FAIL=1
fi
az provider register -n Microsoft.KubernetesConfiguration >/dev/null && echo "  [ok]   Microsoft.KubernetesConfiguration registration requested (needed for Flux)"
az provider register -n Microsoft.KeyVault >/dev/null && echo "  [ok]   Microsoft.KeyVault registration requested"
exit $FAIL
