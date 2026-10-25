# AKS security baseline checklist

A starting point for your own clusters. Tick each item, and keep the "how to check" next to it so the check is repeatable. Not a compliance standard: adapt it to your own risk and regulatory needs.

## 1. Identity and access

- [ ] **Entra ID sign-in, local accounts disabled.** Nobody uses a shared admin kubeconfig.
  Check: `az aks show -g <rg> -n <cluster> --query "{aad:aadProfile.managed, rbac:aadProfile.enableAzureRBAC, local:disableLocalAccounts}"`
- [ ] **Azure RBAC for Kubernetes authorization**, with groups (not individuals) holding roles.
- [ ] **Least privilege per namespace.** Pipelines and teams get a Writer role on their namespace, not Cluster Admin.
  Check: `az role assignment list --scope <aks-id>/namespaces/<ns> -o table`
- [ ] **Few cluster admins**, and the list is reviewed regularly.

## 2. Secrets

- [ ] **No secrets in Git, images, manifests or CI variables.** Run a secret scanner in the repo.
- [ ] **Pods use Workload Identity** (no client secrets, no keys).
  Check: `kubectl -n <ns> exec deploy/<app> -- env | grep AZURE_` shows no `AZURE_CLIENT_SECRET`.
- [ ] **Key Vault uses RBAC mode**, with `Key Vault Secrets User` for apps (read only).
- [ ] **Key Vault purge protection is on** and public access is restricted (private endpoint) for production.
- [ ] **Federated credentials are narrow**: one issuer, one namespace, one ServiceAccount.

## 3. Workload hardening

- [ ] **Pod Security Standards enforced** (`baseline` at minimum, `restricted` where you can).
  Check: `kubectl get ns --show-labels | grep pod-security`
- [ ] **Deployment Safeguards on in Enforce mode** (default on AKS Automatic).
  Check: Azure portal > your cluster > Policies, or look for the Deployment Safeguards initiative in Azure Policy.
- [ ] **Containers run as non-root**, drop all capabilities, forbid privilege escalation, use a read-only root filesystem.
- [ ] **Resource requests and limits on every container.**
- [ ] **Readiness and liveness probes on every container.**
- [ ] **No `:latest` tags.** Images are pinned to a version or digest.

## 4. Network

- [ ] **Network policy enabled** (Cilium) with **default-deny** in each application namespace.
- [ ] **Egress path is designed**, not accidental (firewall, NAT gateway, or at least known).
- [ ] **API server access is restricted** (private cluster or authorized IP ranges).
- [ ] **Ingress is standardized** on one approach (Gateway API), with TLS.

## 5. Supply chain

- [ ] **Images come only from your registry.** Registry admin user is off.
  Check: `az acr show -n <acr> --query adminUserEnabled`
- [ ] **Images are scanned in the pipeline** and the build fails on critical findings.
- [ ] **Registry and runtime are scanned** (for example Microsoft Defender for Containers).
- [ ] **Base images are small and updated** on a schedule.
- [ ] **Pipeline deploys with OIDC**, not stored credentials, and only from protected branches.

## 6. Delivery and drift

- [ ] **Git is the source of truth** (GitOps). Changes go through pull requests.
- [ ] **Drift is corrected automatically** (Flux prune and sync on).
- [ ] **Nobody deploys by hand** with `kubectl apply` outside break-glass situations.

## 7. Monitoring and response

- [ ] **Audit and security logs** go to a Log Analytics workspace with sensible retention.
- [ ] **Alerts exist** for policy violations, failed sign-ins and new privileged access.
- [ ] **A break-glass procedure** exists, is documented and has been tested.

*Session 3 covers observability, upgrades and backup in depth.*
