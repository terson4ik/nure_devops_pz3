#!/usr/bin/env bash
# Створення kind-кластера
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo ">>> Кластер '$CLUSTER_NAME' вже існує"
else
  kind create cluster --name "$CLUSTER_NAME" --config "$PROJECT_ROOT/kind/kind-config.yaml"
fi

kind get kubeconfig --name "$CLUSTER_NAME" > "$KUBECONFIG"
echo ">>> KUBECONFIG=$KUBECONFIG"

# Опційно
if [[ "${CREATE_REGCRED:-0}" == "1" && -f "$HOME/.docker/config.json" ]]; then
  kubectl create secret generic regcred \
    --from-file=.dockerconfigjson="$HOME/.docker/config.json" \
    --type=kubernetes.io/dockerconfigjson \
    --dry-run=client -o yaml | kubectl apply -f -
fi

kubectl cluster-info
kubectl get nodes -o wide
