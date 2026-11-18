#!/usr/bin/env bash
# Genera una transferencia de prueba por segundo (1.00 de la cuenta 1 a la 2),
# cada una con su clave de idempotencia. Los codigos HTTP quedan en /tmp/transferencias.log
: > /tmp/transferencias.log
while true; do
  curl -sk --resolve banca.local:443:127.0.0.1 -o /dev/null -w '%{time_total} %{http_code}\n' \
    -X POST https://banca.local/transferencias \
    -H 'Content-Type: application/json' \
    -H "Idempotency-Key: t-$(date +%s%N)" \
    -d '{"origen":1,"destino":2,"monto":1.00}' >> /tmp/transferencias.log
  sleep 1
done
