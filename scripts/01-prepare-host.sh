#!/usr/bin/env bash
# Підготовка хоста: параметри ядра + перевірка інструментів
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

echo ">>> Налаштування inotify (потрібно для великої кількості pod-ів)"
sudo sysctl -w fs.inotify.max_user_instances=2280
sudo sysctl -w fs.inotify.max_user_watches=1255360
printf 'fs.inotify.max_user_instances=2280\nfs.inotify.max_user_watches=1255360\n' \
  | sudo tee /etc/sysctl.d/99-kubeflow.conf >/dev/null

echo ">>> Перевірка інструментів"
missing=0
for bin in docker kind kubectl kustomize git curl; do
  if command -v "$bin" >/dev/null 2>&1; then
    printf '  [ok] %s\n' "$bin"
  else
    printf '  [!!] %s не знайдено\n' "$bin"
    missing=1
  fi
done
docker info >/dev/null 2>&1 || { echo "  [!!] Docker daemon недоступний (systemctl enable --now docker, група docker)"; missing=1; }
[[ -x "$PYTHON_BIN" ]] || { echo "  [!!] Немає $PYTHON_BIN (створіть venv, див. README)"; missing=1; }
[[ "$missing" -eq 0 ]] || exit 1
echo ">>> Усе готово"
