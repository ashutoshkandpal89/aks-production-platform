#!/usr/bin/env bash
# Sends parallel requests to /load so CPU rises, KEDA adds pods, and NAP adds nodes.
# Usage: ./04-load-test.sh [seconds] [parallel-clients]    (defaults: 180 seconds, 40 clients)
source "$(dirname "$0")/_common.sh"
load_state
GATEWAY_IP="$(grep '^GATEWAY_IP=' "$STATE_FILE" | tail -1 | cut -d= -f2-)"
[[ -n "$GATEWAY_IP" ]] || { echo "No gateway address recorded. Run ./03-deploy-app.sh first." >&2; exit 1; }

DURATION="${1:-180}"
CLIENTS="${2:-40}"
echo "Hitting http://$GATEWAY_IP/load with $CLIENTS clients for ${DURATION}s. Ctrl+C to stop."
echo "Watch in another terminal:  kubectl get hpa,pods,nodes -n demo -w"

client() {
  local end=$((SECONDS + DURATION))
  while (( SECONDS < end )); do
    curl -s -o /dev/null --max-time 10 "http://$GATEWAY_IP/load" || true
  done
}
trap 'kill 0' INT TERM
for _ in $(seq "$CLIENTS"); do client & done
wait
echo "Load finished. Pods scale down after the cooldown (about a minute); empty nodes are removed a few minutes later."
