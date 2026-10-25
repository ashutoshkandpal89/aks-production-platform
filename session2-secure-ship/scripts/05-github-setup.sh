#!/usr/bin/env bash
# Prints (and, if the GitHub CLI is signed in, sets) the repository VARIABLES the pipeline needs.
# These are identifiers, not secrets. That is the point of OIDC: there is no secret to store.
source "$(dirname "$0")/_common.sh"
load_s2_state

OWNER="${GITHUB_OWNER:-$(get_state GITHUB_OWNER)}"
REPO="${GITHUB_REPO:-$(get_state GITHUB_REPO)}"
SUB_ID="$(az account show --query id -o tsv)"

declare -A VARS=(
  [AZURE_CLIENT_ID]="$GH_CLIENT_ID"
  [AZURE_TENANT_ID]="$TENANT_ID"
  [AZURE_SUBSCRIPTION_ID]="$SUB_ID"
  [RESOURCE_GROUP]="$RESOURCE_GROUP"
  [CLUSTER_NAME]="$CLUSTER_NAME"
  [ACR_NAME]="$ACR_NAME"
  [WI_CLIENT_ID]="$WI_CLIENT_ID"
  [KEYVAULT_URI]="$KEYVAULT_URI"
)

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  echo "Setting repository variables on $OWNER/$REPO with the GitHub CLI..."
  for k in "${!VARS[@]}"; do gh variable set "$k" --body "${VARS[$k]}" -R "$OWNER/$REPO"; done
  echo "Done. Run the workflow: GitHub > Actions > 'Session 2 - build, scan and deploy' > Run workflow"
else
  echo "Add these as repository VARIABLES (Settings > Secrets and variables > Actions > Variables):"
  echo
  for k in "${!VARS[@]}"; do printf '  %-24s %s\n' "$k" "${VARS[$k]}"; done | sort
  echo
  echo "Then run: GitHub > Actions > 'Session 2 - build, scan and deploy' > Run workflow"
fi
