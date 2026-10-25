#!/usr/bin/env bash
# Shared settings for Session 2. It reuses the cluster you created in Session 1.
set -euo pipefail

S2_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S1_STATE="$S2_DIR/../session1-foundation/scripts/.state.env"
S2_STATE="$S2_DIR/scripts/.state.env"

export AKS_PREFIX="${AKS_PREFIX:-aksprod}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-rg-${AKS_PREFIX}-s1}"
export NAMESPACE="secure-demo"
export GITOPS_NAMESPACE="gitops-demo"
export FLUX_CONFIG_NAME="secure-demo"

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
  touch "$S2_STATE"
  grep -v "^$1=" "$S2_STATE" > "$S2_STATE.tmp" || true
  echo "$1=$2" >> "$S2_STATE.tmp"
  mv "$S2_STATE.tmp" "$S2_STATE"
}

load_s2_state() {
  [[ -f "$S2_STATE" ]] || { echo "No Session 2 state found. Run ./01-deploy-identity.sh first." >&2; exit 1; }
  # shellcheck disable=SC1090
  source "$S2_STATE"
}

get_state() { grep "^$1=" "$S2_STATE" | tail -1 | cut -d= -f2-; }
