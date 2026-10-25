# Session 3: Operating AKS: Observability, Resilience and Cost

Practice material for the third session of **"From AKS Pilot to Production Platform"**.
You will watch a workload with managed Prometheus and Grafana, break it on purpose, plan upgrades, and keep the bill under control.

This builds on Session 1 (the cluster). Session 2 is not required.

## What you build

| Area | What you do | Files |
|---|---|---|
| Observability | Managed Prometheus + Managed Grafana, a demo app with `/metrics`, a PodMonitor, three alert rules | `infra/main.bicep`, `app/`, `k8s/podmonitor.yaml` |
| Resilience | 3 replicas, topology spread, probes, a PodDisruptionBudget, then kill a pod and drain a node | `k8s/`, `scripts/04-resilience-drill.sh` |
| Chaos (optional) | Azure Chaos Studio pod-kill experiment | `scripts/07-optional-chaos-studio.sh`, `chaos/` |
| Upgrades | See channels and versions, set maintenance windows | `scripts/05-upgrades-maintenance.sh` |
| Cost | Budget with alerts, requests-vs-use report, leftovers check, optional Spot capacity | `scripts/06-cost-controls.sh`, `scripts/08-optional-spot.sh` |
| Backup | Concepts and a pointer to the current Microsoft guide | `docs/backup-notes.md` |

The architecture diagram is `diagrams/session3-architecture.excalidraw`. Open it at https://excalidraw.com (Open, then pick the file).

## Before you start

- The Session 1 cluster is running (`session1-foundation`), and `kubectl` works against it.
- Azure CLI 2.86.0 or newer, and bash.
- **Remove the `aks-preview` CLI extension** if you have it (`az extension remove --name aks-preview`). The managed Prometheus docs ask for this. Session 2's optional Safeguards command may want the extension, so install it again afterwards if you need it.
- Permission to create resources and assign roles in the resource group.

Cost: Managed Grafana (Standard) and metric ingestion cost money while they exist, on top of the cluster. A day of practice is usually small, but always run `./scripts/99-teardown.sh` when you finish.

## Practice steps

Run everything from the `scripts` folder, in order.

```bash
cd session3-operate/scripts

./00-check-cluster.sh                                  # checks the cluster, registers resource providers
ALERT_EMAIL=you@example.com ./01-deploy-monitoring.sh  # Prometheus workspace, Grafana, alerts, budget
./02-deploy-app.sh                                     # demo app with a PodMonitor and PodDisruptionBudget
./03-generate-traffic.sh 300 0.02                      # 5 minutes of traffic, 2% errors
```

Open the Grafana address printed by script 01. Look at the Kubernetes dashboards, then use **Explore** with the queries in `docs/promql-cheatsheet.md`.

Then the game day. Keep `./03-generate-traffic.sh 600` running in a second terminal:

```bash
./04-resilience-drill.sh      # kill a pod, then drain a node, while you watch the dashboard
```

Then upgrades and cost:

```bash
./05-upgrades-maintenance.sh                          # read-only: versions and channels
APPLY=1 DAY=Saturday START=02:00 UTC_OFFSET=+05:30 ./05-upgrades-maintenance.sh
./06-cost-controls.sh                                 # read-only cost check
```

Optional extras: `./07-optional-chaos-studio.sh` (read `chaos/README.md` first) and `./08-optional-spot.sh`.

When you finish: `./99-teardown.sh` removes what Session 3 added. To remove everything, run the Session 1 teardown too.

## Try next

1. Run `./03-generate-traffic.sh 480 0.4`. After about 6 minutes the **DemoAppHighErrorRate** alert should email you.
2. In `k8s/pdb.yaml` change `maxUnavailable: 1` to `minAvailable: 3`, apply it, and try to drain a node. Watch it hang, then explain why. Undo it.
3. Set `replicas: 1` and repeat the drain. What does the dashboard show?
4. Find the pod with the biggest gap between CPU request and real use, and lower its request.
5. Write a runbook link into the alert annotations in `infra/main.bicep` and redeploy.

## Troubleshooting

- **No metrics in Grafana yet:** it can take several minutes after script 01. Check `kubectl get pods -n kube-system | grep ama-metrics`.
- **PodMonitor not found:** enable Prometheus first (script 01). The custom resource is `azmonitoring.coreos.com`, not `monitoring.coreos.com`.
- **Alert never fires:** the rule needs the error ratio above 5% for 5 minutes, so send traffic for 6 minutes or more.
- **Grafana shows no data source or access denied:** role assignments take a few minutes to propagate. Wait and refresh.
- **Budget deployment fails:** the budget start date must be the first day of a month, and your account type must allow budgets.
- **Drain hangs:** a PodDisruptionBudget or a pod without a controller is blocking it. `kubectl -n ops-demo get pdb`.
- **Spot pool or chaos script fails on Automatic:** see the notes in `chaos/README.md` and `k8s/optional/nodepool-spot.yaml`. These are optional.

## Not verified yet

These come from documentation, not from a run on every cluster type. Check them in your own subscription:
managed Prometheus on AKS Automatic, the Prometheus alert rule group API version, built-in role IDs in the Bicep,
Spot pools through Node Auto Provisioning, and Chaos Studio on your cluster type.

This is learning material, not a hardened production template.
