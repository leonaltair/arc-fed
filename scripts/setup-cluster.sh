#!/usr/bin/env bash
# Install ARC into one self-built k8s cluster and register its runner set.
#
# Run once per cluster from Cloud Shell (or any machine with kubectl + helm
# and a kubeconfig context for that cluster):
#
#   GITHUB_APP_ID=1234567 \
#   GITHUB_APP_INSTALLATION_ID=987654 \
#   GITHUB_APP_PRIVATE_KEY_FILE=path/to/private-key.pem \
#   ./scripts/setup-cluster.sh --context ctx-cluster-1 --cluster cluster-1
#
# Env:
#   GITHUB_APP_ID               GitHub App numeric ID
#   GITHUB_APP_INSTALLATION_ID  installation ID for leonaltair/arc-fed
#   GITHUB_APP_PRIVATE_KEY_FILE path to the downloaded .pem (preserves newlines)
#
# Flags:
#   --context   kubeconfig context for this cluster (required)
#   --cluster   cluster-1 | cluster-2  (selects deploy/runner-<cluster>.yaml)
#   --skip-controller  only (re)apply the RunnerDeployment, skip controller install
set -euo pipefail

CTX=""
CLUSTER=""
SKIP_CONTROLLER=0
while [ $# -gt 0 ]; do
  case "$1" in
    --context) CTX="$2"; shift 2 ;;
    --cluster) CLUSTER="$2"; shift 2 ;;
    --skip-controller) SKIP_CONTROLLER=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$CTX" ] || { echo "ERROR: --context is required" >&2; exit 2; }
[ "$CLUSTER" = "cluster-1" ] || [ "$CLUSTER" = "cluster-2" ] || {
  echo "ERROR: --cluster must be cluster-1 or cluster-2" >&2; exit 2; }

command -v kubectl >/dev/null || { echo "ERROR: kubectl not found" >&2; exit 1; }
command -v helm    >/dev/null || { echo "ERROR: helm not found"    >&2; exit 1; }

if [ "$SKIP_CONTROLLER" -eq 0 ]; then
  : "${GITHUB_APP_ID:?GITHUB_APP_ID is required}"
  : "${GITHUB_APP_INSTALLATION_ID:?GITHUB_APP_INSTALLATION_ID is required}"
  : "${GITHUB_APP_PRIVATE_KEY_FILE:?GITHUB_APP_PRIVATE_KEY_FILE is required}"
  [ -f "$GITHUB_APP_PRIVATE_KEY_FILE" ] || {
    echo "ERROR: key file not found: $GITHUB_APP_PRIVATE_KEY_FILE" >&2; exit 1; }
fi

# Resolve to the repo root so the script works from any cwd.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

K="kubectl --context=$CTX"
echo "==> context: $CTX | cluster: $CLUSTER"
$K cluster-info

if [ "$SKIP_CONTROLLER" -eq 0 ]; then
  echo
  echo "==> 1/5 cert-manager"
  helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
  helm repo update
  helm upgrade --install cert-manager jetstack/cert-manager \
    -n cert-manager --create-namespace --set installCRDs=true --wait

  echo
  echo "==> 2/5 ARC controller"
  helm repo add actions-runner-controller \
    https://actions-runner-controller.github.io/actions-runner-controller 2>/dev/null || true
  helm repo update
  helm upgrade --install arc actions-runner-controller/actions-runner-controller \
    -n actions-runner-system --create-namespace --wait

  echo
  echo "==> 3/5 GitHub App secret (controller-manager)"
  $K -n actions-runner-system delete secret controller-manager --ignore-not-found
  $K -n actions-runner-system create secret generic controller-manager \
    --from-literal=github_app_id="$GITHUB_APP_ID" \
    --from-literal=github_app_installation_id="$GITHUB_APP_INSTALLATION_ID" \
    --from-file=github_app_private_key="$GITHUB_APP_PRIVATE_KEY_FILE"
  # Restart the controller so it picks up the (possibly updated) secret.
  $K -n actions-runner-system rollout restart deployment/controller-manager || true
  $K -n actions-runner-system rollout status deployment/controller-manager --timeout=180s || true
else
  echo "==> --skip-controller: skipping 1-3"
fi

echo
echo "==> 4/5 runner namespace"
$K create namespace arc-runners --dry-run=client -o yaml | $K apply -f -

echo
echo "==> 5/5 RunnerDeployment for $CLUSTER"
$K apply -f "$ROOT/deploy/runner-${CLUSTER}.yaml"

echo
echo "==> runner pods"
$K -n arc-runners get runners -o wide || \
  $K -n arc-runners get pods -o wide

echo
echo "DONE. Watch registration:"
echo "  $K -n arc-runners get runners -w"
echo "Then confirm in GitHub: repo Settings -> Actions -> Runners"
