#!/bin/sh
set -eu pipefail

# Volume
echo "[cloud-init.sh] Starting volume mounting"
while [ ! -b /dev/sdb ]; do sleep 1; done
if ! blkid /dev/sdb; then mkfs.ext4 /dev/sdb; fi
mkdir -p /var/lib/rancher
UUID=$(blkid -s UUID -o value /dev/sdb)
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /var/lib/rancher ext4 defaults,_netdev 0 2" >> /etc/fstab
mount -a

# Verify mount before proceeding
echo "[cloud-init.sh] Verifying volume mounting"
if ! mountpoint -q /var/lib/rancher; then
  echo "ERROR: /var/lib/rancher is not mounted, aborting" >&2
  exit 1
fi

# k3s
echo "[cloud-init.sh] Starting k3s install"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb --write-kubeconfig-mode 644" sh -
until kubectl get nodes 2>/dev/null | grep -q Ready; do sleep 5; done

# Helm
echo "[cloud-init.sh] Starting helm install"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

# Argo CD
echo "[cloud-init.sh] Starting argocd install"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --wait