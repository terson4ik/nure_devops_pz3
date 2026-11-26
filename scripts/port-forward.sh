#!/usr/bin/env bash
# Доступ до UI: ./scripts/port-forward.sh [kubeflow|argocd|app]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

case "${1:-kubeflow}" in
  kubeflow)
    echo "Kubeflow: http://localhost:8080  (user@example.com / 12341234)"
    exec kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
    ;;
  argocd)
    echo "ArgoCD: https://localhost:8081  (admin / пароль з 05-install-argocd.sh)"
    exec kubectl port-forward svc/argocd-server -n argocd 8081:443
    ;;
  app)
    echo "iris-api: http://localhost:8000/docs"
    exec kubectl port-forward svc/iris-api -n "$APP_NS" 8000:80
    ;;
  *)
    echo "Використання: $0 [kubeflow|argocd|app]"
    exit 1
    ;;
esac
