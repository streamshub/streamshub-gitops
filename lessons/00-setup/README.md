# Getting Started

This directory sets up the shared infrastructure for the GitOps tutorial series. Run `setup.sh` once before starting any lesson.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Docker** or **Podman** | Container runtime | [docker](https://docs.docker.com/get-docker/)<br>[podman](https://podman.io/docs/installation) |
| **KinD** (v0.20+) | Local Kubernetes clusters | [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| **kubectl** | Kubernetes CLI | [kubectl](https://kubernetes.io/docs/tasks/tools/) |
| **git** | Version control | [git-scm.com](https://git-scm.com/) |
| **curl** | HTTP requests | Usually pre-installed |

**System requirements:** ~8 GB of available memory for Docker/Podman.

---

## Setup

Run the setup script from this directory:

```bash
./setup.sh
```

This takes approximately 8 minutes and creates a fully self-contained local environment:

1. A **KinD** Kubernetes cluster (`gitops-tutorial`) running on your machine
2. **ArgoCD** — the GitOps engine that watches Git and applies changes
3. **Strimzi** — the operator that manages Kafka resources on Kubernetes
4. **Gitea** — a lightweight Git server running inside the cluster, reachable at `http://localhost:3001`
5. A Git repository in Gitea containing the base Kafka configuration
6. An ArgoCD `Application` configured to watch that repository
7. A running Kafka cluster, already deployed via the GitOps workflow

When the script finishes, it prints the ArgoCD admin password and tells you which lesson prep script to run next.

---

## Starting a lesson

After setup completes, follow the lesson guide of your choice:
* [Lesson 1: Your First GitOps Change](../01-lesson-1/README.md)

---

## Teardown

When you are done with all lessons, delete the cluster to remove everything:

```bash
./teardown.sh
```

---

## Troubleshooting

**Docker is not running**
Start Docker Desktop or your container runtime and run `./setup.sh` again.

**Port 3001 is already in use**
Another application is using port 3001. Stop that application, or change the port in `kind-config.yaml` (update both `hostPort` and the `nodePort` in `gitea/deployment.yaml` to match).

**Kafka cluster is not becoming ready**
Kafka takes a few minutes to start, especially on machines with limited resources. Check pod status:

```bash
kubectl get pods -n kafka-tutorial
kubectl describe kafka my-cluster -n kafka-tutorial
```
