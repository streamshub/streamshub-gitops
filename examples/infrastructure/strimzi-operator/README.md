# Strimzi / Streams for Apache Kafka Operator Installation

## Structure

- `overlays/` - Platform and product-specific configurations
  - `kubernetes/` - Community Strimzi operator using upstream manifests from GitHub releases
  - `openshift/` - Community Strimzi operator via OLM (community-operators catalog)
  - `streams-for-kafka/` - Streams for Apache Kafka 3.2 operator via OLM (redhat-operators catalog)

## Deploy via ArgoCD

### Kubernetes (Community Strimzi)

```bash
kubectl apply -f overlays/kubernetes/argocd/application.yaml
```

### OpenShift (Community Strimzi)

```bash
kubectl apply -f overlays/openshift/argocd/application.yaml
```

### OpenShift (Streams for Apache Kafka 3.2)

```bash
kubectl apply -f overlays/streams-for-kafka/argocd/application.yaml
```

## Verify Installation

```bash
# Check the operator pod is running
kubectl get pods -n strimzi-operator

# For Streams for Apache Kafka
kubectl get pods -n streams-kafka-operator

# Verify CRDs are installed
kubectl get crd | grep strimzi
```

## Differences Between Platforms

| Feature | Kubernetes | OpenShift (Strimzi) | OpenShift (SFAK) |
|---------|------------|---------------------|------------------|
| Installation | Upstream manifests | OLM (community-operators) | OLM (redhat-operators) |
| Namespace | `strimzi-operator` | `strimzi-operator` | `streams-kafka-operator` |
| Updates | Manual manifest updates | Automatic via OLM | Automatic via OLM |
| Support | Community | Community | IBM/Red Hat commercial support |
| CRD API | `kafka.strimzi.io/v1` | `kafka.strimzi.io/v1` | `kafka.strimzi.io/v1` |

## Customization

- **Watch namespaces**: By default, the operator watches all namespaces. To restrict this, modify the operator deployment environment variables.
- **Resource limits**: Adjust operator resource requests/limits in the deployment manifest (Kubernetes) or via the Subscription config (OLM).
- **Update channel**: Change the `channel` field in the Subscription to pin to a specific version stream.

## Next Steps

Once the operator is running, deploy a Kafka cluster using one of the [scenarios](../../scenarios/).
