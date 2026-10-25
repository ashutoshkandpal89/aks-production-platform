#!/usr/bin/env bash
# Creates Key Vault, the workload identity, and the GitHub deploy identity with Bicep.
# Then: creates the namespace, gives the GitHub identity rights in THAT namespace only,
# and stores a demo secret in Key Vault.
#
# Required:  export GITHUB_OWNER=<your github user or org>   GITHUB_REPO=<your repo name>
source "$(dirname "$0")/_common.sh"

: "${GITHUB_OWNER:?Set GITHUB_OWNER, for example: export GITHUB_OWNER=my-user}"
: "${GITHUB_REPO:?Set GITHUB_REPO, for example: export GITHUB_REPO=aks-production-platform}"
export GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

echo "Reading cluster details..."
OIDC_ISSUER_URL="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query oidcIssuerProfile.issuerUrl -o tsv)"
[[ -n "$OIDC_ISSUER_URL" ]] || { echo "The cluster has no OIDC issuer. Run ./00-check-cluster.sh" >&2; exit 1; }
AKS_ID="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query id -o tsv)"
ADMIN_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv)"
export OIDC_ISSUER_URL ADMIN_OBJECT_ID CLUSTER_NAME ACR_NAME

echo "Deploying identities and Key Vault (a few minutes)..."
OUT="$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name s2-identity \
  --parameters "$S2_DIR/infra/main.bicepparam" \
  --query properties.outputs -o json)"

out() { echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['$1']['value'])"; }
KEYVAULT_NAME="$(out keyVaultName)"
KEYVAULT_URI="$(out keyVaultUri)"
WI_CLIENT_ID="$(out workloadIdentityClientId)"
GH_CLIENT_ID="$(out githubIdentityClientId)"
GH_PRINCIPAL_ID="$(out githubIdentityPrincipalId)"
TENANT_ID="$(out tenantId)"

for kv in KEYVAULT_NAME KEYVAULT_URI WI_CLIENT_ID GH_CLIENT_ID GH_PRINCIPAL_ID TENANT_ID; do
  save_state "$kv" "${!kv}"
done
save_state GITHUB_OWNER "$GITHUB_OWNER"
save_state GITHUB_REPO "$GITHUB_REPO"

echo "Creating namespace $NAMESPACE..."
kubectl apply -f "$S2_DIR/k8s/namespace.yaml"

echo "Letting the GitHub identity write to namespace $NAMESPACE only (not the whole cluster)..."
az role assignment create \
  --assignee-object-id "$GH_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Azure Kubernetes Service RBAC Writer" \
  --scope "$AKS_ID/namespaces/$NAMESPACE" -o none

echo "Storing a demo secret in Key Vault (role assignments can take a few minutes to propagate)..."
for attempt in $(seq 1 12); do
  if az keyvault secret set --vault-name "$KEYVAULT_NAME" --name demo-secret \
       --value "hello-from-key-vault" -o none 2>/dev/null; then
    echo "  secret stored."
    break
  fi
  [[ $attempt -eq 12 ]] && { echo "Could not write the secret. Wait a few minutes and re-run this script." >&2; exit 1; }
  echo "  waiting for permissions (attempt $attempt of 12)..."; sleep 20
done

echo
echo "Done. Key Vault: $KEYVAULT_NAME"
echo "Next: ./02-deploy-secret-reader.sh"
