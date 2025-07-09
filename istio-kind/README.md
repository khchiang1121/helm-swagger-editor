# Istio Kind Cluster Setup

This directory contains scripts to set up an Istio service mesh on a Kind Kubernetes cluster with proper SSL/TLS termination.

## Problem Fixed

The original setup had an SSL connection issue where `curl -k https://test.example.com:9443/get` would fail with:
```
curl: (35) error:0A000126:SSL routines::unexpected eof while reading
```

### Root Cause
The issue was caused by a mismatch between:
1. **Kind cluster port mapping**: Configured to expose container port 443 on host port 9443
2. **Istio ingress gateway NodePort**: Using a random NodePort (e.g., 31937) instead of the expected port

### Solution
The fix involved:
1. Using a valid NodePort range (30000-32767) for the Istio ingress gateway
2. Mapping the NodePort (30443) to the host port (9443) in the Kind cluster configuration
3. Automatically patching the Istio ingress gateway service to use the correct NodePort

## Files

- `setup-kind-istio.sh` - Main setup script (fixed)
- `test-istio-setup.sh` - Test script to verify the setup
- `README.md` - This documentation

## Usage

### Setup Istio Cluster
```bash
./setup-kind-istio.sh domain1.example.com domain2.example.com
```

### Test the Setup
```bash
./test-istio-setup.sh
```

### Manual Test
```bash
curl -k https://test.example.com:9443/get
```

## What the Setup Includes

1. **Kind Cluster**: Single-node Kubernetes cluster with port mapping
2. **Istio Service Mesh**: Demo profile with ingress gateway
3. **Cert-Manager**: For certificate management
4. **Self-Signed Certificate**: Wildcard certificate for *.example.com
5. **Istio Gateway**: HTTPS gateway with TLS termination
6. **Test Application**: httpbin for testing (deployed and cleaned up automatically)

## Port Configuration

- **Host Port**: 9443 (external access)
- **NodePort**: 30443 (internal Kubernetes NodePort)
- **Container Port**: 443 (Istio ingress gateway)

## Troubleshooting

### Check Cluster Status
```bash
kind get clusters
kubectl get pods -A
```

### Check Port Mapping
```bash
docker port istio-cluster-control-plane
```

### Check Service Configuration
```bash
kubectl get svc -n istio-system istio-ingressgateway
```

### Check Certificate Status
```bash
kubectl get certificate -n istio-system
```

### View Logs
```bash
kubectl logs -n istio-system deployment/istio-ingressgateway
```

## Cleanup

To delete the cluster:
```bash
kind delete cluster --name istio-cluster
```

To remove /etc/hosts entries:
```bash
sudo sed -i '/test.example.com/d' /etc/hosts
``` 