# infra-oracle

This repo contains bootstrapping, IaC, and k8s configuration for hosting my applications in oracle cloud free tier. Some features:

1. Oracle free tier VM and networking with static IP terraformed.
2. Boot scripts to launch k3s and ArgoCD into that VM.
3. Completely automatic bootstrapping from argo k8s definitions in this repo.
4. ArgoCD itself.
5. Ingress.
6. Istio networking with Gateway API.
7. Routing and TLS termination with lets-encrypt.
8. Any other apps or k8s resources needed, automatically deployed from this repo.

Deployed apps:

1. https://argo.oci.sebastiangreen.se
2. https://satisfactory.oci.sebastiangreen.se
