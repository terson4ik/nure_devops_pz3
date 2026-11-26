#!/usr/bin/env bash
# Встановлення Kubeflow (single command через kustomize), lite-режим за замовчуванням
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

MAX_TRIES="${MAX_TRIES:-30}"

if [[ ! -d "$KF_DIR/.git" ]]; then
  echo ">>> Клонування $KF_REPO_URL ($KF_REF)"
  git clone --depth 1 --branch "$KF_REF" "$KF_REPO_URL" "$KF_DIR"
fi

cd "$KF_DIR"

if [[ "$KF_LITE" == "1" ]]; then
  echo ">>> Lite-режим: вимикаю важкі компоненти в example/kustomization.yaml"
  # коментує лише рядки виду "- ../..." (повторний запуск безпечний)
  sed -i -E "\@^[[:space:]]*-[[:space:]]+\.\./.*(${KF_EXCLUDE})@ s/^/# /" example/kustomization.yaml
fi

echo ">>> Увімкнені ресурси в example/kustomization.yaml:"
grep -nE '^[[:space:]]*-[[:space:]]+\.\./' example/kustomization.yaml || true

echo ">>> Перевірка kustomize build"
kustomize build example > /dev/null || {
  echo "kustomize build не проходить: перевірте example/kustomization.yaml (можливо, лишилась залежність від вимкненого компонента)"
  exit 1
}

ok=0
for i in $(seq 1 "$MAX_TRIES"); do
  echo ">>> Застосування маніфестів, спроба $i/$MAX_TRIES"
  if kustomize build example | kubectl apply --server-side --force-conflicts -f -; then
    ok=1
    break
  fi
  echo "Повторна спроба застосувати ресурси через 20 с..."
  sleep 20
done
[[ "$ok" -eq 1 ]] || { echo "Не вдалося встановити Kubeflow"; exit 1; }

echo ">>> Очікування профілю користувача ($KF_PROFILE_NS)"
for _ in $(seq 1 60); do
  kubectl get ns "$KF_PROFILE_NS" >/dev/null 2>&1 && break
  sleep 10
done

echo ">>> Очікування готовності deployment-ів"
for ns in cert-manager istio-system auth oauth2-proxy knative-serving kserve kubeflow kubeflow-system; do
  kubectl get ns "$ns" >/dev/null 2>&1 || continue
  kubectl wait --for=condition=Available deployment --all -n "$ns" --timeout=900s \
    || echo "WARN: не всі deployment-и в $ns готові"
done

kubectl get pods -A
echo ">>> Kubeflow встановлено. UI: ./scripts/port-forward.sh kubeflow"
