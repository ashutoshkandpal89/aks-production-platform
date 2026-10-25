# Building Production-Grade Platforms on Azure Kubernetes Service

Hands-on code for the free 3-part series **"From AKS Pilot to Production Platform"**, so you can practice every demo in your own Azure subscription.

| Session | Topic | Folder | Status |
|---|---|---|---|
| 1 | Building a Production-Ready AKS Foundation | [`session1-foundation`](session1-foundation) | Available |
| 2 | Securing and Shipping on AKS | [`session2-secure-ship`](session2-secure-ship) | Available |
| 3 | Operating AKS: Observability, Resilience and Cost | [`session3-operate`](session3-operate) | Available |

Each session builds on the one before it, so start with Session 1.

## What you need

- An Azure subscription where you can create resources and assign roles (Owner, or Contributor + User Access Administrator)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.86.0 or newer, and `kubectl` (`az aks install-cli` installs `kubectl` and `kubelogin`)
- A bash shell (Linux, macOS, WSL, or Azure Cloud Shell)

## Cost warning

AKS, VMs, a load balancer and a container registry cost real money while they exist. A Session 1 cluster typically costs a few US dollars per day. **Always run the teardown script when you finish practicing.**

## Disclaimer

This is learning material, not a hardened production template. Review every setting against your own security, networking and compliance requirements before using it for real workloads. Provided as is, without warranty.
