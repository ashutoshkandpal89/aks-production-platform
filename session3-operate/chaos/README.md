# Chaos testing

Two ways to practise failure. Start with the first.

## 1. Plain kubectl game day (works everywhere)

`scripts/04-resilience-drill.sh` kills a pod and drains a node while you watch the ready-replica count.
It needs nothing but the cluster, and it works on AKS Automatic and Standard.

## 2. Azure Chaos Studio (optional)

`scripts/07-optional-chaos-studio.sh` installs Chaos Mesh with Helm, registers the cluster as a Chaos Studio
target and runs a managed pod-kill experiment from `experiment-podkill.json.template`.

Read this before you try it:

- **Automatic clusters:** Chaos Mesh's daemon needs elevated rights, and AKS Automatic's safeguards and
  Pod Security rules may block it. The script refuses to run on Automatic unless you set `FORCE=1`.
  Check the Chaos Studio and AKS docs for your cluster type.
- **Roles:** the script gives the experiment's identity *AKS RBAC Cluster Admin* on the cluster. That is
  fine for a lab and wrong for production. Use a custom role there.
- **Versions move:** the Chaos Studio docs show a capability version (`PodChaos-2.1`) that differs from the
  fault URN version (`podChaos/2.2`). Confirm the current version in the fault library and set `CAP_VERSION`.
- **Classic experiments are being replaced** by Chaos Studio workspaces. The portal flow may look different
  from the REST calls here.
- Start with one pod in one namespace, a short duration, and a person watching.
