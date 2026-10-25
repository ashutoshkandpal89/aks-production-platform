#!/usr/bin/env bash
# OPTIONAL. Adds a Spot capacity pool for interruptible work. Spot VMs can be evicted at any time. Never put critical pods there.
source "$(dirname "$0")/_common.sh"

SKU="$(cluster_sku)"
if [[ "$SKU" == "Automatic" ]]; then
  echo "AKS Automatic: using a Node Auto Provisioning NodePool."
  kubectl apply -f "$S3_DIR/k8s/optional/nodepool-spot.yaml"
  kubectl apply -f "$S3_DIR/k8s/optional/batch-on-spot.yaml"
  echo "Watch a Spot node appear:  kubectl get nodes -L karpenter.sh/capacity-type -w"
else
  echo "AKS Standard: adding a Spot node pool (autoscaling from 0)."
  az aks nodepool add -g "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" -n spot1 \
    --priority Spot --eviction-policy Delete --spot-max-price -1 \
    --enable-cluster-autoscaler --min-count 0 --max-count 3 --node-count 0 \
    --labels workload-class=spot \
    --node-taints "workload-class=spot:NoSchedule"
  kubectl apply -f "$S3_DIR/k8s/optional/batch-on-spot.yaml"
  echo "AKS also taints Spot nodes itself, so pods may need that toleration as well: see the AKS Spot node pool docs."
fi
echo "Remove it again with ./99-teardown.sh"
