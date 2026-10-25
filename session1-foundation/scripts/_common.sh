#!/usr/bin/env bash
# Shared settings. Override any of these by exporting them before you run a script.
set -euo pipefail

export AKS_PREFIX="${AKS_PREFIX:-aksprod}"          # 3-12 letters/digits
export LOCATION="${LOCATION:-eastus2}"              # pick a region where AKS Automatic is available
export RESOURCE_GROUP="${RESOURCE_GROUP:-rg-${AKS_PREFIX}-s1}"

STATE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.state.env"

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  else
    echo "No deployment found. Run ./01-deploy-infra.sh first." >&2
    exit 1
  fi
}
