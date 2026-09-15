# ARC runner setup (per cluster)

These snippets are **applied inside each cluster's k8s context** — they are
*not* part of the Actions workflow. They define the ARC runner sets whose labels
the `verify-arc.yml` workflow targets.

Apply with the controller's chosen auth (GitHub PAT or GitHub App); see the
[ARC docs](https://github.com/actions/actions-runner-controller) for controller
install and secret setup. Only the labels matter for routing — the rest
(replicas, image, resource requests) is a minimal starting point.

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

After applying, both clusters' runners should appear under
**repo Settings → Actions → Runners**, each tagged with its `cluster:` label.
Then run the workflow — `Settings → Actions → Runners` shows which runner
accepted each matrix leg.

## Notes

- If you prefer ephemeral, autoscaling runners, swap `RunnerDeployment` for
  `RunnerSet` (on spot/autoscaled node groups) and carry the **same** `labels`.
- `self-hosted` is applied automatically by ARC; you only need to add the
  `cluster:<name>` label. The workflow's `runs-on` lists both.
- Make sure the controller's GitHub auth scope covers this repo (PAT with `repo`
  scope, or a GitHub App installed on `leonaltair/arc-fed`).
