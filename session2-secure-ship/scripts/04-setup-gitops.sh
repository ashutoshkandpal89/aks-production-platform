#!/usr/bin/env bash
# Installs Flux (as an AKS extension) and points it at gitops/apps/secure-app in YOUR repo.
# Required: your repo must be PUBLIC (no credentials are used) and the code must be pushed.
#   export GITOPS_REPO_URL=https://github.com/<you>/<repo>
source "$(dirname "$0")/_common.sh"

: "${GITOPS_REPO_URL:?Set GITOPS_REPO_URL, for example: export GITOPS_REPO_URL=https://github.com/my-user/aks-production-platform}"
GITOPS_BRANCH="${GITOPS_BRANCH:-main}"
GITOPS_PATH="${GITOPS_PATH:-./session2-secure-ship/gitops/apps/secure-app}"

echo "Registering providers..."
az provider register -n Microsoft.KubernetesConfiguration --wait

echo "Installing Flux and the configuration (a few minutes)..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name s2-flux \
  --template-file "$S2_DIR/infra/modules/flux.bicep" \
  --parameters clusterName="$CLUSTER_NAME" gitRepoUrl="$GITOPS_REPO_URL" \
               gitBranch="$GITOPS_BRANCH" gitopsPath="$GITOPS_PATH" -o none

echo "Waiting for Flux to deploy the app from Git..."
for _ in $(seq 1 30); do
  if kubectl -n "$GITOPS_NAMESPACE" get deployment hello >/dev/null 2>&1; then break; fi
  sleep 10
done
kubectl -n "$GITOPS_NAMESPACE" rollout status deployment/hello --timeout=5m

cat <<MSG

Flux deployed 'hello' from Git. Now try the drift demo:

  kubectl -n $GITOPS_NAMESPACE get deployment hello          # 2 replicas, as in Git
  kubectl -n $GITOPS_NAMESPACE scale deployment/hello --replicas=5
  kubectl -n $GITOPS_NAMESPACE get deployment hello -w       # Flux puts it back to 2

Then change 'replicas' in gitops/apps/secure-app/deployment.yaml, commit and push:
the cluster follows within a couple of minutes. No kubectl needed.
MSG
