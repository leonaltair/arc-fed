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

[`.github/workflows/verify-arc.yml`](.github/workflows/verify-arc.yml) runs a
matrix over the two clusters. Each leg checks out the repo, prints cluster and
runner identity, and asserts the job landed on the expected `cluster:` label.

It fires on every push to `main` and via manual dispatch. Manual dispatch lets
you target a single cluster (`all` / `cluster-1` / `cluster-2`) for isolation.

## Repository layout

```
.github/workflows/verify-arc.yml   # matrix smoke test
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
