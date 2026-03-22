#!/bin/sh
set -eu pipefail

# k3s
echo "[cloud-init.sh] Starting k3s install"
export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -
until kubectl cluster-info 2>/dev/null; do sleep 5; done
until kubectl get nodes 2>/dev/null | grep -q Ready; do sleep 5; done

# Helm
echo "[cloud-init.sh] Starting helm install"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

# Argo CD
echo "[cloud-init.sh] Starting argocd install"
kubectl get namespace argocd || kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --wait

# Bootstrap Argo root app
echo "[cloud-init.sh] Applying root app"
kubectl apply -f https://raw.githubusercontent.com/greensebastian/infra-oracle/main/apps/root/app.yaml