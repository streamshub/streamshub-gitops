# Keycloak / Red Hat Build of Keycloak (RHBK) Operator Installation

## Structure

- `overlays/` - Platform and product-specific configurations
  - `kubernetes/` - Community Keycloak operator (v26.6.2) using upstream CRDs and operator manifests
  - `rhbk/` - Red Hat Build of Keycloak operator via OLM (stable-v26.0 channel)

## Deploy via ArgoCD

### Kubernetes (Community Keycloak)

```bash
kubectl apply -f overlays/kubernetes/argocd/application.yaml
```

### OpenShift (RHBK)

```bash
kubectl apply -f overlays/rhbk/argocd/application.yaml
```

## Verify Installation

```bash
# Kubernetes
kubectl get pods -n keycloak-operator

# OpenShift (RHBK)
kubectl get pods -n rhbk-operator

# Verify CRDs are installed
kubectl get crd | grep keycloak
```

## Differences Between Platforms

| Feature | Kubernetes | OpenShift (RHBK) |
|---------|------------|------------------|
| Installation | Upstream manifests | OLM (redhat-operators) |
| Namespace | `keycloak-operator` | `rhbk-operator` |
| Updates | Manual manifest updates | Automatic via OLM |
| Support | Community | Red Hat commercial support |
| CRD API | `k8s.keycloak.org/v2alpha1` | `k8s.keycloak.org/v2alpha1` |

## Next Steps

Once the operator is running, deploy a Keycloak instance as part of the [kafka-oauth scenario](../../scenarios/kafka-oauth/).
