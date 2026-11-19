# Plan de recuperación ante desastres (DRP): PostgreSQL

Sistema: API bancaria Banco_MIBC_UMG (laboratorio, datos ficticios). Última revisión: 17 de noviembre de 2026.

## Alcance

Cubre la pérdida de los datos de PostgreSQL (borrado del volumen, corrupción o borrado accidental de tablas). No cubre la pérdida de todo el equipo o del clúster completo; ese caso se resuelve volviendo a crear la infraestructura con Terraform y restaurando el último respaldo, pero **no se probó**.

## Objetivos de recuperación (propuestos)

| Objetivo | Valor propuesto | Resultado del ejercicio |
|---|---|---|
| RTO (tiempo máximo para volver) | 15 minutos | 5 min 43 s (incluye una pausa de reacción) |
| RPO (datos que se aceptan perder) | 5 minutos | 4 min 40 s, pero solo porque el respaldo se tomó pocos minutos antes |

Son valores propuestos por este documento y deben validarse con el grupo. Con respaldos manuales, el RPO no está garantizado.

## Qué se respalda y dónde

- **Qué:** la base `banca` completa (tablas `cuentas` y `transferencias`) con `pg_dump`, formato SQL comprimido, con `--clean --if-exists` para poder restaurar sobre una base ya existente.
- **Dónde:** carpeta `~/respaldos-banca` del equipo, es decir, **fuera del clúster**, para que sobreviva si se pierde el volumen. No es una copia fuera del equipo: si falla el disco de la computadora, se pierden ambos.
- **Cómo:** `./ops/backup-postgres.sh` (verifica el archivo con `gzip -t`).
- **Cuándo:** manualmente. La frecuencia automática (cada 5 minutos) es una propuesta no implementada.

## Procedimiento de recuperación

1. Declarar el desastre y anotar la hora (`date +%T`).
2. Confirmar la pérdida: `./ops/verificar-datos.sh` (si el volumen se perdió, la base aparece con las 3 cuentas de ejemplo y 0 transferencias).
3. Asegurar que `postgres-0` esté en `1/1 Running` (si no, seguir `docs/runbook-postgresql.md`).
4. Elegir el respaldo más reciente: `ls -t ~/respaldos-banca | head -3`.
5. Restaurar: `./ops/restore-postgres.sh ~/respaldos-banca/<archivo>.sql.gz`.
6. Verificar: `./ops/verificar-datos.sh` y consultar una cuenta por la API.
7. Calcular RTO (hora de verificación menos hora del desastre) y RPO (hora del desastre menos hora del respaldo) y registrarlos.

## Resultado del ejercicio del 17 de noviembre de 2026

| Dato | Valor |
|---|---|
| Desastre simulado | Eliminación del volumen `data-postgres-0` y del pod: 21:03:20 |
| Base recreada (vacía) | 21:03:32 (12 s) |
| Inicio de la restauración | 21:09:02 |
| Fin de la restauración | 21:09:03 (1 s) |
| Servicio verificado | 21:09:03 |
| RTO total | 5 min 43 s |
| RTO técnico (Kubernetes y restauración) | unos 13 s |
| Respaldo usado | 20:58:40, con 801 transferencias |
| Transferencias al momento del desastre | 1,075 (770 previas + 305 del generador) |
| Transferencias perdidas | 274 (25.5 %) |
| RPO real | 4 min 40 s |

Comprobación de consistencia: tras restaurar, la cuenta 1 quedó con 9,199.00, que es 10,000 menos 801 transferencias de 1.00.

## Limitaciones y mejoras propuestas (no implementadas)

- Respaldo automático cada 5 minutos (CronJob) y copia en otro equipo o almacenamiento.
- Archivado continuo de registros de transacción (WAL) para acercar el RPO a cero.
- Cifrar los respaldos y controlar quién puede leerlos (en el laboratorio son datos ficticios; en un banco real es obligatorio).
- Prueba periódica de restauración y prueba de reconstrucción completa del clúster.
- Alerta de integridad que detecte una caída repentina en el número de transferencias (la pérdida del volumen no produce errores 5xx).
