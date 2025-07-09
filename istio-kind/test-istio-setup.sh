#!/bin/bash

# Test script for Istio setup
echo "🔍 Testing Istio setup..."

# Check if cluster exists
if ! kind get clusters | grep -q "^istio-cluster$"; then
  echo "❌ Istio cluster not found. Please run setup-kind-istio.sh first."
  exit 1
fi

# Check if kubectl context is set
if ! kubectl config current-context | grep -q "kind-istio-cluster"; then
  echo "⚠️ Setting kubectl context to istio-cluster..."
  kind export kubeconfig --name istio-cluster
fi

# Check if Istio components are running
echo "📊 Checking Istio components..."
kubectl get pods -n istio-system --no-headers | grep -v "Running" && echo "❌ Some Istio pods are not running" || echo "✅ All Istio pods are running"

# Check if cert-manager is running
echo "📊 Checking cert-manager..."
kubectl get pods -n cert-manager --no-headers | grep -v "Running" && echo "❌ Some cert-manager pods are not running" || echo "✅ All cert-manager pods are running"

# Check certificate status
echo "📊 Checking certificate status..."
kubectl get certificate -n istio-system wildcard-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True" && echo "✅ Certificate is ready" || echo "❌ Certificate is not ready"

# Check gateway and virtual service
echo "📊 Checking Istio resources..."
kubectl get gateway -n default example-gateway >/dev/null 2>&1 && echo "✅ Gateway exists" || echo "❌ Gateway not found"

# Test connection if test.example.com is in /etc/hosts
if grep -q "test.example.com" /etc/hosts; then
  echo "🌐 Testing connection to test.example.com:9443..."
  if curl -sk --max-time 10 "https://test.example.com:9443/get" >/dev/null 2>&1; then
    echo "✅ Connection successful"
  else
    echo "❌ Connection failed"
  fi
else
  echo "⚠️ test.example.com not found in /etc/hosts. Add it to test connection."
fi

echo "🎉 Test complete!" 