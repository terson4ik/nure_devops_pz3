#!/usr/bin/env bash
# Звіт kubectl: поди, контейнери, сервіси, логи pipeline (зберігається в ./reports)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

OUT="$PROJECT_ROOT/reports"
mkdir -p "$OUT"

run() {  # run <ім'я-файлу> <команда...>
  local file="$OUT/$1.txt"
  shift
  { echo "\$ $*"; "$@"; } 2>&1 | tee "$file"
  echo
}

date | tee "$OUT/00-date.txt"
run 01-cluster-info        kubectl cluster-info
run 02-nodes               kubectl get nodes -o wide
run 03-all-pods            kubectl get pods -A -o wide
run 04-running-pods        kubectl get pods -A --field-selector=status.phase=Running
run 05-pods-containers     kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,POD:.metadata.name,PHASE:.status.phase,CONTAINERS:.spec.containers[*].name
run 06-running-containers  kubectl get pods -A -o 'jsonpath={range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{range .status.containerStatuses[?(@.state.running)]}{"    "}{.name}{"\t"}{.image}{"\n"}{end}{end}'
run 07-crictl-containers   docker exec "${CLUSTER_NAME}-control-plane" crictl ps
run 08-services            kubectl get svc -A
run 09-deployments         kubectl get deployments -A
run 10-kubeflow-pods       kubectl get pods -n kubeflow
run 11-user-namespace      kubectl get pods,workflows -n "$KF_PROFILE_NS"
run 12-argocd-apps         kubectl get applications -n argocd
run 13-iris-app            kubectl get all -n "$APP_NS"

echo "=== Логи pod-ів pipeline ($KF_PROFILE_NS) ==="
{
  for pod in $(kubectl -n "$KF_PROFILE_NS" get pods -l workflows.argoproj.io/workflow -o name 2>/dev/null); do
    echo "===== $pod ====="
    kubectl -n "$KF_PROFILE_NS" logs "$pod" --all-containers=true --prefix || true
  done
} 2>&1 | tee "$OUT/14-pipeline-pod-logs.txt"

echo ">>> Звіти збережено в $OUT"
