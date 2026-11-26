#!/usr/bin/env bash
# Компіляція та запуск ML Ops pipeline у Kubeflow
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

PF_PID=""
cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

if ! curl -s -o /dev/null --max-time 3 http://localhost:8080; then
  echo ">>> port-forward istio-ingressgateway -> localhost:8080"
  kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 \
    > "$PROJECT_ROOT/.build/port-forward.log" 2>&1 &
  PF_PID=$!
  for _ in $(seq 1 30); do
    curl -s -o /dev/null --max-time 2 http://localhost:8080 && break
    sleep 2
  done
fi

echo ">>> Компіляція pipeline"
"$PYTHON_BIN" "$PROJECT_ROOT/pipelines/iris_pipeline.py"

echo ">>> Запуск pipeline"
"$PYTHON_BIN" "$PROJECT_ROOT/pipelines/run_pipeline.py"
