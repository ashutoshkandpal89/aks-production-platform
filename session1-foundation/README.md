# Session 1: Building a Production-Ready AKS Foundation

Deploy an AKS cluster the right way with Bicep, run a sample app behind a Kubernetes Gateway API ingress, and watch KEDA and Node Auto Provisioning scale it. You can deploy either flavour and compare them:

- **AKS Automatic**: Azure manages nodes, networking, scaling and safeguards. Least to operate. **Start here.**
- **AKS Standard**: you choose and own VNet, identity, node pools and add-ons. Most control.

## What gets created

| Resource | Automatic | Standard |
|---|---|---|
| Resource group and Azure Container Registry (no admin user) | yes | yes |
| Cluster with Entra ID + Azure RBAC (local accounts off in Standard) | yes | yes |
| Virtual network, control plane identity | managed by Azure | created by `network.bicep`, `identity.bicep` |
| Azure CNI Overlay + Cilium | default | set in `aks-standard.bicep` |
| KEDA, Node Auto Provisioning | default | enabled in `aks-standard.bicep` |
| ACR pull with managed identity (`AcrPull`, no passwords) | yes | yes |
| Gateway API ingress (application routing add-on, Istio-based) | yes | yes |

Tip: open `infra/modules/aks-automatic.bicep` and `infra/modules/aks-standard.bicep` side by side. The size difference *is* the lesson.

## Folder map

```
infra/            Bicep: main.bicep, modules/, and parameter files for each tier
diagrams/         Architecture diagram (open the .excalidraw file at excalidraw.com)
app/              Tiny Python web app + Dockerfile (non-root)
k8s/              Deployment, Service, Gateway + HTTPRoute, KEDA ScaledObject
scripts/          Numbered helper scripts (00 to 04, plus 99 teardown)
```

## Practice it

Run these from the `scripts/` folder.

```bash
az login
./00-prereqs.sh                    # checks tools, registers resource providers
export LOCATION=eastus2            # pick a region where AKS Automatic is available
./01-deploy-infra.sh automatic     # or: standard   (5-15 min)
./02-build-push-image.sh           # builds the app image inside ACR
./03-deploy-app.sh                 # app + Gateway API ingress + KEDA
curl http://<printed-gateway-ip>/  # shows pod and node names
```

### Watch autoscaling work

In one terminal:

```bash
kubectl get pods,nodes -n demo -w
```

In another:

```bash
./04-load-test.sh                  # 3 minutes of CPU load
```

You should see: CPU rises, KEDA adds pods, some pods go `Pending`, Node Auto Provisioning adds a node, the pods start. When the load stops, pods scale down, then empty nodes are removed.

### Try these next

1. Deploy `tier=standard` in a second resource group (`RESOURCE_GROUP=rg-s1-std ./01-deploy-infra.sh standard`) and compare how much you had to configure.
2. Change the image in `k8s/deployment.yaml` to a `:latest` tag and apply it to the Automatic cluster. Read the Deployment Safeguards error. (A missing `resources:` block is not denied: safeguards fill in default requests instead. A `:latest` tag or a privileged container is denied.)
3. Swap in `k8s/optional/scaledobject-cron.yaml` to scale on a schedule instead of CPU.
4. Run `kubectl get pods -n demo -o wide` and see how pods spread across zones.

## Clean up (do not skip)

```bash
./99-teardown.sh
```

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Deployment fails with a quota or SKU error | Your region or subscription lacks vCPU quota. For Standard, set `AKS_SYSTEM_VM_SIZE` to a size you have quota for, or try another `LOCATION`. |
| Standard deployment fails on zones | The region has no availability zones. Set `availabilityZones` to `[]` in `main.standard.bicepparam`. |
| `kubectl` says Forbidden or asks to log in | Run `kubelogin convert-kubeconfig -l azurecli`, and wait a minute for the RBAC role to propagate. |
| `az acr build` is blocked | Some subscriptions (for example free trials) disable ACR Tasks. The script falls back to local Docker. |
| Pods stay `Pending` for a few minutes on a new cluster | Normal: Node Auto Provisioning is creating the first workload node. |
| Gateway never becomes `Programmed` | Check the add-on: `kubectl get pods -n aks-istio-system` and `kubectl get gatewayclass`. If `approuting-istio` is missing, see the [Gateway API add-on docs](https://learn.microsoft.com/azure/aks/app-routing-gateway-api). |
| Bicep param error about `ADMIN_OBJECT_ID` | Run the deploy through `01-deploy-infra.sh`, which sets it for you. |

## Notes

- Azure features and API versions change. The Bicep targets `Microsoft.ContainerService/managedClusters@2026-04-01`. If your Azure CLI or region lags behind, update the CLI (`az upgrade`) first.
- `main.bicep` accepts `clusterTier`, `prefix`, `kubernetesVersion` and more. Read the parameter descriptions at the top of the file.
