#!/usr/bin/env bash
# Повне розгортання одним скриптом: хост -> кластер -> Kubeflow -> pipeline -> ArgoCD -> застосунок -> звіт
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${GIT_REPO_URL:?Вкажіть GIT_REPO_URL (проєкт має бути запушений у GitHub, гілка main)}"

"$DIR/01-prepare-host.sh"
"$DIR/02-create-cluster.sh"
"$DIR/03-install-kubeflow.sh"
"$DIR/04-run-pipeline.sh"
"$DIR/05-install-argocd.sh"
"$DIR/06-deploy-app.sh"
"$DIR/07-cluster-report.sh"
