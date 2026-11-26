#!/usr/bin/env bash
# Збірка образу, завантаження в kind та створення ArgoCD Application (GitOps)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

: "${GIT_REPO_URL:?Вкажіть GIT_REPO_URL (публічний GitHub-репозиторій з цим проєктом, гілка main)}"

echo ">>> Збірка образу $APP_IMAGE"
docker build -t "$APP_IMAGE" "$PROJECT_ROOT/app"

echo ">>> Завантаження образу в kind"
if ! kind load docker-image "$APP_IMAGE" --name "$CLUSTER_NAME"; then
  docker save "$APP_IMAGE" -o "$PROJECT_ROOT/.build/app-image.tar"
  kind load image-archive "$PROJECT_ROOT/.build/app-image.tar" --name "$CLUSTER_NAME"
fi

echo ">>> Створення ArgoCD Application (repo: $GIT_REPO_URL)"
sed "s|REPLACE_REPO_URL|${GIT_REPO_URL}|g" "$PROJECT_ROOT/argocd/application.yaml" | kubectl apply -f -

echo ">>> Очікування синхронізації (потрібно, щоб deploy/ уже був запушений у GitHub)"
for _ in $(seq 1 40); do
  status="$(kubectl -n argocd get application iris-api \
    -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)"
  echo "    iris-api: ${status:-unknown}"
  [[ "$status" == "Synced/Healthy" ]] && break
  sleep 10
done

kubectl -n "$APP_NS" get all
