# App-of-Apps Pattern

An ArgoCD ApplicationSet that deploys all infrastructure operators and scenarios from this repository with a single command.

## Platform-Specific Variants

Since infrastructure operators differ between platforms (OLM on OpenShift vs upstream manifests on Kubernetes), there are platform-specific ApplicationSets:

- `openshift/` — deploys Streams for Apache Kafka, RHBK, ESO (Red Hat), and all scenarios
- `kubernetes/` — deploys community Strimzi, Keycloak, and all scenarios

## Quick Start

### OpenShift

```bash
kubectl apply -f openshift/applicationset.yaml
```

### Kubernetes

```bash
kubectl apply -f kubernetes/applicationset.yaml
```

## What Gets Deployed

### OpenShift

| Application | Path |
|-------------|------|
| `streams-for-apache-kafka-operator` | `operators/strimzi/overlays/streams-for-kafka` |
| `rhbk-operator` | `operators/keycloak/overlays/rhbk` |
| `external-secrets-operator` | `operators/external-secrets/overlays/openshift` |
| `basic-kafka` | `scenarios/basic-kafka` |
| `kafka-mirror` | `scenarios/kafka-mirror` |
| `kafka-oauth` | `scenarios/kafka-oauth` |

### Kubernetes

| Application | Path |
|-------------|------|
| `strimzi-operator` | `operators/strimzi/overlays/kubernetes` |
| `keycloak-operator` | `operators/keycloak/overlays/kubernetes` |
| `basic-kafka` | `scenarios/basic-kafka` |
| `kafka-mirror` | `scenarios/kafka-mirror` |
| `kafka-oauth` | `scenarios/kafka-oauth` |

## Selective Deployment

To deploy only specific components, modify the `generators` section:
- Remove entries from the `list` generator to skip specific operators
- Add `exclude` entries to the `git` generator to skip specific scenarios

## Prerequisites

- ArgoCD installed (see [ArgoCD installation](../argo-cd/))
- The `streamshub` AppProject must exist (created as part of the ArgoCD instance setup)
