#!/usr/bin/env bash
# Removes ONLY what Session 2 added (Key Vault, identities, Flux config, namespaces).
# To delete everything, including the Session 1 cluster, run ../../session1-foundation/scripts/99-teardown.sh
source "$(dirname "$0")/_common.sh"

echo "This removes the Session 2 resources from resource group $RESOURCE_GROUP."
read -r -p "Type 'yes' to continue: " OK
[[ "$OK" == "yes" ]] || { echo "Cancelled."; exit 1; }

echo "Removing Flux configuration..."
az k8s-configuration flux delete -g "$RESOURCE_GROUP" -c "$CLUSTER_NAME" -t managedClusters -n "$FLUX_CONFIG_NAME" --yes 2>/dev/null || echo "  (none found)"

echo "Removing namespaces..."
kubectl delete namespace "$NAMESPACE" "$GITOPS_NAMESPACE" --ignore-not-found --wait=false

echo "Removing role assignments, identities and Key Vault..."
for id in "id-${AKS_PREFIX}-secret-reader" "id-${AKS_PREFIX}-github-deploy"; do
  PID="$(az identity show -g "$RESOURCE_GROUP" -n "$id" --query principalId -o tsv 2>/dev/null || true)"
  if [[ -n "$PID" ]]; then
    az role assignment list --assignee "$PID" --all --query "[].id" -o tsv | xargs -r -n1 az role assignment delete --ids || true
    az identity delete -g "$RESOURCE_GROUP" -n "$id"
  fi
done
KV="$(az keyvault list -g "$RESOURCE_GROUP" --query "[?starts_with(name,'kv-${AKS_PREFIX}')].name | [0]" -o tsv 2>/dev/null || true)"
if [[ -n "$KV" ]]; then
  az keyvault delete -g "$RESOURCE_GROUP" -n "$KV"
  az keyvault purge -n "$KV" || true   # frees the name straight away
fi
rm -f "$S2_STATE"
echo "Done."
