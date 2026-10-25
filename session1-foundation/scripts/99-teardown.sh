#!/usr/bin/env bash
# Deletes EVERYTHING created by these scripts (the whole resource group). Stops the billing.
source "$(dirname "$0")/_common.sh"

echo "This will delete resource group '$RESOURCE_GROUP' and everything in it."
read -r -p "Type the resource group name to confirm: " CONFIRM
[[ "$CONFIRM" == "$RESOURCE_GROUP" ]] || { echo "Cancelled."; exit 1; }

az group delete -n "$RESOURCE_GROUP" --yes --no-wait
rm -f "$STATE_FILE"
echo "Deletion started (runs in the background, a few minutes)."
