# Basic Kafka Cluster

A production-like Apache Kafka cluster running in KRaft mode with 3 controllers and 3 brokers.

## What Gets Deployed

- **Namespace**: `kafka`
- **Kafka cluster** (`my-cluster`): KRaft mode, Kafka 4.2.0
- **KafkaNodePool** `controllers`: 3 replicas, 10Gi storage
- **KafkaNodePool** `brokers`: 3 replicas, 100Gi storage
- **Entity Operator**: Topic Operator + User Operator
- **Cruise Control**: Auto-rebalancing on broker add/remove
- **Kafka Exporter**: Consumer lag metrics
- **JMX Prometheus Exporter**: Broker and Cruise Control metrics via ConfigMap

## Listeners

| Name | Port | Type | TLS | Authentication |
|------|------|------|-----|----------------|
| `plain` | 9092 | internal | No | None |
| `tls` | 9093 | internal | Yes | TLS client certificates |

## Prerequisites

- ArgoCD installed (see [ArgoCD installation](../../argo-cd/))
- Strimzi or Streams for Apache Kafka operator deployed via ArgoCD (see [operator installation](../../operators/strimzi/))

## Deploy via ArgoCD

```bash
kubectl apply -f argocd/application.yaml
```

Or deploy all scenarios at once using the [app-of-apps](../../app-of-apps/) ApplicationSet.

## Verify

```bash
# Check ArgoCD sync status
kubectl get application basic-kafka -n argocd

# Check all pods are running
kubectl get pods -n kafka

# Check Kafka cluster status
kubectl get kafka my-cluster -n kafka

# Check node pools
kubectl get kafkanodepool -n kafka
```

## Connect to the Cluster

```bash
# Internal plain-text bootstrap (from within the cluster)
my-cluster-kafka-bootstrap.kafka.svc:9092

# Internal TLS bootstrap (from within the cluster)
my-cluster-kafka-bootstrap.kafka.svc:9093
```

## Customization

- **Replicas**: Adjust `spec.replicas` in `controllers.yaml` and `brokers.yaml`
- **Storage**: Change `size` in the storage configuration of each node pool
- **Resources**: Modify CPU/memory requests and limits per node pool
- **Listeners**: Add additional listeners (e.g., `type: route` for OpenShift external access, `type: nodeport` or `type: loadbalancer` for Kubernetes)
- **Retention**: Adjust `log.retention.hours` in `kafka.yaml` (default: 7 days)

## Compatibility

These manifests use `kafka.strimzi.io/v1` CRDs and work with both:
- **Strimzi** 1.0.0+ (community)
- **Streams for Apache Kafka** 3.2+ (Red Hat)
