#!/usr/bin/env bash
# Встановлення ArgoCD у кластер
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

kubectl get ns argocd >/dev/null 2>&1 || kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

kubectl wait --for=condition=Available deployment --all -n argocd --timeout=600s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

echo ">>> ArgoCD готовий. UI: ./scripts/port-forward.sh argocd"
echo ">>> Логін: admin"
echo -n ">>> Пароль: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
