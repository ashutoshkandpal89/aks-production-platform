#!/usr/bin/env bash
# Builds the demo app, deploys it with a PodDisruptionBudget, and tells Prometheus to scrape it.
source "$(dirname "$0")/_common.sh"

TAG="${IMAGE_TAG:-1.0.0}"
IMAGE="$ACR_LOGIN_SERVER/ops-demo:$TAG"

echo "Building $IMAGE ..."
if ! az acr build -r "$ACR_NAME" -t "ops-demo:$TAG" "$S3_DIR/app"; then
  echo "ACR Tasks failed (some subscriptions block it). Falling back to local Docker..."
  command -v docker >/dev/null || { echo "Docker not found." >&2; exit 1; }
  az acr login -n "$ACR_NAME"
  docker build -t "$IMAGE" "$S3_DIR/app"
  docker push "$IMAGE"
fi

K8S="$S3_DIR/k8s"
kubectl apply -f "$K8S/namespace.yaml"
sed "s|__IMAGE__|$IMAGE|g" "$K8S/deployment.yaml" | kubectl apply -f -
kubectl apply -f "$K8S/service.yaml" -f "$K8S/pdb.yaml"
kubectl apply -f "$K8S/podmonitor.yaml" || \
  echo "  PodMonitor not applied. Is managed Prometheus enabled? Run ./01-deploy-monitoring.sh first."
kubectl -n "$NAMESPACE" rollout status deployment/ops-demo --timeout=10m

echo
kubectl -n "$NAMESPACE" get pods -o wide
echo
echo "Next: ./03-generate-traffic.sh   (then look at the metrics in Grafana)"
