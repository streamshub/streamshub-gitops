# ArgoCD Installation with Kustomize

## Structure

- `overlays/` - Platform-specific configurations
  - `openshift/` - OpenShift using `openshift-gitops` operator
  - `kubernetes/` - Kubernetes using direct ArgoCD manifests (ARM64 compatible)
- `examples/` - Optional production configurations

## Prerequisites

- **OpenShift**: OLM is built-in
- **Kubernetes**: Nothing

## Quick Start

### OpenShift

```bash
# Install operator via OLM
kubectl apply -k overlays/openshift/operator

# Wait for operator to be ready
kubectl wait --for=condition=Available deployment/openshift-gitops-operator-controller-manager -n openshift-gitops-operator --timeout=300s

# Install ArgoCD instance
kubectl apply -k overlays/openshift/instance
```

### Kubernetes

```bash
# Install ArgoCD
kubectl apply -k overlays/kubernetes
```

## Access ArgoCD

### OpenShift

OpenShift GitOps creates a route automatically:

```bash
# Get the route URL
kubectl get route argocd-server -n argocd -o jsonpath='{.spec.host}'

# Login using openshift auth or Get admin password
kubectl get secret argocd-cluster -n argocd -o jsonpath='{.data.admin\.password}' | base64 -d
```

### Kubernetes

```bash
# Port forward to access locally
kubectl port-forward service/argocd-server -n argocd 8080:443

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

Then open `https://localhost:8080` in your browser.

## Differences Between Platforms

| Feature | OpenShift | Kubernetes |
|---------|-----------|------------|
| Installation | `openshift-gitops` operator (Red Hat) | Direct manifests |
| Namespace | `argocd` | `argocd` |
| Access | OpenShift Route (auto TLS) | Port Forward / Ingress |
| Authentication | OpenShift OAuth integration | Username/password |
| Updates | Operator managed | Manual manifest updates |

## Customization

You can customize the installation by:

1. Modifying the ArgoCD custom resource in the overlays
2. Adding additional configuration patches
