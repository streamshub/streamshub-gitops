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

- ArgoCD installed (see [ArgoCD installation](../../argo-cd/))
- Strimzi or Streams for Apache Kafka operator deployed via ArgoCD (see [operator installation](../../operators/strimzi/))
- [External Secrets Operator](../../operators/external-secrets/) deployed via ArgoCD for automatic cross-namespace secret replication

## Cross-Namespace Secret Replication

MirrorMaker 2 runs in `kafka-target` but needs access to the source cluster's CA certificate and user credentials from `kafka-source`. This scenario uses the [External Secrets Operator](../../operators/external-secrets/) with the Kubernetes provider to automatically replicate these secrets.

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

Or deploy all scenarios at once using the [app-of-apps](../../app-of-apps/) ApplicationSet.

ArgoCD deploys both clusters, ESO resources, and MirrorMaker 2. Once the source cluster is ready, the External Secrets Operator syncs the required secrets into `kafka-target` and MirrorMaker 2 starts replicating topics.

## Verify

```bash
# Check MirrorMaker 2 status
kubectl get kafkamirrormaker2 mirror -n kafka-target

# Check connector status
kubectl get kafkamirrormaker2 mirror -n kafka-target -o jsonpath='{.status.connectors}' | jq .

# Produce to source, verify on target
kubectl run kafka-producer -ti --image=quay.io/strimzi/kafka:latest-kafka-4.2.0 --rm=true --restart=Never -n kafka-source -- \
  bin/kafka-console-producer.sh --bootstrap-server source-kafka-bootstrap:9092 --topic test-topic

kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:latest-kafka-4.2.0 --rm=true --restart=Never -n kafka-target -- \
  bin/kafka-console-consumer.sh --bootstrap-server target-kafka-bootstrap:9092 --topic source.test-topic --from-beginning
```

Alternatively, use [strimzi/test-clients](https://github.com/strimzi/test-clients) Jobs:

```bash
# Produce 10 messages to the source cluster
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mirror-producer
  namespace: kafka-source
spec:
  backoffLimit: 0
  template:
    spec:
      containers:
        - name: producer
          image: quay.io/strimzi-test-clients/test-clients:latest-kafka-4.2.0
          env:
            - name: BOOTSTRAP_SERVERS
              value: source-kafka-bootstrap:9092
            - name: TOPIC
              value: test-topic
            - name: MESSAGE_COUNT
              value: "10"
            - name: MESSAGE
              value: "hello-mirror"
            - name: PRODUCER_ACKS
              value: "all"
            - name: CLIENT_TYPE
              value: KafkaProducer
      restartPolicy: Never
EOF

# Consume mirrored messages from the target cluster
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mirror-consumer
  namespace: kafka-target
spec:
  backoffLimit: 0
  template:
    spec:
      containers:
        - name: consumer
          image: quay.io/strimzi-test-clients/test-clients:latest-kafka-4.2.0
          env:
            - name: BOOTSTRAP_SERVERS
              value: target-kafka-bootstrap:9092
            - name: TOPIC
              value: source.test-topic
            - name: MESSAGE_COUNT
              value: "10"
            - name: GROUP_ID
              value: mirror-test-group
            - name: CLIENT_TYPE
              value: KafkaConsumer
      restartPolicy: Never
EOF

# Check results
kubectl wait --for=condition=complete job/mirror-producer -n kafka-source --timeout=60s
kubectl logs job/mirror-producer -n kafka-source
kubectl wait --for=condition=complete job/mirror-consumer -n kafka-target --timeout=60s
kubectl logs job/mirror-consumer -n kafka-target

# Cleanup
kubectl delete job mirror-producer -n kafka-source
kubectl delete job mirror-consumer -n kafka-target
```

## Customization

- **Topic filtering**: Change `topicsPattern` in `mirror-maker/mirror-maker2.yaml` (default: `.*` mirrors all topics)
- **Replicas**: Adjust MirrorMaker 2 replicas for throughput
- **Bidirectional**: Add a second `mirrors` entry to replicate target back to source
- **Cross-cluster**: In production, source and target are typically on separate Kubernetes clusters. Update `bootstrapServers` to use external addresses and configure the ArgoCD Application for multi-cluster deployment.

## Compatibility

These manifests use `kafka.strimzi.io/v1` CRDs and work with both:
- **Strimzi** 1.0.0+ (community)
- **Streams for Apache Kafka** 3.2+ (Red Hat)
