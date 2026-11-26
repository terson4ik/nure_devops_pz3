#!/usr/bin/env bash
# Перевірка всього стенда: PASS/FAIL по кожному етапу
set -u
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

PASS=0
FAIL=0

check() {  # check "<опис>" <функція|команда...>
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  [PASS] %s\n' "$desc"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s\n' "$desc"
    FAIL=$((FAIL + 1))
  fi
}

section() { printf '\n=== %s ===\n' "$1"; }

# ---------- допоміжні перевірки ----------
cluster_exists() { kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; }

nodes_ready() {
  [[ -n "$(kubectl get nodes --no-headers)" ]] && ! kubectl get nodes --no-headers | grep -qv ' Ready'
}

no_bad_pods() {  # pod-и користувацького ns (старі запуски pipeline) не враховуємо
  [[ -z "$(kubectl get pods -A --no-headers \
    | awk -v ns="$KF_PROFILE_NS" '$1!=ns && $4!="Running" && $4!="Completed"')" ]]
}

all_ready() {
  [[ -z "$(kubectl get pods -A --no-headers \
    | awk -v ns="$KF_PROFILE_NS" '$1!=ns && $4=="Running" {split($3,a,"/"); if (a[1]!=a[2]) print}')" ]]
}

kubeflow_gateway() {
  kubectl -n istio-system port-forward svc/istio-ingressgateway 18080:80 >/dev/null 2>&1 &
  local pf=$! code
  sleep 4
  code="$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' http://localhost:18080/)"
  kill "$pf" 2>/dev/null
  wait "$pf" 2>/dev/null
  [[ "$code" != "000" ]]
}

pipeline_succeeded() {
  kubectl -n "$KF_PROFILE_NS" get workflows -o jsonpath='{.items[*].status.phase}' | grep -qw Succeeded
}

pipeline_logs_contain() {  # pipeline_logs_contain <regex>
  local pod logs
  for pod in $(kubectl -n "$KF_PROFILE_NS" get pods -l workflows.argoproj.io/workflow -o name 2>/dev/null); do
    logs="$(kubectl -n "$KF_PROFILE_NS" logs "$pod" --all-containers=true 2>/dev/null)"
    if grep -qE "$1" <<<"$logs"; then
      return 0
    fi
  done
  return 1
}

argocd_synced() {
  [[ "$(kubectl -n argocd get application iris-api \
    -o jsonpath='{.status.sync.status}/{.status.health.status}')" == "Synced/Healthy" ]]
}

app_rolled_out() { kubectl -n "$APP_NS" rollout status deployment/iris-api --timeout=60s; }

app_predicts() {
  kubectl -n "$APP_NS" port-forward svc/iris-api 18000:80 >/dev/null 2>&1 &
  local pf=$! resp
  sleep 4
  resp="$(curl -s --max-time 10 -X POST http://localhost:18000/predict \
    -H 'Content-Type: application/json' \
    -d '{"sepal_length":5.1,"sepal_width":3.5,"petal_length":1.4,"petal_width":0.2}')"
  kill "$pf" 2>/dev/null
  wait "$pf" 2>/dev/null
  grep -q setosa <<<"$resp"
}

git_pushed() {
  git -C "$PROJECT_ROOT" rev-parse origin/main >/dev/null 2>&1 \
    && [[ -z "$(git -C "$PROJECT_ROOT" log origin/main..HEAD 2>/dev/null)" ]]
}

# ---------- перевірки ----------
section "1. Інфраструктура"
check "Docker daemon працює" docker info
check "kind-кластер '$CLUSTER_NAME' існує" cluster_exists
check "Усі вузли Ready" nodes_ready

section "2. Kubeflow"
for ns in cert-manager istio-system auth oauth2-proxy kubeflow "$KF_PROFILE_NS"; do
  check "namespace $ns існує" kubectl get ns "$ns"
done
check "Istio ingressgateway (service)" kubectl -n istio-system get svc istio-ingressgateway
check "Dex (логін)" kubectl -n auth get deployment dex
check "Kubeflow Pipelines API (ml-pipeline)" kubectl -n kubeflow get deployment ml-pipeline
check "Kubeflow Pipelines UI (ml-pipeline-ui)" kubectl -n kubeflow get deployment ml-pipeline-ui
check "Немає pod-ів у помилковому стані" no_bad_pods
check "Усі Running pod-и мають READY n/n" all_ready
check "Шлюз Kubeflow відповідає по HTTP" kubeflow_gateway

section "3. ML Ops pipeline"
check "Скомпільований pipelines/iris_pipeline.yaml існує" test -s "$PROJECT_ROOT/pipelines/iris_pipeline.yaml"
check "Є Workflow зі статусом Succeeded" pipeline_succeeded
check "У логах є метрики (accuracy=)" pipeline_logs_contain 'accuracy='
check "У логах є передбачення (=== PREDICTIONS ===)" pipeline_logs_contain '=== PREDICTIONS ==='

section "4. ArgoCD + GitOps"
check "ArgoCD server працює" kubectl -n argocd get deployment argocd-server
check "Application iris-api: Synced/Healthy" argocd_synced
check "Deployment iris-api розгорнуто (rollout)" app_rolled_out
check "iris-api відповідає на /predict (setosa)" app_predicts

section "5. CI/CD та репозиторій"
check "Файл .github/workflows/ci.yaml існує" test -f "$PROJECT_ROOT/.github/workflows/ci.yaml"
check "Remote origin налаштовано" git -C "$PROJECT_ROOT" remote get-url origin
check "Усі коміти запушені в origin/main" git_pushed
check "Звіти kubectl збережені в ./reports" test -s "$PROJECT_ROOT/reports/03-all-pods.txt"

printf '\nПідсумок: PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
