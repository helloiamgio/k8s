#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: comando richiesto non trovato: $1" >&2
    exit 1
  }
}

need kind
need kubectl
need helm
need docker

if kind get clusters 2>/dev/null | grep -qx kind; then
  echo "[INFO] Cluster kind già presente: kind"
else
  echo "[INFO] Creo il cluster kind"
  kind create cluster --config "$ROOT_DIR/lab/01-kind-cluster.yaml"
fi

echo "[INFO] Installo i CRD Gateway API"
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.4.2" | kubectl apply -f -

echo "[INFO] Installo NGINX Gateway Fabric"
if helm -n nginx-gateway status ngf >/dev/null 2>&1; then
  echo "[INFO] Release Helm ngf già presente, salto installazione"
else
  helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
    --create-namespace -n nginx-gateway \
    --set nginx.service.type=NodePort \
    --set-json 'nginx.service.nodePorts=[{"port":31437,"listenerPort":80},{"port":30478,"listenerPort":8443}]'
fi

echo "[INFO] Attendo i pod del gateway"
kubectl rollout status -n nginx-gateway deploy/ngf-nginx-gateway-fabric --timeout=180s || true

echo "[INFO] Applico le demo app"
kubectl apply -f "$ROOT_DIR/lab/02-apps.yaml"

echo "[INFO] Applico Gateway e HTTPRoute"
kubectl apply -f "$ROOT_DIR/lab/03-gateway.yaml"
kubectl apply -f "$ROOT_DIR/lab/04-routes.yaml"

echo
kubectl get gatewayclass
kubectl get gateways
kubectl get httproutes

echo
echo "[INFO] Test suggeriti:"
echo "curl -H 'Host: cafe.example.com' http://127.0.0.1:8080/coffee"
echo "curl -H 'Host: cafe.example.com' http://127.0.0.1:8080/tea"
