+++
title = 'Deploying Kafka with ArgoCD'
+++

The [introduction](../introduction/_index.md) covered why GitOps matters.
This document shows what it looks like in practice — deploying Apache Kafka infrastructure entirely through ArgoCD, from operators to running clusters.

## How deployment works

Everything in this repository is an ArgoCD Application.
An Application tells ArgoCD: "watch this directory in Git, and keep the cluster in sync with what's there."

When you apply an Application, ArgoCD reads the Kustomize manifests from the specified directory, renders them, and creates the Kubernetes resources.
If someone changes a file in the repository, ArgoCD detects the change and updates the cluster.
If someone changes something directly on the cluster, ArgoCD detects the drift and corrects it.

This means the Git repository is always the source of truth.
There is no need to run `kubectl apply` on individual manifests, no scripts to remember, no runbooks to follow.

## The deployment flow

The only manual step is installing ArgoCD itself.
After that, every operator and every Kafka scenario is deployed by applying a single YAML file — the ArgoCD Application.

All commands below are run from the repository root.

1. **Install ArgoCD** (manual, one-time) — `kubectl apply -k <PATH_TO_OVERLAY>`
2. **Deploy operators** — one `kubectl apply -f <path>/application.yaml` per operator (Strimzi, Keycloak, ESO)
3. **Deploy scenarios** — one `kubectl apply -f <path>/application.yaml` per scenario (basic-kafka, kafka-mirror, kafka-oauth)

Or skip steps 2 and 3 entirely and deploy everything at once with the app-of-apps ApplicationSet.

### Step 1: ArgoCD bootstrap

ArgoCD is the one component that can't deploy itself.
The `examples/argo-cd/` directory contains Kustomize overlays for OpenShift and Kubernetes.

On OpenShift, the install is two steps — the operator and then the instance:

```bash
kubectl apply -k examples/argo-cd/overlays/openshift/operator
kubectl apply -k examples/argo-cd/overlays/openshift/instance
```

The OpenShift overlay includes two important configurations:
- `ARGOCD_CLUSTER_CONFIG_NAMESPACES=argocd` on the operator subscription, which grants the ArgoCD instance cluster-scope permissions.
- A `streamshub` AppProject with `clusterResourceWhitelist`, which allows ArgoCD to manage cluster-scoped resources like Namespaces.

On Kubernetes:

```bash
kubectl apply -k examples/argo-cd/overlays/kubernetes
```

### Step 2: Deploy operators

Each operator has an ArgoCD Application file.
Applying it tells ArgoCD to install and manage the operator.

For example, deploying the Strimzi operator on OpenShift:

```bash
kubectl apply -f examples/operators/strimzi/overlays/streams-for-kafka/argocd/application.yaml
```

That single command creates the namespace, the OLM Subscription, the OperatorGroup, and starts the operator.
ArgoCD keeps it in sync — if someone accidentally deletes the Subscription, ArgoCD recreates it.

The same pattern works for every operator:

```bash
# Keycloak / RHBK (needed for the OAuth scenario)
kubectl apply -f examples/operators/keycloak/overlays/rhbk/argocd/application.yaml

# External Secrets Operator (needed for the mirror scenario)
kubectl apply -f examples/operators/external-secrets/overlays/openshift/argocd/application.yaml
```

### Step 3: Deploy scenarios

Scenarios work exactly the same way — each is an ArgoCD Application:

```bash
kubectl apply -f examples/scenarios/basic-kafka/argocd/application.yaml
```

ArgoCD creates the namespace, deploys the Kafka cluster, node pools, metrics configuration, and all supporting resources.
The Strimzi operator then takes over and creates the actual broker and controller pods.

### Deploying everything at once

Instead of applying Applications one by one, the app-of-apps pattern deploys all operators and scenarios with a single command.
The ApplicationSet uses a combination of a list generator (for operators) and a Git directory generator (for scenarios):

```bash
# OpenShift with Streams for Apache Kafka + RHBK
kubectl apply -f examples/app-of-apps/openshift/applicationset.yaml

# Kubernetes with community Strimzi + Keycloak
kubectl apply -f examples/app-of-apps/kubernetes/applicationset.yaml
```

Adding a new scenario directory under `examples/scenarios/` automatically creates a new ArgoCD Application on the next sync.

## What the scenarios deploy

### Basic Kafka

A single Kafka cluster in KRaft mode with three controllers and three brokers.
Includes Cruise Control for automatic rebalancing, Entity Operator for managing topics and users as custom resources, and JMX Prometheus metrics.

Two listeners: plain-text on port 9092 and TLS with client certificate authentication on port 9093.

### Kafka Mirror

Two independent Kafka clusters with MirrorMaker 2 replicating all topics from source to target.

This scenario demonstrates a practical Kubernetes challenge: MirrorMaker 2 runs in the `kafka-target` namespace but needs TLS credentials from `kafka-source`.
The External Secrets Operator solves this by automatically syncing secrets between namespaces.
A `SecretStore` reads from `kafka-source`, and `ExternalSecret` resources pull the CA certificate and user credentials into `kafka-target`.
If the source cluster rotates its CA certificate, the change propagates automatically.

### Kafka OAuth

A complete OAuth 2.0 setup: Keycloak as the OIDC provider with a Kafka-specific realm, and a Kafka cluster with token-based authentication on the TLS listener.

Strimzi v1 replaced the built-in `type: oauth` listener with `type: custom`.
The OAuth libraries remain bundled in the Kafka images — only the API changed.
The JAAS configuration tells Kafka to validate JWT tokens against Keycloak's JWKS endpoint.

The Keycloak operator is installed into the `keycloak` namespace, and the Keycloak instance is deployed in the same namespace.
This is important because the Keycloak operator watches only its own namespace by default.

The realm includes test users and OAuth clients.
You can test the setup using [strimzi/test-clients](https://github.com/strimzi/test-clients) Jobs that authenticate via client credentials flow.
See the [kafka-oauth README](../../examples/scenarios/kafka-oauth/README.md#obtain-a-token-and-produce-messages) for full producer and consumer examples.

## Making changes

The power of this setup is what happens after the initial deployment.

### Scaling brokers

To add a broker, change `replicas: 3` to `replicas: 4` in `brokers.yaml`, commit, and push.
ArgoCD detects the change, updates the KafkaNodePool, and Strimzi creates the new broker pod.
Cruise Control is configured with `autoRebalance` for `add-brokers` and `remove-brokers` modes, so partitions are automatically redistributed when the broker count changes.
A `KafkaRebalance` resource is also included for on-demand rebalancing.

### Updating configuration

To change a Kafka setting like retention time, edit `kafka.yaml`, commit, and push.
ArgoCD syncs the change, and the Strimzi operator performs a rolling restart of the brokers.

### Adding a new scenario

Create a new directory under `examples/scenarios/` with a `kustomization.yaml` and the Kafka resources.
If you're using the app-of-apps ApplicationSet, ArgoCD automatically discovers it and creates a new Application.

Example structure for a new scenario:

```
examples/scenarios/my-scenario/
├── kustomization.yaml
├── namespace.yaml
├── kafka.yaml
├── brokers.yaml
├── controllers.yaml
└── argocd/
    └── application.yaml
```

Minimal `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - controllers.yaml
  - brokers.yaml
  - kafka.yaml
```

## Community and product support

Our current examples are based on Strimzi 1.0.0 and its v1 API.
This API version is also available within Streams for Apache Kafka (SfAK) 3.2.0, but the storage version is still v1beta2.
Despite that, the examples work with both of these projects/products.
The only difference is which operator you install.

| Component | Community | Product |
|-----------|-----------|---------|
| Kafka operator | Strimzi | Streams for Apache Kafka (`amq-streams`) |
| Identity provider | Keycloak | Red Hat Build of Keycloak (`rhbk-operator`) |
| Secret management | ESO (Helm chart) | ESO for Red Hat OpenShift (`openshift-external-secrets-operator`) |

Switching between community and product is a matter of deploying a different operator Application.
The scenarios themselves don't change.

## What's next

These scenarios cover the foundational Kafka patterns.
We plan to add the following example scenarios:

- **KafkaConnect with Debezium** for change data capture
- **StreamsHub Console** for Kafka cluster management UI
- **Kroxylicious** for Kafka proxy with encryption and schema enforcement
- **Monitoring** with Prometheus and Grafana dashboards
