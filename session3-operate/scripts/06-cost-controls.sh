#!/usr/bin/env bash
# Read-only cost check: what is running, what you asked for, what you use, and what is idle.
source "$(dirname "$0")/_common.sh"

echo "== Nodes =="
kubectl get nodes -L node.kubernetes.io/instance-type,karpenter.sh/capacity-type,topology.kubernetes.io/zone || true

echo
echo "== What the cluster has reserved vs what is in use =="
kubectl top nodes 2>/dev/null || echo "  (metrics API not ready yet)"
echo
echo "== Requested CPU and memory per namespace (the number you pay for, not what is used) =="
kubectl get pods -A -o json | python3 -c '
import json, sys, collections
def cpu(v): return float(v[:-1])/1000 if v.endswith("m") else float(v)
def mem(v):
    for s, m in (("Ki",1/1024),("Mi",1),("Gi",1024)):
        if v.endswith(s): return float(v[:-2])*m
    return float(v)/1048576
tot = collections.defaultdict(lambda: [0.0, 0.0])
for p in json.load(sys.stdin)["items"]:
    ns = p["metadata"]["namespace"]
    for c in p["spec"]["containers"]:
        r = c.get("resources", {}).get("requests", {})
        tot[ns][0] += cpu(r.get("cpu", "0")); tot[ns][1] += mem(r.get("memory", "0"))
print("  %-24s%12s%14s" % ("namespace", "CPU (cores)", "Memory (MiB)"))
for ns, (c, m) in sorted(tot.items(), key=lambda kv: -kv[1][0]):
    print(f"  {ns:<24}{c:>12.2f}{m:>14.0f}")
'

echo
echo "== Likely leftovers (unattached disks and public IPs in $RESOURCE_GROUP and the node resource group) =="
NODE_RG="$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)"
for rg in "$RESOURCE_GROUP" "$NODE_RG"; do
  echo "  [$rg]"
  az disk list -g "$rg" --query "[?managedBy==null].{disk:name,sizeGb:diskSizeGb}" -o table 2>/dev/null || true
  az network public-ip list -g "$rg" --query "[?ipConfiguration==null].{ip:name}" -o table 2>/dev/null || true
done

echo
echo "== Budgets on this resource group =="
az consumption budget list --resource-group "$RESOURCE_GROUP" --query "[].{name:name, amount:amount, timeGrain:timeGrain}" -o table 2>/dev/null \
  || echo "  (none found, or the consumption command is not available in your CLI)"

cat <<'TXT'

Where to look next
  Cost analysis (portal): Cost Management, Cost analysis, group by Resource and by Tag.
  Right-sizing: compare requests above with real use in Grafana (container CPU and memory vs requests).
  Cheaper capacity: Spot for interruptible work (./08-optional-spot.sh), scale-to-zero with KEDA.
  Tags: add owner / environment tags to the resource group so cost can be split.
TXT
