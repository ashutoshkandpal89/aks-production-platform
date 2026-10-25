#!/usr/bin/env bash
# Checks your machine and subscription are ready. Safe to run any time (changes nothing except
# registering resource providers).
source "$(dirname "$0")/_common.sh"

ok()   { echo "  [ok]   $*"; }
warn() { echo "  [warn] $*"; }
fail() { echo "  [FAIL] $*"; FAILED=1; }
FAILED=0

echo "Tools"
for t in az kubectl; do
  command -v "$t" >/dev/null && ok "$t found" || fail "$t not found - install it first"
done
command -v kubelogin >/dev/null && ok "kubelogin found" || warn "kubelogin missing (needed for Entra sign-in): see \"Installing kubectl and kubelogin\" in the root README"
command -v docker >/dev/null && ok "docker found (optional; only needed if ACR Tasks is blocked)" || warn "docker not found (optional)"

echo "Azure login"
if az account show >/dev/null 2>&1; then
  ok "signed in to: $(az account show --query name -o tsv)"
else
  fail "not signed in - run: az login"
fi

if [[ $FAILED -eq 0 ]]; then
  echo "Resource providers (registering if needed)"
  for rp in Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.Network \
            Microsoft.Compute Microsoft.ManagedIdentity Microsoft.PolicyInsights \
            Microsoft.OperationsManagement Microsoft.Insights; do
    state=$(az provider show -n "$rp" --query registrationState -o tsv 2>/dev/null || echo "NotRegistered")
    if [[ "$state" != "Registered" ]]; then
      az provider register -n "$rp" >/dev/null && warn "$rp was $state - registration started (can take a few minutes)"
    else
      ok "$rp registered"
    fi
  done
  echo "Azure CLI version: $(az version --query '"azure-cli"' -o tsv)  (2.86.0 or newer recommended)"
  echo "Tip: check vCPU quota for your region: az vm list-usage -l $LOCATION -o table | grep -i 'DSv5\|Total Regional'"
fi
exit $FAILED