#!/usr/bin/env bash
set -Eeuo pipefail

if kind get clusters 2>/dev/null | grep -qx kind; then
  echo "[INFO] Elimino il cluster kind"
  kind delete cluster
else
  echo "[INFO] Nessun cluster kind chiamato 'kind' trovato"
fi
