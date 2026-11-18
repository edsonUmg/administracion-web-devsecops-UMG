#!/usr/bin/env bash
# Muestra el estado de los datos: cuantas filas hay y la ultima transferencia.
# Sirve para comparar "antes" y "despues" de un desastre y de una restauracion.
set -euo pipefail
NS=banca-prod
echo "Hora: $(date +%T)"
kubectl -n "$NS" exec postgres-0 -- psql -U banca_app -d banca -At -F ' | ' -c "SELECT 'cuentas', count(*), sum(saldo) FROM cuentas UNION ALL SELECT 'transferencias', count(*), coalesce(sum(monto),0) FROM transferencias;"
kubectl -n "$NS" exec postgres-0 -- psql -U banca_app -d banca -At -F ' | ' -c "SELECT 'ultima transferencia', coalesce(max(creada_en)::text,'(ninguna)') FROM transferencias;"
