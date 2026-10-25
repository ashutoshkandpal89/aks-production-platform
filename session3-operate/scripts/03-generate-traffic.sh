#!/usr/bin/env bash
# Sends steady traffic to every pod, including a share of failing requests, so the dashboards have something to show.
# Usage: ./03-generate-traffic.sh [seconds] [error-rate 0-1]     (defaults: 300 seconds, 0.02)
# Try a high error rate (for example 0.4) for 6+ minutes to trigger the DemoAppHighErrorRate alert.
source "$(dirname "$0")/_common.sh"

DURATION="${1:-300}"
RATE="${2:-0.02}"
PORT_BASE=18080

# Read the pod names into an array (a loop instead of mapfile, so it works with macOS's bash 3.2)
PODS=()
for name in $(kubectl -n "$NAMESPACE" get pods -l app=ops-demo -o jsonpath='{.items[*].metadata.name}'); do PODS+=("$name"); done
[[ ${#PODS[@]} -gt 0 ]] || { echo "No ops-demo pods found. Run ./02-deploy-app.sh first." >&2; exit 1; }

cleanup() { kill 0 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# One port-forward per pod, so traffic reaches all of them (a Service port-forward would pin one pod).
for i in "${!PODS[@]}"; do
  kubectl -n "$NAMESPACE" port-forward "pod/${PODS[$i]}" "$((PORT_BASE + i)):8080" >/dev/null 2>&1 &
done
sleep 3

echo "Sending traffic to ${#PODS[@]} pods for ${DURATION}s, error rate $RATE. Ctrl+C to stop."
END=$((SECONDS + DURATION))
n=0
while (( SECONDS < END )); do
  port=$((PORT_BASE + (n % ${#PODS[@]})))
  curl -s -o /dev/null --max-time 5 "http://localhost:$port/work" || true
  curl -s -o /dev/null --max-time 5 "http://localhost:$port/flaky?rate=$RATE" || true
  n=$((n + 1))
  sleep 0.05
done
echo "Done. $n rounds sent."