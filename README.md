# arc-fed

Verify GitHub Actions → [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller) dispatch across **two Kubernetes clusters** (`cluster-1`, `cluster-2`).

Each cluster runs its own ARC runner set carrying a distinct runner label. A single matrix workflow fans out to both clusters so you can confirm:

1. ARC runners in each cluster register with GitHub and pick up jobs.
2. Runner labels route each matrix leg to the intended cluster.
3. The runner pod environment is what you expect (node/runner metadata).

## Cluster targeting

Clusters are distinguished by a `cluster:<name>` runner label. Each cluster's
`RunnerDeployment` (or `RunnerSet`) must advertise the matching label:

| Cluster  | `runs-on` labels                         |
|----------|------------------------------------------|
| cluster-1 | `self-hosted`, `cluster:cluster-1`      |
| cluster-2 | `self-hosted`, `cluster:cluster-2`      |

See [`docs/arc-runner-setup.md`](docs/arc-runner-setup.md) for the exact
`RunnerDeployment` manifests to apply in each cluster.

## The verification workflow

[`.github/workflows/verify-arc.yml`](.github/workflows/verify-arc.yml) is the
entry point: it fires on every push to `main` and via manual dispatch (which can
target a single cluster: `all` / `cluster-1` / `cluster-2`). For each cluster
it calls the reusable [`.github/workflows/smoke.yml`](.github/workflows/smoke.yml),
which runs on that cluster's labeled runner, prints cluster and runner identity,
and asserts the job landed on the expected `cluster:` label.

> Note: `matrix` can't be referenced in a job-level `if` (evaluated before matrix
> expansion), so each cluster is a separate caller job delegating to `smoke.yml`.

## Repository layout

```
.github/workflows/verify-arc.yml   # entry point: triggers + per-cluster caller jobs
.github/workflows/smoke.yml       # reusable: runs on a cluster's labeled runner
docs/arc-runner-setup.md            # ARC RunnerDeployment manifests per cluster
README.md
.gitignore
```

## Prerequisites (outside this repo)

- Two k8s clusters with ARC installed and a GitHub PAT / GitHub App configured on
  the controller (see ARC docs).
- A `RunnerDeployment`/`RunnerSet` per cluster applying the labels above.
- This repo enabled for Actions, with self-hosted runners visible under
  Settings → Actions → Runners (grouped by label).
