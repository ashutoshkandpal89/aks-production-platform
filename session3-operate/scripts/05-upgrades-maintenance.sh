#!/usr/bin/env bash
# Shows upgrade options and the current channels. Add APPLY=1 to create maintenance windows.
# Usage:  ./05-upgrades-maintenance.sh
#         APPLY=1 DAY=Saturday START=02:00 UTC_OFFSET=+05:30 ./05-upgrades-maintenance.sh
source "$(dirname "$0")/_common.sh"

echo "== Kubernetes versions =="
az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query "{current:kubernetesVersion, upgradeChannel:autoUpgradeProfile.upgradeChannel, nodeOsChannel:autoUpgradeProfile.nodeOsUpgradeChannel}" -o table
echo
az aks get-upgrades -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" -o table || true

echo
echo "== Existing maintenance configurations =="
az aks maintenanceconfiguration list -g "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" -o table || true

if [[ "${APPLY:-0}" != "1" ]]; then
  cat <<TXT

Nothing changed. To create maintenance windows, run again with APPLY=1.
  aksManagedAutoUpgradeSchedule        controls WHEN Kubernetes version upgrades happen
  aksManagedNodeOSUpgradeSchedule      controls WHEN node OS patching happens
Optional: DAY, START, UTC_OFFSET, DURATION (hours, 4 or more for auto-upgrade).
TXT
  exit 0
fi

DAY="${DAY:-Saturday}"; START="${START:-02:00}"; OFFSET="${UTC_OFFSET:-+00:00}"; DURATION="${DURATION:-4}"
echo
echo "Creating maintenance windows: $DAY $START (UTC$OFFSET), $DURATION hours"
echo "(Windows only apply if an auto-upgrade channel is set. On Standard you can set one:"
echo "   az aks update -g $RESOURCE_GROUP -n $CLUSTER_NAME --auto-upgrade-channel patch --node-os-upgrade-channel NodeImage )"
az aks maintenanceconfiguration add -g "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name aksManagedAutoUpgradeSchedule --schedule-type Weekly --day-of-week "$DAY" \
  --interval-weeks 1 --duration "$DURATION" --utc-offset "$OFFSET" --start-time "$START"
az aks maintenanceconfiguration add -g "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name aksManagedNodeOSUpgradeSchedule --schedule-type Weekly --day-of-week "$DAY" \
  --interval-weeks 1 --duration "$DURATION" --utc-offset "$OFFSET" --start-time "$START"
az aks maintenanceconfiguration list -g "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" -o table
