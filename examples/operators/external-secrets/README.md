# External Secrets Operator

The [External Secrets Operator](https://external-secrets.io/) synchronizes secrets from external sources into Kubernetes Secrets. In this repository, it is used with the **Kubernetes provider** to replicate Strimzi-managed secrets across namespaces (e.g., cluster CA certificates and user credentials for MirrorMaker 2).

## Structure

- `overlays/` - Platform-specific configurations
  - `kubernetes/` - Community External Secrets Operator deployed via ArgoCD Application pointing to the upstream Helm chart
  - `openshift/` - External Secrets Operator for Red Hat OpenShift via OLM (`redhat-operators` catalog, `stable-v1` channel)

## Deploy via ArgoCD

### Kubernetes

```bash
kubectl apply -f overlays/kubernetes/application.yaml
```

ArgoCD installs the External Secrets Operator directly from the upstream Helm chart at `charts.external-secrets.io`.

### OpenShift

```bash
kubectl apply -f overlays/openshift/argocd/application.yaml
```

## Verify Installation

```bash
kubectl get pods -n external-secrets-operator

# Verify CRDs are installed
kubectl get crd | grep external-secrets
```

## Differences Between Platforms

| Feature | Kubernetes | OpenShift |
|---------|------------|-----------|
| Installation | ArgoCD + Helm chart | OLM (redhat-operators) |
| Namespace | `external-secrets-operator` | `external-secrets-operator` |
| Support | Community | Red Hat commercial support |
| Updates | Update `targetRevision` in Application | Automatic via OLM |

## How It Works

The External Secrets Operator uses a `SecretStore` with the Kubernetes provider to read secrets from a remote namespace and create local copies via `ExternalSecret` resources. See the [kafka-mirror scenario](../../scenarios/kafka-mirror/) for a working example.
