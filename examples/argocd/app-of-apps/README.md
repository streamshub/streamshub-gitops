# App-of-Apps Pattern

An ArgoCD ApplicationSet that automatically discovers and deploys all scenarios from this repository.

## How It Works

The ApplicationSet uses a **Git directory generator** to scan `examples/scenarios/` for subdirectories. Each directory automatically becomes an ArgoCD Application:

```
examples/scenarios/
├── basic-kafka/     →  ArgoCD Application "basic-kafka"
├── kafka-mirror/    →  ArgoCD Application "kafka-mirror"
└── kafka-oauth/     →  ArgoCD Application "kafka-oauth"
```

Adding a new scenario directory automatically creates a new ArgoCD Application on the next sync.

## Prerequisites

- ArgoCD installed (see [ArgoCD installation](../../infrastructure/argo-cd/))
- Strimzi or Streams for Apache Kafka operator installed (see [operator installation](../../infrastructure/strimzi-operator/))

## Quick Start

```bash
kubectl apply -f applicationset.yaml
```

## Verify

```bash
# List all generated applications
kubectl get applications -n argocd

# Check ApplicationSet status
kubectl get applicationset streamshub-gitops-scenarios -n argocd
```

## Selective Deployment

To deploy only specific scenarios, modify the `directories` filter in `applicationset.yaml`:

```yaml
generators:
  - git:
      directories:
        - path: examples/scenarios/basic-kafka
        - path: examples/scenarios/kafka-mirror
        # Exclude kafka-oauth
```

## Standalone Alternative

Each scenario also contains its own `argocd/application.yaml` that can be applied independently without the ApplicationSet:

```bash
kubectl apply -f ../scenarios/basic-kafka/argocd/application.yaml
```

## Customization

- **Repository URL**: Update `repoURL` to point to your fork
- **Target revision**: Change `targetRevision` from `HEAD` to a specific branch or tag
- **Sync policy**: Adjust `automated.prune` to `true` if you want ArgoCD to delete resources removed from Git
- **Project**: Change `project` from `default` to a dedicated ArgoCD AppProject for access control
