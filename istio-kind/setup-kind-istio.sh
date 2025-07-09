#!/bin/bash
set -e

# === Config ===
CLUSTER_NAME="my-cluster"
HOST_HTTPS_PORT=9443
HOST_HTTP_PORT=9080
NODEPORT_HTTP=30080
NODEPORT_HTTPS=30443  # Valid NodePort in range 30000-32767
CERT_NAMESPACE="istio-system"
CERT_SECRET_NAME="wildcard-cert"
ISTIO_PROFILE="demo"
# === ISTIOCTL Setup ===
ISTIO_VERSION="1.26.2"
ISTIOCTL_LOCAL="$HOME/.local/bin/istioctl"
WILDCARD_DOMAIN="localhost"

echo "[0/9] Installing Istio..."

if ! command -v istioctl >/dev/null 2>&1; then
  echo "[Setup] istioctl not found. Installing Istio ${ISTIO_VERSION}..."

  mkdir -p "$HOME/.local/bin"
  TMP_DIR=$(mktemp -d)
  curl -sL "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz" -o "$TMP_DIR/istio.tar.gz"
  tar -xzf "$TMP_DIR/istio.tar.gz" -C "$TMP_DIR"
  mv "$TMP_DIR/istio-${ISTIO_VERSION}/bin/istioctl" "$ISTIOCTL_LOCAL"
  chmod +x "$ISTIOCTL_LOCAL"
  rm -rf "$TMP_DIR"

  echo "[Setup] istioctl installed at $ISTIOCTL_LOCAL"
else
  echo "[Setup] istioctl found: $(command -v istioctl)"
fi

# === Check if cluster exists ===
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "[1/9] Kind cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  echo "[1/9] Creating kind cluster '${CLUSTER_NAME}' with NodePort mapping..."
  cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
  extraPortMappings:
  - containerPort: ${NODEPORT_HTTPS}
    hostPort: ${HOST_HTTPS_PORT}
    protocol: TCP
  - containerPort: ${NODEPORT_HTTP}
    hostPort: ${HOST_HTTP_PORT}
    protocol: TCP
- role: worker
EOF
fi

echo "[2/9] Installing Istio..."
istioctl install --set profile=${ISTIO_PROFILE} -y
kubectl label namespace default istio-injection=enabled --overwrite

echo "[3/9] Installing cert-manager 1.18.2..."
kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
kubectl wait --namespace cert-manager --for=condition=Ready pod --all --timeout=120s

echo "[4/9] Creating self-signed ClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

echo "[5/9] Creating wildcard TLS certificate for *.${WILDCARD_DOMAIN}..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-cert
  namespace: ${CERT_NAMESPACE}
spec:
  secretName: ${CERT_SECRET_NAME}
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: "*.${WILDCARD_DOMAIN}"
  dnsNames:
  - "*.${WILDCARD_DOMAIN}"
  - "${WILDCARD_DOMAIN}"
  duration: 8760h
  privateKey:
    algorithm: RSA
    size: 2048
EOF

kubectl wait --for=condition=Ready --timeout=120s certificate/wildcard-cert -n ${CERT_NAMESPACE}



echo "[7/9] Deploying httpbin app..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: httpbin
spec:
  selector:
    app: httpbin
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
EOF

kubectl wait --for=condition=Available --timeout=120s deployment/httpbin -n default

echo "[6/9] Creating Istio Gateway..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "httpbin.${WILDCARD_DOMAIN}"
    tls:
      mode: SIMPLE
      credentialName: ${CERT_SECRET_NAME}
EOF

echo "[8/9] Creating VirtualServices..."

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-vs
spec:
  hosts:
  - "httpbin.${WILDCARD_DOMAIN}"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: httpbin
        port:
          number: 80
EOF

# === Fix Istio Ingress Gateway NodePort ===
echo "[10/9] Fixing Istio Ingress Gateway NodePort..."
# Get the current NodePort for HTTPS
CURRENT_NODEPORT=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo "Current HTTPS NodePort: ${CURRENT_NODEPORT}"

# Update the service to use the correct NodePort that matches the kind cluster port mapping
kubectl patch svc istio-ingressgateway -n istio-system -p "{\"spec\":{\"ports\":[{\"name\":\"http2\",\"port\":80,\"targetPort\":8080,\"nodePort\":${NODEPORT_HTTP}},{\"name\":\"https\",\"port\":443,\"targetPort\":8443,\"nodePort\":${NODEPORT_HTTPS}}]}}"
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec": {"type": "NodePort"}}'

echo "Updated Istio Ingress Gateway to use NodePort ${NODEPORT_HTTPS}"

# === Test Connections ===
echo
echo "🔍 Testing connections..."
TEST_SUCCESS=true
DOMAINS=("httpbin.${WILDCARD_DOMAIN}")
for DOMAIN in "${DOMAINS[@]}"; do
  echo -n "  → Testing https://${DOMAIN}:${HOST_HTTPS_PORT}/get ... "
  if curl -sk --max-time 10 "https://${DOMAIN}:${HOST_HTTPS_PORT}/get" >/dev/null; then
    echo "OK ✅"
  else
    echo "FAILED ❌"
    TEST_SUCCESS=false
  fi
done

# # === Cleanup if successful ===
# if [ "$TEST_SUCCESS" = true ]; then
#   echo
#   echo "🧹 Cleaning up test app and virtual services..."
#   kubectl delete deploy httpbin || true
#   kubectl delete svc httpbin || true
#   for DOMAIN in "${DOMAINS[@]}"; do
#     kubectl delete virtualservice "httpbin-${DOMAIN//./-}" || true
#   done
#   echo "✅ Cleanup complete."
# else
#   echo
#   echo "⚠️ Some connections failed. Keeping resources for debugging."
# fi

echo
echo "🎉 Done!"