# ARC runner setup (per cluster)

Everything here is applied **inside each cluster's k8s context** — it is *not*
part of the Actions workflow. Repeat the whole sequence for `cluster-1` and
`cluster-2`; the two clusters are fully independent (separate controller,
separate auth secret, separate RunnerDeployment). The same PAT / GitHub App
may be reused across both clusters.

## 0. Prerequisites (per cluster)

### cert-manager — ARC webhook dependency

```bash
helm repo add jetstack https://charts.jetstack.io
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace --set installCRDs=true
```

### ARC controller

```bash
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm upgrade --install arc actions-runner-controller/actions-runner-controller \
  -n actions-runner-system --create-namespace
```

### GitHub auth for the controller

The controller uses these credentials to mint per-pod registration tokens from
GitHub. The runner pods themselves need **no** separate secret. Pick one:

**PAT (simplest):**
```bash
kubectl create secret generic controller-manager -n actions-runner-system \
  --from-literal=github_token=ghp_xxx        # PAT needs `repo` scope
```

**GitHub App (recommended for production):**
```bash
kubectl create secret generic controller-manager -n actions-runner-system \
  --from-literal=github_app_id=... \
  --from-literal=github_app_installation_id=... \
  --from-literal=github_app_private_key=-----BEGIN\ RSA\ PRIVATE\ KEY-----...-----END\ RSA\ PRIVATE\ KEY-----
```
GitHub App permissions (repo-level, installed on `leonaltair/arc-fed`):
Administration Read/Write, Actions Read/Write, Metadata Read.

### Runner namespace

```bash
kubectl create namespace arc-runners
```

---

## RunnerDeployments

Only the labels matter for routing — the rest (replicas, image, resource
requests) is a minimal starting point.

## cluster-1

```yaml
# kubectl apply -f this --context cluster-1
apiVersion: actions.github.com/v1alpha1
kind: RunnerDeployment
metadata:
  name: arc-runner-cluster-1
  namespace: arc-runners
spec:
  replicas: 2
  template:
    spec:
      repository: leonaltair/arc-fed        # repo these runners serve
      labels:
        - cluster:cluster-1                # <-- targeted by runs-on
      # resources are optional; adjust to your cluster capacity
      # resources:
      #   requests: { cpu: "1", memory: "1Gi" }
      #   limits:   { cpu: "2", memory: "2Gi" }
```

## cluster-2

```yaml
# kubectl apply -f this --context cluster-2
apiVersion: actions.github.com/v1alpha1
kind: RunnerDeployment
metadata:
  name: arc-runner-cluster-2
  namespace: arc-runners
spec:
  replicas: 2
  template:
    spec:
      repository: leonaltair/arc-fed
      labels:
        - cluster:cluster-2                # <-- targeted by runs-on
```

## Verify registration

After applying both RunnerDeployments, runners from each cluster should appear
under **repo Settings → Actions → Runners**, tagged with their `cluster:` label.

Cluster-side checks:
```bash
kubectl get runners -n arc-runners                      # pod status
kubectl get runnerdeployment -n arc-runners
kubectl logs -n arc-runners -l app=runner               # registration log
```
Then run the workflow — the run summary shows which runner accepted each leg
and asserts the `cluster:` label routed correctly.

## Notes

- This setup uses **fixed replicas** (always-on runners). No GitHub webhook is
  required. If you later want on-demand autoscaling, switch to `RunnerSet`
  (on spot/autoscaled node groups) with the **same** `labels`, and configure a
  GitHub webhook → ARC webhook server. That is additional config — start with
  fixed replicas first.
- `self-hosted` is applied automatically by ARC; you only add the
  `cluster:<name>` label. The workflow's `runs-on` lists both.
- These manifests target **repo-level runners** (`repository: leonaltair/arc-fed`).
  For organization-level runners, replace `repository:` with `organization:`.
- Each cluster's controller reads the same `controller-manager` secret name in
  `actions-runner-system`; reusing the same PAT/App across clusters is fine.
