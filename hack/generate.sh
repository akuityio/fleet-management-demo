#!/usr/bin/env bash
# Regenerates the manifests in hack/agent, hack/host and hack/k3s from the kargo-enterprise chart.
#
# Required env vars:
#   CHART_PATH       path to the kargo-enterprise chart (e.g. ~/ws/akuityio/kargo-enterprise/charts/kargo-enterprise)
#   IMAGE_REPO       kargo image repository (e.g. ghcr.io/jessesuen/kargo)
#   IMAGE_TAG        kargo image tag (e.g. fleet)
#   AGENT_NAMESPACE  namespace of the Akuity agent (e.g. akuity-demo-fleet)
#   HOST_NAMESPACE   namespace of the Kargo instance on the host (e.g. kargo-u4mqjepdv1rr4us5)
#   AGENT_NAME       agent name used in kubeconfig secret/service account names (e.g. demo-fleet)
#
# Optional env vars:
#   LOG_LEVEL        log level of the TargetSet and PromotionRequest controllers (default: DEBUG)

set -euo pipefail

: "${CHART_PATH:?CHART_PATH is required}"
: "${IMAGE_REPO:?IMAGE_REPO is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${AGENT_NAMESPACE:?AGENT_NAMESPACE is required}"
: "${HOST_NAMESPACE:?HOST_NAMESPACE is required}"
: "${AGENT_NAME:?AGENT_NAME is required}"
LOG_LEVEL="${LOG_LEVEL:-DEBUG}"

HACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

common_args=(
  --set kargo.api.adminAccount.passwordHash=x
  --set kargo.api.adminAccount.tokenSigningKey=x
)

echo "Generating agent/target-set-controller.yaml"
helm template kargo "${CHART_PATH}" -n "${AGENT_NAMESPACE}" \
  "${common_args[@]}" \
  --set targetSetController.enabled=true \
  --set "targetSetController.logLevel=${LOG_LEVEL}" \
  --set "targetSetController.kubeconfigSecrets.kargo=kargo-controller-kubeconfig-${AGENT_NAME}" \
  --set "targetSetController.kubeconfigSecrets.argocd=kargo-akp-cd-kubeconfig-${AGENT_NAME}" \
  --set "kargo.image.repository=${IMAGE_REPO}" \
  --set "kargo.image.tag=${IMAGE_TAG}" \
  --show-only templates/target-set-controller/deployment.yaml \
  --show-only templates/target-set-controller/configmap.yaml \
  --show-only templates/target-set-controller/service-account.yaml \
  > "${HACK_DIR}/agent/target-set-controller.yaml"

echo "Generating host/promotionrequest-controller.yaml"
helm template kargo "${CHART_PATH}" -n "${HOST_NAMESPACE}" \
  "${common_args[@]}" \
  --set kargo.dataPlane.install=false \
  --set promotionRequestController.kubeconfigSecrets.kargo=k3s-kubeconfig \
  --set "promotionRequestController.logLevel=${LOG_LEVEL}" \
  --set "kargo.image.repository=${IMAGE_REPO}" \
  --set "kargo.image.tag=${IMAGE_TAG}" \
  --show-only templates/promotion-request-controller/deployment.yaml \
  --show-only templates/promotion-request-controller/configmap.yaml \
  --show-only templates/promotion-request-controller/service-account.yaml \
  > "${HACK_DIR}/host/promotionrequest-controller.yaml"

echo "Generating k3s/targetset-rbac.yaml"
helm template kargo "${CHART_PATH}" -n kargo \
  "${common_args[@]}" \
  --set targetSetController.enabled=true \
  --show-only templates/target-set-controller/cluster-roles.yaml \
  --show-only templates/target-set-controller/cluster-role-bindings.yaml \
| AGENT_NAME="${AGENT_NAME}" yq 'select(.kind == "ClusterRoleBinding") |= (
    .metadata.name = "kargo-target-set-controller-agent-" + strenv(AGENT_NAME) |
    .subjects = [{"kind": "ServiceAccount", "name": "agent-" + strenv(AGENT_NAME), "namespace": "kargo"}]
  )' \
  > "${HACK_DIR}/k3s/targetset-rbac.yaml"

echo "Generating k3s/promotionrequest-rbac.yaml"
helm template kargo "${CHART_PATH}" -n kargo \
  "${common_args[@]}" \
  --set kargo.workloads.install=false \
  --show-only templates/promotion-request-controller/service-account.yaml \
  --show-only templates/promotion-request-controller/cluster-roles.yaml \
  --show-only templates/promotion-request-controller/cluster-role-bindings.yaml \
  > "${HACK_DIR}/k3s/promotionrequest-rbac.yaml"

cat <<EOF

Done. The host also needs its k3s NetworkPolicy to allow the PromotionRequest controller:

kubectl -n ${HOST_NAMESPACE} patch networkpolicy k3s --type=json -p '[
  {"op":"add","path":"/spec/ingress/-","value":{
    "from":[{"podSelector":{"matchLabels":{
      "app.kubernetes.io/component":"promotion-request-controller",
      "app.kubernetes.io/name":"kargo-enterprise"}}}],
    "ports":[{"port":6443,"protocol":"TCP"}]}}
]'
EOF
