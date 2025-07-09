#!/bin/bash
set -e
echo "[3.5/9] Installing Kubernetes Dashboard..."

# 安裝 Dashboard 本體
# Add kubernetes-dashboard repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

# 建立 admin 使用者與角色綁定
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-binding
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# 等待 dashboard 就緒
kubectl wait --namespace kubernetes-dashboard --for=condition=Ready pod --all --timeout=90s

# 印出登入用 token（選用）
echo
echo "🔐 Dashboard login token (admin-user):"
kubectl -n kubernetes-dashboard create token admin-user
echo



echo "[3.6/9] Creating Istio Gateway for Kubernetes Dashboard..."
# 建立專用的 Gateway

WILDCARD_DOMAIN="localhost"
DASHBOARD_DOMAIN="kubernetes-dashboard.${WILDCARD_DOMAIN}"
CERT_NAMESPACE="istio-system"
CERT_SECRET_NAME="kubernetes-dashboard-cert"

echo "[5/9] Creating TLS certificate for ${DASHBOARD_DOMAIN}..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${CERT_SECRET_NAME}
  namespace: ${CERT_NAMESPACE}
spec:
  secretName: ${CERT_SECRET_NAME}
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: "${DASHBOARD_DOMAIN}"
  dnsNames:
  - "${DASHBOARD_DOMAIN}"
  duration: 8760h
  privateKey:
    algorithm: RSA
    size: 2048
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: kubernetes-dashboard-gateway
  namespace: kubernetes-dashboard
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "${DASHBOARD_DOMAIN}"
    tls:
      mode: PASSTHROUGH
    # tls:
    #   mode: SIMPLE
    #   credentialName: ${CERT_SECRET_NAME}
EOF

# 建立 VirtualService 指向 dashboard
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: kubernetes-dashboard-vs
  namespace: kubernetes-dashboard
spec:
  hosts:
  - "${DASHBOARD_DOMAIN}"
  gateways:
  - kubernetes-dashboard-gateway
  tls:
  - match:
    - port: 443
      sniHosts:
      - kubernetes-dashboard.localhost
    route:
    - destination:
        host: kubernetes-dashboard-kong-proxy.kubernetes-dashboard.svc.cluster.local
        port:
          number: 443
EOF

# # 建立 VirtualService 指向 dashboard
# cat <<EOF | kubectl apply -f -
# apiVersion: networking.istio.io/v1beta1
# kind: VirtualService
# metadata:
#   name: kubernetes-dashboard-vs
#   namespace: kubernetes-dashboard
# spec:
#   hosts:
#   - "${DASHBOARD_DOMAIN}"
#   gateways:
#   - kubernetes-dashboard-gateway
#   http:
#   - match:
#     - uri:
#         prefix: /
#     route:
#     - destination:
#         host: kubernetes-dashboard-kong-proxy.kubernetes-dashboard.svc.cluster.local
#         port:
#           number: 443
#     rewrite:
#       uri: /
# EOF