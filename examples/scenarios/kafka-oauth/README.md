# Kafka with OAuth/OIDC Authentication

A self-contained scenario deploying Keycloak as the OIDC identity provider and a Kafka cluster with OAuth 2.0 token-based authentication using the Strimzi `type: custom` listener configuration.

## What Gets Deployed

### Keycloak (namespace: `keycloak`)

- **PostgreSQL** database (StatefulSet, 5Gi storage)
- **Keycloak** instance (1 replica, HTTP mode)
- **Realm** `kafka` with:
  - Roles: `kafka-admin`, `kafka-producer`, `kafka-consumer`
  - Users: `kafka-admin`, `producer-user`, `consumer-user`
  - Clients: `kafka-broker` (for Kafka token validation), `kafka-client` (for applications)

### Kafka (namespace: `kafka-oauth`)

- **Kafka cluster** (`my-cluster`): KRaft mode, Kafka 4.2.0
- **KafkaNodePool** `controllers`: 3 replicas, 10Gi storage
- **KafkaNodePool** `brokers`: 3 replicas, 100Gi storage
- **OAuth listener** on port 9093 using `type: custom` with OAUTHBEARER SASL
- **Entity Operator**: Topic Operator + User Operator
- **Cruise Control**: Auto-rebalancing

## Architecture

```
┌──────────────────────┐        ┌──────────────────────┐
│  keycloak namespace  │        │  kafka-oauth ns      │
│                      │        │                      │
│  ┌────────────────┐  │  JWKS  │  ┌────────────────┐  │
│  │   Keycloak     │◄─┼───────┼──┤  Kafka cluster  │  │
│  │  (HTTP :8080)  │  │       │  │  (OAUTHBEARER   │  │
│  └───────┬────────┘  │       │  │   on port 9093) │  │
│          │           │       │  └────────────────┘  │
│  ┌───────▼────────┐  │       │                      │
│  │  PostgreSQL    │  │       │                      │
│  └────────────────┘  │       │                      │
└──────────────────────┘       └──────────────────────┘
```

## Listeners

| Name | Port | Type | TLS | Authentication |
|------|------|------|-----|----------------|
| `plain` | 9092 | internal | No | None |
| `tls` | 9093 | internal | Yes | OAuth 2.0 (OAUTHBEARER via `type: custom`) |

## Prerequisites

- ArgoCD installed (see [ArgoCD installation](../../argo-cd/))
- Strimzi or Streams for Apache Kafka operator deployed via ArgoCD (see [strimzi-operator](../../operators/strimzi/))
- Keycloak or RHBK operator deployed via ArgoCD (see [keycloak-operator](../../operators/keycloak/))

## Deploy via ArgoCD

```bash
kubectl apply -f argocd/application.yaml
```

Or deploy all scenarios at once using the [app-of-apps](../../app-of-apps/) ApplicationSet.

## Verify

```bash
# Check Keycloak is running
kubectl get pods -n keycloak
kubectl get keycloak -n keycloak

# Check Kafka is running
kubectl get pods -n kafka-oauth
kubectl get kafka my-cluster -n kafka-oauth
```

## Obtain a Token and Produce Messages

```bash
# Run a producer Job using the Strimzi test-clients image
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: oauth-producer
  namespace: kafka-oauth
spec:
  backoffLimit: 0
  template:
    spec:
      containers:
        - name: producer
          image: quay.io/strimzi-test-clients/test-clients:latest-kafka-4.2.0
          env:
            - name: BOOTSTRAP_SERVERS
              value: my-cluster-kafka-bootstrap:9093
            - name: TOPIC
              value: test-topic
            - name: MESSAGE_COUNT
              value: "10"
            - name: MESSAGE
              value: "hello-oauth"
            - name: PRODUCER_ACKS
              value: "all"
            - name: CLIENT_TYPE
              value: KafkaProducer
            - name: ADDITIONAL_CONFIG
              value: |
                security.protocol=SASL_SSL
                sasl.mechanism=OAUTHBEARER
                sasl.login.callback.handler.class=io.strimzi.kafka.oauth.client.JaasClientOauthLoginCallbackHandler
            - name: OAUTH_CLIENT_ID
              value: kafka-client
            - name: OAUTH_CLIENT_SECRET
              value: kafka-client-secret
            - name: OAUTH_TOKEN_ENDPOINT_URI
              value: http://keycloak-service.keycloak.svc:8080/realms/kafka/protocol/openid-connect/token
            - name: CA_CRT
              valueFrom:
                secretKeyRef:
                  name: my-cluster-cluster-ca-cert
                  key: ca.crt
      restartPolicy: Never
EOF

# Check producer logs
kubectl wait --for=condition=complete job/oauth-producer -n kafka-oauth --timeout=60s
kubectl logs job/oauth-producer -n kafka-oauth

# Run a consumer Job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: oauth-consumer
  namespace: kafka-oauth
spec:
  backoffLimit: 0
  template:
    spec:
      containers:
        - name: consumer
          image: quay.io/strimzi-test-clients/test-clients:latest-kafka-4.2.0
          env:
            - name: BOOTSTRAP_SERVERS
              value: my-cluster-kafka-bootstrap:9093
            - name: TOPIC
              value: test-topic
            - name: MESSAGE_COUNT
              value: "10"
            - name: GROUP_ID
              value: oauth-test-group
            - name: CLIENT_TYPE
              value: KafkaConsumer
            - name: ADDITIONAL_CONFIG
              value: |
                security.protocol=SASL_SSL
                sasl.mechanism=OAUTHBEARER
                sasl.login.callback.handler.class=io.strimzi.kafka.oauth.client.JaasClientOauthLoginCallbackHandler
            - name: OAUTH_CLIENT_ID
              value: kafka-client
            - name: OAUTH_CLIENT_SECRET
              value: kafka-client-secret
            - name: OAUTH_TOKEN_ENDPOINT_URI
              value: http://keycloak-service.keycloak.svc:8080/realms/kafka/protocol/openid-connect/token
            - name: CA_CRT
              valueFrom:
                secretKeyRef:
                  name: my-cluster-cluster-ca-cert
                  key: ca.crt
      restartPolicy: Never
EOF

# Check consumer logs
kubectl wait --for=condition=complete job/oauth-consumer -n kafka-oauth --timeout=60s
kubectl logs job/oauth-consumer -n kafka-oauth

# Cleanup
kubectl delete job oauth-producer oauth-consumer -n kafka-oauth
```

## OAuth Configuration Details

This scenario uses `type: custom` listener authentication (required since Strimzi v1 removed the legacy `type: oauth`). The key configuration in `kafka/kafka.yaml`:

```yaml
authentication:
  type: custom
  sasl: true
  listenerConfig:
    sasl.enabled.mechanisms: OAUTHBEARER
    oauthbearer.sasl.server.callback.handler.class: io.strimzi.kafka.oauth.server.JaasServerOauthValidatorCallbackHandler
    oauthbearer.sasl.jaas.config: >
      org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required
      oauth.valid.issuer.uri="http://keycloak-service.keycloak.svc:8080/realms/kafka"
      oauth.jwks.endpoint.uri="http://keycloak-service.keycloak.svc:8080/realms/kafka/protocol/openid-connect/certs"
      oauth.username.claim="preferred_username" ...
    principal.builder.class: io.strimzi.kafka.oauth.server.OAuthKafkaPrincipalBuilder
```

The Strimzi OAuth libraries (`io.strimzi.kafka.oauth.*`) are bundled in the Strimzi Kafka images.

## Realm Users and Clients

| User/Client | Type | Credentials | Role |
|-------------|------|-------------|------|
| `kafka-admin` | User | `kafka-admin` / `kafka-admin` | Full Kafka access |
| `producer-user` | User | `producer-user` / `producer-user` | Produce to topics |
| `consumer-user` | User | `consumer-user` / `consumer-user` | Consume from topics |
| `kafka-broker` | Client | secret: `kafka-broker-secret` | Kafka broker token validation |
| `kafka-client` | Client | secret: `kafka-client-secret` | Application client credentials |

## Customization

- **OIDC provider URLs**: Update `oauthbearer.sasl.jaas.config` in `kafka/kafka.yaml` to point to your provider
- **TLS for Keycloak**: For production, add `spec.http.tlsSecret` to `keycloak/keycloak.yaml` and mount the CA cert in the Kafka pod template (see [Strimzi docs](https://strimzi.io/docs/operators/latest/configuring.html) for volume mount examples)
- **Realm configuration**: Add users, roles, and clients in `keycloak/realm-import.yaml`
- **External access**: Add an Ingress/Route for Keycloak and a `type: route` or `type: loadbalancer` listener on Kafka
- **Production secrets**: Replace the example secrets in `keycloak/database-secret.yaml` and `keycloak/admin-secret.yaml` with proper secret management (e.g., Sealed Secrets, External Secrets Operator)

## Using with RHBK Instead of Keycloak

This scenario works identically with Red Hat Build of Keycloak (RHBK). Install the RHBK operator instead of the community Keycloak operator:

```bash
# Instead of: kubectl apply -f ../../operators/keycloak/overlays/kubernetes/argocd/application.yaml
kubectl apply -f ../../operators/keycloak/overlays/rhbk/argocd/application.yaml
```

The Keycloak CR and KeycloakRealmImport CR use the same `k8s.keycloak.org/v2alpha1` API for both products.

## Compatibility

These manifests use `kafka.strimzi.io/v1` and `k8s.keycloak.org/v2alpha1` CRDs and work with:
- **Strimzi** 1.0.0+ / **Streams for Apache Kafka** 3.2+
- **Keycloak** 26.0+ / **Red Hat Build of Keycloak** (RHBK)
