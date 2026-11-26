#!/usr/bin/env bash
# Спільні змінні для всіх скриптів (підключається через `source`)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT

export CLUSTER_NAME="${CLUSTER_NAME:-kubeflow}"
export KUBECONFIG="${KUBECONFIG_FILE:-$PROJECT_ROOT/.kube/kubeflow-config}"

export KF_REPO_URL="${KF_REPO_URL:-https://github.com/kubeflow/community-distribution.git}"
export KF_REF="${KF_REF:-26.03.1}"
export KF_DIR="${KF_DIR:-$PROJECT_ROOT/.build/kubeflow-manifests}"
export KF_PROFILE_NS="${KF_PROFILE_NS:-kubeflow-user-example-com}"

# Lite-режим: вимикаємо важкі компоненти, які не потрібні для pipeline (KF_LITE=0 -> повний Kubeflow)
export KF_LITE="${KF_LITE:-1}"
export KF_EXCLUDE="${KF_EXCLUDE:-applications/(katib|trainer|spark|hub|notebooks-v1|kserve)|common/knative}"

export ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"
export APP_NS="${APP_NS:-iris-app}"
export APP_IMAGE="${APP_IMAGE:-iris-api:0.1.0}"

export PYTHON_BIN="${PYTHON_BIN:-$PROJECT_ROOT/.venv/bin/python}"

mkdir -p "$PROJECT_ROOT/.kube" "$PROJECT_ROOT/.build" "$PROJECT_ROOT/reports"
