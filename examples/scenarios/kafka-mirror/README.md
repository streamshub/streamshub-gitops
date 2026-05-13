# Kafka Mirroring with MirrorMaker 2

Two Kafka clusters with MirrorMaker 2 replicating data from the source to the target cluster.

## What Gets Deployed

- **Source cluster** (`source`) in namespace `kafka-source`: 3 controllers + 3 brokers
- **Target cluster** (`target`) in namespace `kafka-target`: 3 controllers + 3 brokers
- **MirrorMaker 2** (`mirror`) in namespace `kafka-target`: 2 replicas replicating all topics
- **KafkaUser** `source-mirror-user` on source cluster (read access) and `mirror-user` on target cluster (read/write access)

## Architecture

```
┌─────────────────────┐         ┌─────────────────────┐
│   kafka-source      │         │   kafka-target       │
│                     │         │                     │
│  ┌───────────────┐  │         │  ┌───────────────┐  │
│  │ source cluster│  │────────►│  │ target cluster│  │
│  │ (3 ctrl +     │  │  MM2    │  │ (3 ctrl +     │  │
│  │  3 brokers)   │  │         │  │  3 brokers)   │  │
│  └───────────────┘  │         │  └───────────────┘  │
│                     │         │                     │
│  source-mirror-user │         │  mirror-user (r/w)  │
│  (read)             │         │                     │
└─────────────────────┘         │  MirrorMaker 2      │
                                └─────────────────────┘
```

## MirrorMaker 2 Connectors

| Connector | Purpose |
|-----------|---------|
| Source Connector | Replicates topic data from source to target |
| Heartbeat Connector | Monitors connectivity between clusters |
| Checkpoint Connector | Tracks consumer group offset mapping for failover |

## Prerequisites

- ArgoCD installed (see [ArgoCD installation](../../infrastructure/argo-cd/))
- Strimzi or Streams for Apache Kafka operator deployed via ArgoCD (see [operator installation](../../infrastructure/strimzi-operator/))
- [External Secrets Operator](../../infrastructure/external-secrets-operator/) deployed via ArgoCD for automatic cross-namespace secret replication

## Cross-Namespace Secret Replication

MirrorMaker 2 runs in `kafka-target` but needs access to the source cluster's CA certificate and user credentials from `kafka-source`. This scenario uses the [External Secrets Operator](../../infrastructure/external-secrets-operator/) with the Kubernetes provider to automatically replicate these secrets.

The `secrets/` directory contains:
- **RBAC** — ServiceAccount in `kafka-target` with a Role/RoleBinding granting read access to secrets in `kafka-source`
- **SecretStore** — points to `kafka-source` namespace using the Kubernetes provider
- **ExternalSecrets** — pull `source-cluster-ca-cert` and `source-mirror-user` into `kafka-target`

Secrets replicated automatically:
- `source-cluster-ca-cert` (source cluster CA certificate for TLS trust)
- `source-mirror-user` (TLS credentials for authenticating to the source cluster)

## Deploy via ArgoCD

```bash
kubectl apply -f argocd/application.yaml
```

Or deploy all scenarios at once using the [app-of-apps](../../argocd/app-of-apps/) ApplicationSet.

ArgoCD deploys both clusters, ESO resources, and MirrorMaker 2. Once the source cluster is ready, the External Secrets Operator syncs the required secrets into `kafka-target` and MirrorMaker 2 starts replicating topics.

## Verify

```bash
# Check MirrorMaker 2 status
kubectl get kafkamirrormaker2 mirror -n kafka-target

# Check connector status
kubectl get kafkamirrormaker2 mirror -n kafka-target -o jsonpath='{.status.connectors}' | jq .

# Produce to source, verify on target
kubectl run kafka-producer -ti --image=quay.io/strimzi/kafka:latest-kafka-4.0.0 --rm=true --restart=Never -n kafka-source -- \
  bin/kafka-console-producer.sh --bootstrap-server source-kafka-bootstrap:9092 --topic test-topic

kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:latest-kafka-4.0.0 --rm=true --restart=Never -n kafka-target -- \
  bin/kafka-console-consumer.sh --bootstrap-server target-kafka-bootstrap:9092 --topic source.test-topic --from-beginning
```

## Customization

- **Topic filtering**: Change `topicsPattern` in `mirror-maker/mirror-maker2.yaml` (default: `.*` mirrors all topics)
- **Replicas**: Adjust MirrorMaker 2 replicas for throughput
- **Bidirectional**: Add a second `mirrors` entry to replicate target back to source
- **Cross-cluster**: In production, source and target are typically on separate Kubernetes clusters. Update `bootstrapServers` to use external addresses and configure the ArgoCD Application for multi-cluster deployment.

## Compatibility

These manifests use `kafka.strimzi.io/v1` CRDs and work with both:
- **Strimzi** 1.0.0+ (community)
- **Streams for Apache Kafka** 3.2+ (IBM/Red Hat)
