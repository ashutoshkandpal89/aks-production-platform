#!/usr/bin/env bash
# Builds the demo image in ACR (no local Docker needed) and tags it with a fixed version.
source "$(dirname "$0")/_common.sh"
load_state

APP_DIR="$(cd "$(dirname "$0")/../app" && pwd)"
TAG="${IMAGE_TAG:-1.0.0}"

echo "Building aks-demo:$TAG in $ACR_NAME ..."
if ! az acr build -r "$ACR_NAME" -t "aks-demo:$TAG" "$APP_DIR"; then
  echo
  echo "ACR Tasks failed (some subscriptions, e.g. free trials, block it). Falling back to local Docker..."
  command -v docker >/dev/null || { echo "Docker not found. Install Docker or use a different subscription." >&2; exit 1; }
  az acr login -n "$ACR_NAME"
  docker build -t "$ACR_LOGIN_SERVER/aks-demo:$TAG" "$APP_DIR"
  docker push "$ACR_LOGIN_SERVER/aks-demo:$TAG"
fi

echo "IMAGE=$ACR_LOGIN_SERVER/aks-demo:$TAG" >> "$STATE_FILE"
echo "Done. Next: ./03-deploy-app.sh"
