#!/usr/bin/env bash
# Shared settings for Session 3. It reuses the cluster you created in Session 1.
set -euo pipefail

S3_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S1_STATE="$S3_DIR/../session1-foundation/scripts/.state.env"
S3_STATE="$S3_DIR/scripts/.state.env"

export AKS_PREFIX="${AKS_PREFIX:-aksprod}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-rg-${AKS_PREFIX}-s1}"
export NAMESPACE="ops-demo"

# Session 1 wrote CLUSTER_NAME, ACR_NAME and ACR_LOGIN_SERVER here.
# No Session 1 state? Export CLUSTER_NAME, ACR_NAME and ACR_LOGIN_SERVER yourself.
if [[ -f "$S1_STATE" ]]; then
  # shellcheck disable=SC1090
  source "$S1_STATE"
fi
: "${CLUSTER_NAME:?CLUSTER_NAME is not set. Finish Session 1 first, or export CLUSTER_NAME, ACR_NAME and ACR_LOGIN_SERVER.}"
: "${ACR_NAME:?ACR_NAME is not set.}"
: "${ACR_LOGIN_SERVER:=${ACR_NAME}.azurecr.io}"
export CLUSTER_NAME ACR_NAME ACR_LOGIN_SERVER

save_state() { # save_state KEY VALUE  (replaces an existing KEY)
  touch "$S3_STATE"
  grep -v "^$1=" "$S3_STATE" > "$S3_STATE.tmp" || true
  echo "$1=$2" >> "$S3_STATE.tmp"
  mv "$S3_STATE.tmp" "$S3_STATE"
}

get_state() { [[ -f "$S3_STATE" ]] && grep "^$1=" "$S3_STATE" | tail -1 | cut -d= -f2- || true; }

cluster_sku() { az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query sku.name -o tsv; }
