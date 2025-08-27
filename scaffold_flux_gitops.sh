#!/usr/bin/env bash
set -euo pipefail

# ================================
# Scaffold Flux GitOps (K3s + MetalLB + nip.io + Nginx demo)
# ================================
: "${APP_NAMESPACE:=medtech}"
: "${APP_NAME:=nginx-demo}"
: "${IMAGE:=nginx}"
: "${IMAGE_TAG:=stable}"
: "${METALLB_RANGE:=192.168.1.240-192.168.1.250}"
: "${INGRESS_HOST:=CHANGEME.nip.io}"

function image_ref() {
  local img="${IMAGE}"
  if [[ "${img}" == *:* ]]; then
    echo "${img}"
  else
    echo "${img}:${IMAGE_TAG}"
  fi
}

ROOT_DIR="$(pwd)"

echo "==> Repo: ${ROOT_DIR}"
echo "==> Namespace: ${APP_NAMESPACE}"
echo "==> App: ${APP_NAME}"
echo "==> Image: $(image_ref)"
echo "==> MetalLB range: ${METALLB_RANGE}"
echo "==> Ingress host: ${INGRESS_HOST}"

mkdir -p "${ROOT_DIR}/clusters/dev"
mkdir -p "${ROOT_DIR}/infrastructure/metallb"
mkdir -p "${ROOT_DIR}/apps/${APP_NAME}"

# clusters/dev/kustomization.yaml
cat > "${ROOT_DIR}/clusters/dev/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../infrastructure
  - ../../apps/${APP_NAME}
YAML

# infrastructure/kustomization.yaml
cat > "${ROOT_DIR}/infrastructure/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - metallb/namespace.yaml
  - metallb/ipaddresspool.yaml
  - metallb/l2advertisement.yaml
YAML

# MetalLB namespace
cat > "${ROOT_DIR}/infrastructure/metallb/namespace.yaml" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
YAML

# MetalLB IPAddressPool
cat > "${ROOT_DIR}/infrastructure/metallb/ipaddresspool.yaml" <<YAML
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - "${METALLB_RANGE}"
YAML

# MetalLB L2Advertisement
cat > "${ROOT_DIR}/infrastructure/metallb/l2advertisement.yaml" <<YAML
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-adv
  namespace: metallb-system
spec: {}
YAML

# apps/kustomization.yaml
cat > "${ROOT_DIR}/apps/${APP_NAME}/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${APP_NAMESPACE}
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
YAML

# apps/namespace.yaml
cat > "${ROOT_DIR}/apps/${APP_NAME}/namespace.yaml" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAMESPACE}
YAML

# apps/deployment.yaml
cat > "${ROOT_DIR}/apps/${APP_NAME}/deployment.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  labels:
    app: ${APP_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
        - name: ${APP_NAME}
          image: $(image_ref)
          ports:
            - containerPort: 80
YAML

# apps/service.yaml
cat > "${ROOT_DIR}/apps/${APP_NAME}/service.yaml" <<YAML
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  labels:
    app: ${APP_NAME}
spec:
  type: ClusterIP
  selector:
    app: ${APP_NAME}
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

# apps/ingress.yaml
cat > "${ROOT_DIR}/apps/${APP_NAME}/ingress.yaml" <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - host: ${INGRESS_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${APP_NAME}
                port:
                  number: 80
YAML

echo "✅ Scaffold terminé. Tu peux git add/commit/push."
