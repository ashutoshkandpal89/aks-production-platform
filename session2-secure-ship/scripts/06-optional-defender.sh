#!/usr/bin/env bash
# OPTIONAL: turns on the Microsoft Defender for Containers profile on this cluster.
# Defender for Cloud plans are BILLED per vCore (or per image/resource depending on the plan).
# Read the pricing page for your region before you say yes. Not needed for the other demos.
source "$(dirname "$0")/_common.sh"

echo "This enables the Defender profile on cluster $CLUSTER_NAME."
echo "It can add cost to your subscription. See: https://azure.microsoft.com/pricing/details/defender-for-cloud/"
read -r -p "Type 'yes' to continue: " OK
[[ "$OK" == "yes" ]] || { echo "Cancelled."; exit 1; }

az aks update -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --enable-defender
echo "Enabled. Review findings in the Azure portal: Microsoft Defender for Cloud > Recommendations."
echo "To turn it off again: az aks update -g $RESOURCE_GROUP -n $CLUSTER_NAME --disable-defender"
