#!/usr/bin/env bash
set -e

echo "==> [1/4] Installing Prometheus Community repo inside K3s agent..."
docker exec -i jenkins-agent bash << 'EOF'
set -e
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "==> [2/4] Generating inline values-prom-lite.yaml on agent..."
cat << 'VALS' > /tmp/values-prom-lite.yaml
grafana:
  enabled: false
alertmanager:
  enabled: false

prometheus:
  prometheusSpec:
    scrapeInterval: "15s"
    evaluationInterval: "15s"
    retention: "4h"
    resources:
      requests:
        cpu: "50m"
        memory: "150Mi"
      limits:
        cpu: "250m"
        memory: "350Mi"
  service:
    type: NodePort
    nodePort: 30090

kubeStateMetrics:
  enabled: true
nodeExporter:
  enabled: true
prometheus-node-exporter:
  hostRootFsMount:
    enabled: false
VALS

echo "==> [3/4] Deploying in-cluster Prometheus to K3s..."
helm upgrade --install k3s-prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f /tmp/values-prom-lite.yaml \
  --atomic \
  --timeout 5m

echo "==> [4/4] In-cluster Prometheus deployed successfully!"
kubectl get pods,svc -n monitoring
EOF
