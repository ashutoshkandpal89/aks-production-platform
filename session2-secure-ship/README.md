# Session 2: Securing and Shipping on AKS

Run applications with **no stored secrets**, let **Git** drive the cluster, **block unsafe pods** at admission, and **deploy from GitHub Actions** without a single stored credential.

This builds on the cluster from [Session 1](../session1-foundation). Automatic or Standard both work.

## What you will practice

| Demo | Idea | Where |
|---|---|---|
| Workload Identity + Key Vault | A pod reads a secret with no password, key or connection string | `infra/`, `app/`, `k8s/` |
| GitOps with Flux | Change in Git and the cluster follows; change the cluster and Flux reverts it | `gitops/`, `infra/modules/flux.bicep` |
| Deployment Safeguards | A privileged pod and a `:latest` image are rejected | `k8s/bad/` |
| GitHub Actions with OIDC | Build, scan and deploy with no stored credentials | `../.github/workflows/session2-deploy.yml` |
| Security baseline | A checklist for your own clusters | `docs/security-baseline-checklist.md` |

## Before you start

- Session 1 is deployed (the scripts here read its settings), and `kubectl get ns` works.
- Your **own copy of this repo on GitHub** (fork or push it). The GitOps and pipeline demos need it. For GitOps the repo must be **public**.
- GitHub CLI (`gh`) is optional. It saves copying values by hand.

## Practice it

Run these from this folder's `scripts/` directory.

```bash
export GITHUB_OWNER=<your-github-user-or-org>
export GITHUB_REPO=<your-repo-name>

./00-check-cluster.sh            # OIDC issuer on? kubectl works? registers providers
./01-deploy-identity.sh          # Key Vault + workload identity + GitHub identity (Bicep)
./02-deploy-secret-reader.sh     # app reads Key Vault with NO stored secret
./03-safeguards-demo.sh          # privileged pod and :latest image get rejected
```

### GitOps (needs your repo pushed and public)

```bash
export GITOPS_REPO_URL=https://github.com/<you>/<repo>
./04-setup-gitops.sh

kubectl -n gitops-demo scale deployment/hello --replicas=5   # change the cluster by hand
kubectl -n gitops-demo get deployment hello -w               # watch Flux put it back to 2
```

Then edit `replicas` in `gitops/apps/secure-app/deployment.yaml`, commit, push, and watch the cluster follow.

### The pipeline (needs your repo on GitHub)

```bash
./05-github-setup.sh             # sets the repo VARIABLES (identifiers, not secrets)
```

Then in GitHub: **Actions > Session 2 - build, scan and deploy > Run workflow**.
The identity is trusted only for `repo:<owner>/<repo>:ref:refs/heads/main` and can write only to the `secure-demo` namespace.

## Try these next

1. Run `kubectl -n secure-demo exec deploy/secret-reader -- env | grep AZURE_` and confirm there is no client secret.
2. Remove the `azure.workload.identity/use` label from `k8s/deployment.yaml`, redeploy, and read the error from `/secret`.
3. Change the federated credential subject in `infra/modules/workload-identity.bicep` to a wrong ServiceAccount name and see authentication fail.
4. Apply `k8s/optional/networkpolicy-default-deny-ingress.yaml` and test traffic.
5. Try the CSI driver variant in `k8s/optional/secretproviderclass.yaml`.
6. Make the Trivy step fail on purpose by switching the base image to an old version.
7. Optional: `./06-optional-defender.sh` (costs money; read the warning first).

## Clean up

```bash
./99-teardown.sh                 # removes only what Session 2 added
```

Deleting the Session 1 resource group removes everything.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `/secret` returns `ClientAuthenticationError` or 403 | The Key Vault role assignment has not propagated yet (wait a few minutes), or the ServiceAccount name or namespace does not match the federated credential. |
| Pod has no `AZURE_FEDERATED_TOKEN_FILE` | The pod is missing the label `azure.workload.identity/use: "true"` or the ServiceAccount is missing the `client-id` annotation. |
| `01-deploy-identity.sh` cannot write the secret | RBAC propagation. The script retries for a few minutes. Re-run it if it gives up. |
| Privileged pod is **not** rejected on Standard | Safeguards take 5 to 15 minutes to sync after enabling. Run `./03-safeguards-demo.sh` again. If `az aks safeguards` is unknown, run `az extension add --name aks-preview`. |
| Missing `resources:` is not rejected on Automatic | Expected: in Enforce mode safeguards **mutate** missing requests to defaults instead of denying. Try the privileged pod or `:latest` tag, which are denied. |
| Flux configuration fails to install | Make sure `Microsoft.KubernetesConfiguration` is registered. Check that your cluster type supports the Flux extension. The repo must be public and the path must exist on the branch you set. |
| Workflow fails at "Sign in to Azure" | The federated credential subject must match exactly: `repo:<owner>/<repo>:ref:refs/heads/main`. Running from another branch or using a GitHub *environment* changes the subject. |
| Workflow fails at the Trivy step | The image has HIGH or CRITICAL findings with fixes available. That is the gate working: update the base image, or adjust the severity in the workflow. |
| Bicep role assignment error | A built-in role ID differs in your cloud, or the identity has not replicated yet. Re-run the script. |

## Notes

- This is learning material, not a hardened production template. Key Vault public access and disabled purge protection are lab settings, called out in `infra/modules/keyvault.bicep`.
- Azure features and action versions change. Check the pinned versions in the workflow before you rely on them.
