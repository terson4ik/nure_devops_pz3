#!/usr/bin/env bash
# Видалення кластера
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
kind delete cluster --name "$CLUSTER_NAME"
rm -f "$KUBECONFIG"
