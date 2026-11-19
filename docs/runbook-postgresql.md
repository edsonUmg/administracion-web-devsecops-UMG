# Runbook: PostgreSQL no disponible o con datos perdidos

Sistema: API bancaria Banco_MIBC_UMG (laboratorio, namespace `banca-prod`). Última revisión: 17 de noviembre de 2026.

## Cuándo usar este runbook

- Las solicitudes a la API devuelven 503, 502 o 500 de forma sostenida.
- Las pods `banca-api` aparecen en `0/1` (no listas) o `postgres-0` no está en `1/1 Running`.
- Se sospecha pérdida de datos (por ejemplo, el historial de transferencias apareció vacío).
- Se activa una alerta de disponibilidad (`BancaSLODisponibilidadBurnRapido`, `BancaAPISinInstancias`). Atención: en el ejercicio del 17 de noviembre estas alertas **no** se activaron con una caída de la base, así que no basta con esperar una alerta (ver post-mortem).

## Severidad

| Nivel | Criterio | Meta de respuesta |
|---|---|---|
| SEV1 | Servicio caído o datos perdidos | Empezar de inmediato; recuperar en menos de 15 min (RTO propuesto) |
| SEV2 | Servicio degradado (errores parciales) | Empezar en menos de 15 min |

## Pasos

Anotar la hora de cada paso (`date +%T`): sirven para medir tiempos y para el post-mortem.

1. **Confirmar el impacto.**
   ```
   curl -sk --resolve banca.local:443:127.0.0.1 https://banca.local/cuentas/1; echo
   kubectl -n banca-prod get pods
   ```
   Esperado en estado sano: la cuenta responde y todas las pods están en `1/1 Running`.

2. **Revisar PostgreSQL.**
   ```
   kubectl -n banca-prod get pod postgres-0
   kubectl -n banca-prod describe pod postgres-0 | tail -20
   ```
   - `Running 1/1`: la base está arriba; pasar al paso 5.
   - `Terminating` por mucho tiempo, `Pending` o `CrashLoopBackOff`: leer la sección `Events` y seguir al paso 3.

3. **Si el pod no termina de borrarse y el evento dice `FailedKillPod` con `calico ... Unauthorized`** (ocurrió el 17 de noviembre): la red del clúster perdió su credencial. Reiniciar los pods de Calico (no corta la red de los pods existentes):
   ```
   kubectl -n calico-system rollout restart ds/calico-node
   kubectl -n calico-system rollout status ds/calico-node --timeout=180s
   kubectl -n banca-prod get pods
   ```
   Esperado: `postgres-0` vuelve a `1/1` y las pods de la API pasan a `1/1`. Si el pod sigue atascado, no forzar su borrado sin antes anotar el estado (puede dejar procesos huérfanos).

4. **Si hay otro error en los eventos** (por ejemplo, falta de memoria o de disco): corregirlo según el mensaje y volver a revisar el paso 2. Si no se puede resolver en 15 minutos, escalar al responsable del proyecto.

5. **Verificar los datos.**
   ```
   ./ops/verificar-datos.sh
   ```
   Comparar con lo último que se sabe (número de transferencias y su fecha). Si coincide, ir al paso 7.

6. **Si faltan datos o el volumen se perdió**: ir al plan de recuperación (`docs/drp-postgresql.md`) y restaurar el último respaldo:
   ```
   ls -t ~/respaldos-banca | head -3
   ./ops/restore-postgres.sh ~/respaldos-banca/<archivo-mas-reciente>.sql.gz
   ./ops/verificar-datos.sh
   ```
   Registrar la hora del último respaldo: indica cuántos datos se perdieron (RPO real).

7. **Confirmar la recuperación.** La API responde, las pods están en `1/1`, y se revisa el panel de Grafana (disponibilidad de 5 minutos de vuelta a 100 %).

8. **Cerrar.** Anotar horas de inicio, de detección y de recuperación, y escribir el post-mortem sin culpables (`docs/postmortem-2026-11-17-postgresql.md` como modelo).

## Estado de prueba

| Paso | Estado |
|---|---|
| 1, 2 y 5 | Probados en el ejercicio del 17 de noviembre |
| 3 (reinicio de Calico) | Probado en un incidente real durante el ejercicio |
| 6 (restauración) | Probado en el ejercicio de desastre |
| 4 y 7 | Descritos, no probados como paso separado |
