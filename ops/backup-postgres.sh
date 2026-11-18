#!/usr/bin/env bash
# Respaldo logico de PostgreSQL (pg_dump). El archivo se guarda FUERA del cluster
# (carpeta del equipo), para que sobreviva si se pierde el volumen de la base.
set -euo pipefail
NS=banca-prod
DIR=${BACKUP_DIR:-$HOME/respaldos-banca}
mkdir -p "$DIR"
ARCHIVO="$DIR/banca-$(date +%Y%m%d-%H%M%S).sql.gz"
INICIO=$(date +%s)
echo "Inicio del respaldo: $(date +%T)"
kubectl -n "$NS" exec postgres-0 -- pg_dump -U banca_app -d banca --clean --if-exists --no-owner | gzip > "$ARCHIVO"
gzip -t "$ARCHIVO"
echo "Respaldo listo: $ARCHIVO ($(du -h "$ARCHIVO" | cut -f1)) en $(( $(date +%s) - INICIO )) s, fin $(date +%T)"
