+++
title = 'GitOps Tutorial Series: Wrapping Up'
+++

# What You've Learned

In Lesson 1, you learned the two foundational principles of GitOps. First, that your infrastructure is defined as configuration stored in a Git repository, making it the *single source of truth* for the state of your cluster. Second, that a *reconciliation loop* continuously watches that repository and automatically rolls out any changes it detects. You pushed a commit and the system converged to match, no manual intervention required.

In Lesson 2, you scaled that workflow to handle multiple environments. Using Kustomize's base and overlay pattern, you managed staging and production configurations from a single repository, each with its own ArgoCD Application watching its own directory path. Promoting a change from staging to production wasn't a special deployment step. It was a configuration change and a Git commit, the same workflow you'd already learned.

In Lesson 3, you saw that GitOps handles failure the same way it handles everything else: through Git. A rollback is just another commit that returns the configuration to a known-good state. Because the reconciliation loop applies whatever is in the repository, recovery is automatic. And because every change is a Git commit, the full history of the incident, from the breaking change to the fix, is preserved as an auditable record.

# The Tools Behind the Workflow

Two tools made all of this possible.

**Kustomize** gave you a clean, declarative way to manage your Kubernetes manifests. In Lesson 1, it controlled which resources ArgoCD deployed. By Lesson 2, it was doing much more: shared base configurations with environment-specific overlays handled the complexity of multi-environment management without duplicating a single YAML file.

**ArgoCD** was the engine that turned your Git repository into a live, self-healing system. It watched for changes, applied them to the cluster and continuously reported both sync and health status. It's what made the "push and forget" workflow possible and what ensured that when you rolled back a bad change, the recovery was automatic.

# Final Thoughts on GitOps

Throughout this series, every change you made to your cluster followed the same pattern: edit configuration, commit, push. Deployments, promotions and rollbacks were all just Git commits. That consistency is the real strength of GitOps. You get reproducibility, auditability and safe rollbacks not as extra features you have to set up, but as natural consequences of treating your Git repository as the single source of truth. It's a simpler and more reliable way to manage infrastructure, built on tools and workflows you already know.

# Next Steps

Now that you have the fundamentals down, explore the `examples/` directory in this repository to see GitOps applied to production-grade streaming infrastructure. All of the examples support both OpenShift and vanilla Kubernetes.

* **Basic Kafka** (`examples/scenarios/basic-kafka/`): A production-ready Kafka cluster running in KRaft mode with Cruise Control for automatic rebalancing and Prometheus metrics for monitoring.
* **Kafka with OAuth** (`examples/scenarios/kafka-oauth/`): Extends the basic cluster with OAuth/OIDC authentication powered by Keycloak, including a full realm configuration with roles, users and clients.
* **Kafka Mirroring** (`examples/scenarios/kafka-mirror/`): Cross-cluster data replication using MirrorMaker 2, with the External Secrets Operator handling cross-namespace TLS credential management.
* **App of Apps** (`examples/app-of-apps/`): An ArgoCD ApplicationSet that deploys all operators and scenarios with a single command, demonstrating a real-world pattern for managing multiple applications at scale.

Each scenario comes with its own README, verification steps and customization guidance. They're designed as starting points you can adapt for your own infrastructure.
