#!/bin/bash

# === Configuration ===
# Set default values for required variables
CLUSTER_NAME=${CLUSTER_NAME:-"istio-cluster"}
HOST_HTTPS_PORT=${HOST_HTTPS_PORT:-"9443"}
# Only set DOMAINS if not already set (use DOMAINS_SET=1 to override)
if [ -z "$DOMAINS_SET" ]; then
  DOMAINS=("httpbin.local" "httpbin.example.com")
fi
TEST_SUCCESS=true

# === Test Connections ===
echo
# Cleanup any existing curl-test pod before running the test
kubectl delete pod curl-test --ignore-not-found > /dev/null 2>&1

echo "🔍 [1/4] Testing service (Pod) connection inside cluster..."

# Launch an ephemeral pod, run curl, capture only the HTTP code, then delete the pod
TEMP_FILE=$(mktemp)
kubectl run curl-test \
  --image=curlimages/curl:7.88.1 \
  -it --rm --restart=Never \
  --overrides='{"metadata": {"annotations": {"sidecar.istio.io/inject": "false"}}}' \
  --command -- \
  curl -s -o /dev/null -w "%{http_code}" http://httpbin.default.svc.cluster.local:80/get > "$TEMP_FILE" 2>/dev/null
HTTP_CODE=$(cat "$TEMP_FILE" | grep -o '^[0-9]*')
rm -f "$TEMP_FILE"
echo "HTTP Code: $HTTP_CODE"
# Check whether we got back 200
if [ "$HTTP_CODE" -eq 200 ]; then
  echo "✅ httpbin service is reachable inside the cluster."
else
  echo "❌ curl inside Pod failed (HTTP status: $HTTP_CODE)."
  TEST_SUCCESS=false
  exit 1
fi


echo
echo "🔍 [2/4] Testing HTTPS Gateway routing inside the cluster..."

for DOMAIN in "${DOMAINS[@]}"; do
  echo -n "  → https://${DOMAIN}:443 from Pod ... "
  if kubectl run curl-test --image=curlimages/curl:7.88.1 -it --rm --restart=Never --command -- \
    curl -sk --max-time 5 https://${DOMAIN}/get >/dev/null; then
    echo "OK ✅"
  else
    echo "FAIL ❌"
    TEST_SUCCESS=false
  fi
done

echo
echo "🔍 [3/4] Testing from kind node container to Istio ingress..."

KIND_NODE=$(docker ps --filter "name=kind-${CLUSTER_NAME}-control-plane" --format "{{.ID}}")

for DOMAIN in "${DOMAINS[@]}"; do
  echo -n "  → https://${DOMAIN}:443 from node with --resolve ... "
  if docker exec "$KIND_NODE" curl -sk --resolve "${DOMAIN}:443:127.0.0.1" --max-time 5 https://${DOMAIN}/get >/dev/null; then
    echo "OK ✅"
  else
    echo "FAIL ❌"
    TEST_SUCCESS=false
  fi
done

echo
echo "🔍 [4/4] Testing from host machine..."

for DOMAIN in "${DOMAINS[@]}"; do
  echo -n "  → curl -k https://${DOMAIN}:${HOST_HTTPS_PORT}/get ... "
  if curl -sk --max-time 5 "https://${DOMAIN}:${HOST_HTTPS_PORT}/get" >/dev/null; then
    echo "OK ✅"
  else
    echo "FAIL ❌"
    TEST_SUCCESS=false
  fi
done

# === Cleanup if successful ===
if [ "$TEST_SUCCESS" = true ]; then
  echo
  echo "🧹 All tests passed. Cleaning up test app and virtual services..."
  kubectl delete deploy httpbin || true
  kubectl delete svc httpbin || true
  for DOMAIN in "${DOMAINS[@]}"; do
    kubectl delete virtualservice "httpbin-${DOMAIN//./-}" || true
  done
  echo "✅ Cleanup complete."
else
  echo
  echo "⚠️ Some tests failed. Keeping resources for debugging."
fi

echo
echo "🎉 Done!"
