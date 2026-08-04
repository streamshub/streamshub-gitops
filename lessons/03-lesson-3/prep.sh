#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../00-setup/common.sh
source "${SCRIPT_DIR}/../00-setup/common.sh"

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
b64decode() { echo "$1" | base64 -d 2>/dev/null || echo "$1" | base64 -D 2>/dev/null; }

cleanup() {
  if [[ -n "${WORK_DIR:-}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
}

# ─── Step 1: Validate infrastructure ──────────────────────────────────────────

info "Validating tutorial infrastructure..."

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  error "KinD cluster '${CLUSTER_NAME}' is not running."
  error "Please run the setup script first: ../00-setup/setup.sh"
  exit 1
fi

if ! kubectl get deployment strimzi-cluster-operator -n strimzi-operator &>/dev/null; then
  error "Strimzi operator not found in namespace 'strimzi-operator'."
  error "Please run the setup script first: ../00-setup/setup.sh"
  exit 1
fi

if ! curl -sf "${GITEA_URL}/api/v1/version" >/dev/null 2>&1; then
  error "Gitea is not reachable on ${GITEA_URL}."
  error "Please run the setup script first: ../00-setup/setup.sh"
  exit 1
fi

info "Infrastructure checks passed."

# ─── Step 2: Remove ArgoCD Applications ───────────────────────────────────────

info "Removing ArgoCD applications..."

kubectl delete application "${KAFKA_NAMESPACE}" "${KAFKA_STAGING_NAMESPACE}" "${KAFKA_PRODUCTION_NAMESPACE}" \
  -n argocd --ignore-not-found 2>/dev/null || true

# ─── Step 3: Reconfigure Strimzi to watch kafka-tutorial ──────────────────────
#
# This must happen BEFORE deleting lesson-2 namespaces. While Strimzi watches
# kafka-staging/kafka-production it will re-add finalizers to any resources we
# try to clear, causing namespace deletion to hang.

info "Configuring Strimzi operator for ${KAFKA_NAMESPACE} namespace..."

kubectl create namespace "${KAFKA_NAMESPACE}" 2>/dev/null || true

for rb_name in strimzi-cluster-operator strimzi-cluster-operator-entity-operator-delegation strimzi-cluster-operator-watched; do
  ROLE_REF=$(kubectl get rolebinding "${rb_name}" -n strimzi-operator -o jsonpath='{.roleRef.name}' 2>/dev/null || echo "")
  if [[ -n "${ROLE_REF}" ]]; then
    kubectl create rolebinding "${rb_name}" \
      --namespace "${KAFKA_NAMESPACE}" \
      --clusterrole="${ROLE_REF}" \
      --serviceaccount=strimzi-operator:strimzi-cluster-operator 2>/dev/null || true
  fi
done

kubectl set env deployment/strimzi-cluster-operator -n strimzi-operator \
  STRIMZI_NAMESPACE="${KAFKA_NAMESPACE}"

info "Waiting for Strimzi operator to restart..."
kubectl rollout status deployment/strimzi-cluster-operator -n strimzi-operator --timeout=120s

# ─── Step 4: Clean up lesson-2 namespaces ─────────────────────────────────────
#
# Now that Strimzi only watches kafka-tutorial, it will not re-add finalizers to
# resources in kafka-staging or kafka-production.

info "Cleaning up previous lesson state..."

for ns in "${KAFKA_STAGING_NAMESPACE}" "${KAFKA_PRODUCTION_NAMESPACE}"; do
  for cr_type in kafka kafkanodepool kafkatopic; do
    kubectl get "${cr_type}" -n "${ns}" -o name 2>/dev/null | \
      xargs -r -I{} kubectl patch {} -n "${ns}" \
        --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
  done
done

kubectl delete namespace "${KAFKA_STAGING_NAMESPACE}" "${KAFKA_PRODUCTION_NAMESPACE}" --ignore-not-found

info "Previous lesson state cleaned up."

# ─── Step 5: Seed the Gitea repository with lesson-3 starting state ──────────

info "Resetting Gitea repository to lesson-3 starting state..."

WORK_DIR=$(mktemp -d)
trap cleanup EXIT

git clone "http://${GITEA_USER}:${GITEA_PASSWORD}@localhost:${GITEA_HOST_PORT}/${GITEA_USER}/${GITEA_REPO}.git" "${WORK_DIR}/repo" 2>/dev/null

rm -rf "${WORK_DIR}/repo/manifests"
mkdir -p "${WORK_DIR}/repo/manifests"
cp "${SCRIPT_DIR}/lesson-manifests/"* "${WORK_DIR}/repo/manifests/"

pushd "${WORK_DIR}/repo" >/dev/null
git add .
if git diff --cached --quiet; then
  info "Gitea repo is already in lesson-3 starting state, skipping commit."
else
  git -c user.name="Tutorial Setup" -c user.email="setup@tutorial.local" commit -m "Reset to lesson-3 starting state"
  git push
  info "Lesson-3 starting state pushed to Gitea."
fi
TARGET_REVISION=$(git rev-parse HEAD)
popd >/dev/null

# ─── Step 6: Create ArgoCD Application kafka-tutorial ─────────────────────────

info "Creating ArgoCD application ${KAFKA_NAMESPACE}..."

kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${KAFKA_NAMESPACE}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/${GITEA_USER}/${GITEA_REPO}.git
    targetRevision: main
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: ${KAFKA_NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    managedNamespaceMetadata:
      labels:
        argocd.argoproj.io/managed-by: argocd
    syncOptions:
      - CreateNamespace=true
EOF

# ─── Step 7: Wait for ArgoCD to sync ──────────────────────────────────────────

info "Waiting for ArgoCD to sync..."

kubectl annotate application "${KAFKA_NAMESPACE}" -n argocd argocd.argoproj.io/refresh=normal --overwrite >/dev/null 2>&1 || true

SYNC_STATUS="Unknown"
for i in $(seq 1 24); do
  CURRENT_REVISION=$(kubectl get application "${KAFKA_NAMESPACE}" -n argocd -o jsonpath='{.status.sync.revision}' 2>/dev/null || echo "")
  SYNC_STATUS=$(kubectl get application "${KAFKA_NAMESPACE}" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  if [[ "${CURRENT_REVISION}" == "${TARGET_REVISION}" && "${SYNC_STATUS}" == "Synced" ]]; then
    break
  fi
  sleep 5
done

if [[ "${SYNC_STATUS}" != "Synced" ]]; then
  warn "ArgoCD has not synced yet (status: ${SYNC_STATUS})."
  warn "Check status with: kubectl get application ${KAFKA_NAMESPACE} -n argocd"
else
  info "ArgoCD application is synced."
fi

# ─── Step 8: Wait for Kafka cluster to be ready ────────────────────────────────

info "Waiting for Kafka cluster to be ready (this may take a few minutes)..."
kubectl wait kafka/${KAFKA_CLUSTER_NAME} --for=condition=Ready -n "${KAFKA_NAMESPACE}" --timeout=600s 2>/dev/null || \
  warn "Kafka cluster is not yet ready. Check with: kubectl get kafka -n ${KAFKA_NAMESPACE}"

# ─── Step 9: Wait for KafkaTopic to be ready ──────────────────────────────────

info "Waiting for KafkaTopic to be ready..."
kubectl wait kafkatopic/my-first-topic --for=condition=Ready -n "${KAFKA_NAMESPACE}" --timeout=120s 2>/dev/null || \
  warn "KafkaTopic is not yet ready. Check with: kubectl get kafkatopic -n ${KAFKA_NAMESPACE}"

# ─── Step 10: Print starting instructions ─────────────────────────────────────

ARGOCD_PASSWORD=$(b64decode "$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}')")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "Lesson 3 is ready. Open README.md and follow the lesson steps."
echo ""
echo "  Clone the repo to follow along:"
echo "     git clone http://${GITEA_USER}:${GITEA_PASSWORD}@localhost:${GITEA_HOST_PORT}/${GITEA_USER}/${GITEA_REPO}.git /tmp/gitops-lesson-3"
echo ""
echo "  Gitea (your Git server):  ${GITEA_URL}"
echo "  Username: ${GITEA_USER}   Password: ${GITEA_PASSWORD}"
echo ""
echo "  ArgoCD Dashboard (open in a separate terminal):"
echo "     kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "     URL:      https://localhost:8080"
echo "     Username: admin"
echo "     Password: ${ARGOCD_PASSWORD}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
