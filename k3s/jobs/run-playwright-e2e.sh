#!/usr/bin/env bash
set -euo pipefail

NS=phoenixapp
JOB_FILE="k3s/jobs/playwright-e2e-job.yaml"

usage() {
  cat <<EOF
Usage: $0 [--github-token <token>] [--test-url <url>] [--ref <git-ref>]

Optional args:
  --github-token  GitHub token if repository is private (creates/updates secret ci-github/token)
  --test-url      Base URL to target from Playwright tests inside the cluster (default: http://phoenix-web)
  --ref           Git ref to checkout (defaults to master)

Examples:
  # Run against the in-cluster service
  $0

  # Run using private repo token
  Usage: $0 [--github-token <token>] [--test-url <url>] [--ref <git-ref>] [--test-user <user>] [--test-pwd <password>]

  Optional args:
  GITHUB_TOKEN=xxx $0 --ref main --test-url http://phoenix-web

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-user) TEST_USER=$2; shift 2;;
    --test-pwd) TEST_PWD=$2; shift 2;;
    --github-token) GITHUB_TOKEN=$2; shift 2;;
    --test-url) TEST_URL=$2; shift 2;;
    --ref) GIT_REF=$2; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "Creating/updating secret ci-github (namespace: $NS)"
  kubectl -n $NS create secret generic ci-github --from-literal=token="$GITHUB_TOKEN" --dry-run=client -o yaml | kubectl apply -f -
fi

if [[ -n "${TEST_USER:-}" && -n "${TEST_PWD:-}" ]]; then
  echo "Creating/updating secret ci-playwright-auth (namespace: $NS)"
  kubectl -n $NS create secret generic ci-playwright-auth --from-literal=user="$TEST_USER" --from-literal=pwd="$TEST_PWD" --dry-run=client -o yaml | kubectl apply -f -
fi

# Apply and wait for seeding job first so that the e2e user is present before Playwright runs
echo "Applying e2e user seeding job (create-e2e-user)"
# ensure previous job object is removed to avoid immutable field patch issues
kubectl -n $NS delete job/create-e2e-user --ignore-not-found || true
if [[ -n "${TEST_URL:-}" ]]; then
  sed -e "s|value: \"http://phoenix-web\"|value: \"$TEST_URL\"|g" k3s/jobs/create-e2e-user-job.yaml | kubectl -n $NS apply -f -
else
  kubectl -n $NS apply -f k3s/jobs/create-e2e-user-job.yaml
fi

echo "Waiting for create-e2e-user to complete (or exit)"
kubectl -n $NS wait --for=condition=complete --timeout=120s job/create-e2e-user || {
  echo "create-e2e-user job may have failed or timed out; dumping logs..."
  kubectl -n $NS logs job/create-e2e-user --tail=200 || true
  # don't fail the entire pipeline if seeding job failed — Playwright can still attempt login/register
}

# Now apply the Playwright job (delete previous instances first to avoid immutable patch errors)
if [[ -n "${TEST_URL:-}" ]]; then
  echo "Patching playwright job to use TEST_URL=$TEST_URL"
  kubectl -n $NS delete job/playwright-e2e --ignore-not-found || true
  sed -e "s|value: \"http://phoenix-web\"|value: \"$TEST_URL\"|g" "$JOB_FILE" | kubectl -n $NS apply -f -
else
  kubectl -n $NS delete job/playwright-e2e --ignore-not-found || true
  kubectl -n $NS apply -f "$JOB_FILE"
fi

# (Playwright job has been applied above — continue to wait for it)
echo "Waiting for job to complete (timeout 300s)..."
kubectl -n $NS wait --for=condition=complete --timeout=300s job/playwright-e2e || {
  echo "Job failed or timed out; dumping logs..."
  kubectl -n $NS logs job/playwright-e2e --tail=200 || true
  exit 1
}

echo "Job completed; grabbing logs:"
kubectl -n $NS logs job/playwright-e2e --tail=400
