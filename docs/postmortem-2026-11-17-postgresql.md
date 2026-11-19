# Post-mortem sin culpables: caída de PostgreSQL (17 de noviembre de 2026)

Tipo: ejercicio de incidente en laboratorio, que se volvió un incidente real por un fallo de la red del clúster. Este documento busca aprender del sistema, no señalar personas.

## Resumen

A las 20:35:46 se eliminó el pod `postgres-0` con tráfico de prueba activo, para comprobar la detección y la recuperación. Se esperaba que Kubernetes lo recreara en menos de un minuto. El pod quedó en `Terminating` casi 10 minutos porque Calico (la red del clúster) respondía `Unauthorized` al intentar eliminar su red. Se recuperó a las 20:45:44, después de reiniciar los pods de Calico. No se perdió ningún dato.

## Impacto

- Duración: 9 min 58 s sin base de datos.
- De 1,359 solicitudes de transferencia del generador, 589 fallaron (586 con 503, 2 con 502 y 1 con 500): 43.3 %. Durante la caída, prácticamente todas.
- Integridad: las 770 transferencias confirmadas (201) coinciden con las 770 filas de la base. Ninguna fallida quedó guardada.
- Usuarios afectados: ninguno real (laboratorio).

## Línea de tiempo (hora de Guatemala)

| Hora | Evento |
|---|---|
| 20:35:46 | Se elimina `postgres-0` con tráfico activo. |
| 20:35 a 20:42 | El pod queda en `Terminating`; las pods de la API pasan a `0/1`; el Ingress devuelve 503. |
| Alrededor de 20:40 | El operador nota que el comando de espera no termina (detección humana, no por alerta). |
| 20:41:00 | `BancaLatenciaSLOEnRiesgo` en `pending` durante una sola muestra; no llega a `firing`. |
| 20:42 | `describe` del pod: evento `FailedKillPod` (27 intentos), error de Calico: `connection is unauthorized: Unauthorized`. |
| Poco antes de 20:46 | Se reinician los pods de Calico (`rollout restart ds/calico-node`). |
| 20:45:44 | `postgres-0` listo (`1/1`); las pods de la API vuelven a `1/1`. |

## Causa raíz

Causa inmediata: el plugin de red Calico no pudo autenticarse contra la API de Kubernetes al eliminar la red del pod, y la eliminación quedó reintentándose. Reiniciar `calico-node` lo resolvió, lo que sugiere un problema con la credencial que Calico usa y renueva por sí mismo (el clúster llevaba unos 4 días encendido). **La causa exacta no se investigó ni se confirmó.**

## Qué salió bien

- Los datos quedaron íntegros: ninguna transferencia confirmada se perdió y ninguna fallida se guardó (idempotencia y transacciones).
- La recuperación fue rápida una vez identificado el problema.
- El respaldo y la restauración funcionaron (ejercicio de desastre posterior: restauración en 1 s).

## Qué salió mal

1. **Las alertas no vieron la caída.** Ninguna alerta de disponibilidad se activó en 10 minutos:
   - 586 de los 589 errores los devolvió el Ingress (503), que las métricas de la API no cuentan.
   - Los pocos errores que sí vio la API fueron un pico breve, menor al minuto que exige la alerta rápida.
   - `BancaAPISinInstancias` no se activó porque Prometheus siguió leyendo las métricas de las pods aunque Kubernetes las marcara como "no listas".
2. **El diagnóstico fue manual** y tomó unos 7 minutos desde el inicio hasta ver el error de Calico.
3. **Pérdida silenciosa de datos en el desastre posterior.** Al perderse el volumen, la base reapareció vacía y la API siguió respondiendo sin errores 5xx; ningún SLO lo detecta.
4. **RPO alto por respaldo manual:** se perdieron 274 transferencias (4 min 40 s de datos).
5. **Observación no investigada:** el contador de reinicios de las pods de la API subió en cada caída de la base.

## Acciones de mejora

Todas son propuestas: ninguna está implementada ni probada.

| # | Acción | Motivo |
|---|---|---|
| 1 | Alerta cuando `/health/ready` devuelve 503 de forma sostenida | Detectar base caída aunque el Ingress responda los errores |
| 2 | Medir disponibilidad desde el Ingress o con una prueba externa | Que el SLI vea lo que ve el cliente |
| 3 | Respaldo automático cada 5 minutos y copia fuera del equipo | Reducir el RPO |
| 4 | Vigilar Calico (y revisar su versión) | Evitar un nuevo bloqueo por credencial |
| 5 | Alerta de integridad (caída brusca en el conteo de transferencias) | Detectar pérdida silenciosa de datos |
| 6 | Revisar por qué se reinician las pods de la API al caer la base | Entender el reinicio observado |
| 7 | Archivado de WAL para llevar el RPO cerca de cero | Mejora a futuro |
