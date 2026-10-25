#!/usr/bin/env bash
# Deploys the app, Gateway API ingress and the KEDA ScaledObject.
source "$(dirname "$0")/_common.sh"
load_state
IMAGE="$(grep '^IMAGE=' "$STATE_FILE" | tail -1 | cut -d= -f2-)"
[[ -n "$IMAGE" ]] || { echo "No image recorded. Run ./02-build-push-image.sh first." >&2; exit 1; }

K8S_DIR="$(cd "$(dirname "$0")/../k8s" && pwd)"

echo "Deploying app with image $IMAGE ..."
sed "s|__IMAGE__|$IMAGE|g" "$K8S_DIR/deployment.yaml" | kubectl apply -f -
kubectl apply -f "$K8S_DIR/gateway.yaml"
kubectl apply -f "$K8S_DIR/scaledobject.yaml"

echo "Waiting for the first pods. On a fresh cluster, Node Auto Provisioning may add a node first (2-4 min)..."
kubectl -n demo rollout status deployment/aks-demo --timeout=10m

echo "Waiting for the Gateway to get an address..."
kubectl -n demo wait --for=condition=programmed gateways.gateway.networking.k8s.io/aks-demo-gateway --timeout=10m
GATEWAY_IP="$(kubectl -n demo get gateways.gateway.networking.k8s.io aks-demo-gateway -o jsonpath='{.status.addresses[0].value}')"
echo "GATEWAY_IP=$GATEWAY_IP" >> "$STATE_FILE"

echo
echo "App is live:  curl http://$GATEWAY_IP/"
echo "Next: ./04-load-test.sh   (in another terminal: kubectl get pods,nodes -n demo -w)"
