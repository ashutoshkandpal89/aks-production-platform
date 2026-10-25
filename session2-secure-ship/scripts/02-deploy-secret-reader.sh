#!/usr/bin/env bash
# Builds the secret-reader image in ACR and deploys it. The pod reads Key Vault with NO stored secret.
source "$(dirname "$0")/_common.sh"
load_s2_state

TAG="${IMAGE_TAG:-1.0.0}"
IMAGE="$ACR_LOGIN_SERVER/secret-reader:$TAG"

echo "Building $IMAGE ..."
if ! az acr build -r "$ACR_NAME" -t "secret-reader:$TAG" "$S2_DIR/app"; then
  echo "ACR Tasks failed (some subscriptions block it). Falling back to local Docker..."
  command -v docker >/dev/null || { echo "Docker not found." >&2; exit 1; }
  az acr login -n "$ACR_NAME"
  docker build -t "$IMAGE" "$S2_DIR/app"
  docker push "$IMAGE"
fi

echo "Deploying..."
K8S="$S2_DIR/k8s"
sed "s|__WI_CLIENT_ID__|$WI_CLIENT_ID|g" "$K8S/serviceaccount.yaml" | kubectl apply -f -
sed -e "s|__IMAGE__|$IMAGE|g" -e "s|__KEYVAULT_URL__|$KEYVAULT_URI|g" "$K8S/deployment.yaml" | kubectl apply -f -
kubectl apply -f "$K8S/service.yaml"
kubectl -n "$NAMESPACE" rollout status deployment/secret-reader --timeout=10m

echo
echo "--- /env: the AZURE_* variables inside the pod (names only) ---"
kubectl -n "$NAMESPACE" exec deploy/secret-reader -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://localhost:8080/env').read().decode())"
echo "--- /secret: read from Key Vault ---"
for attempt in 1 2 3 4 5 6; do
  if kubectl -n "$NAMESPACE" exec deploy/secret-reader -- python -c \
      "import urllib.request; print(urllib.request.urlopen('http://localhost:8080/secret').read().decode())" 2>/dev/null; then
    break
  fi
  echo "  not ready yet (role assignment still propagating?), retrying in 20s..."; sleep 20
done
echo
echo "Look at the /env output: there is no AZURE_CLIENT_SECRET. Next: ./03-safeguards-demo.sh"
