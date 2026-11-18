#!/usr/bin/env bash
# Restaura un respaldo creado con backup-postgres.sh (reemplaza las tablas actuales).
# Uso: ./ops/restore-postgres.sh ~/respaldos-banca/banca-AAAAMMDD-HHMMSS.sql.gz
set -euo pipefail
NS=banca-prod
ARCHIVO=${1:?Uso: restore-postgres.sh archivo.sql.gz}
[ -f "$ARCHIVO" ] || { echo "No existe $ARCHIVO"; exit 1; }
echo "Esperando a que exista postgres-0..."
until kubectl -n "$NS" get pod postgres-0 >/dev/null 2>&1; do sleep 2; done
kubectl -n "$NS" wait --for=condition=Ready pod/postgres-0 --timeout=180s
INICIO=$(date +%s)
echo "Inicio de la restauracion: $(date +%T)"
gunzip -c "$ARCHIVO" | kubectl -n "$NS" exec -i postgres-0 -- psql -U banca_app -d banca -v ON_ERROR_STOP=1 -q
echo "Restauracion terminada: $(date +%T) ($(( $(date +%s) - INICIO )) s)"
