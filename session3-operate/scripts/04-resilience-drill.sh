#!/usr/bin/env bash
# A small game day using plain kubectl (works on Automatic and Standard):
#   1. Kill a pod        -> the Deployment replaces it, the app stays up
#   2. Drain a node      -> the PodDisruptionBudget limits how many pods leave at once
# Run ./03-generate-traffic.sh in another terminal and watch the Grafana dashboard while this runs.
source "$(dirname "$0")/_common.sh"

ready() { kubectl -n "$NAMESPACE" get deploy ops-demo -o jsonpath='{.status.readyReplicas}/{.spec.replicas}'; }
watch_ready() { # watch_ready SECONDS
  local end=$((SECONDS + $1))
  while (( SECONDS < end )); do echo "  $(date +%T)  ready replicas: $(ready)"; sleep 2; done
}

echo "== Baseline =="
kubectl -n "$NAMESPACE" get pods -o wide
echo "  ready replicas: $(ready)"

echo
echo "== Drill 1: delete one pod =="
VICTIM="$(kubectl -n "$NAMESPACE" get pods -l app=ops-demo -o jsonpath='{.items[0].metadata.name}')"
echo "Deleting $VICTIM"
kubectl -n "$NAMESPACE" delete pod "$VICTIM" --wait=false
watch_ready 30

echo
echo "== Drill 2: drain a node that runs an ops-demo pod =="
NODE="$(kubectl -n "$NAMESPACE" get pods -l app=ops-demo -o jsonpath='{.items[0].spec.nodeName}')"
echo "Chosen node: $NODE (other workloads on it will also be moved)"
read -r -p "Type 'yes' to cordon and drain $NODE: " OK
if [[ "$OK" == "yes" ]]; then
  kubectl cordon "$NODE"
  # Evictions respect the PodDisruptionBudget: you will see the app stay at 2/3 or better.
  kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=5m &
  DRAIN_PID=$!
  while kill -0 "$DRAIN_PID" 2>/dev/null; do echo "  $(date +%T)  ready replicas: $(ready)"; sleep 2; done
  wait "$DRAIN_PID" || echo "Drain did not finish. Check: kubectl -n $NAMESPACE get pdb"
  echo "Putting the node back..."
  kubectl uncordon "$NODE"
else
  echo "Skipped."
fi

echo
kubectl -n "$NAMESPACE" get pods -o wide
kubectl -n "$NAMESPACE" get pdb
echo "Look at the Grafana panel for the error rate during the drills. A well-built app shows (almost) none."
