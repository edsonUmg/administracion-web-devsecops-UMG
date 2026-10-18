# Sección 1: Resumen Ejecutivo y Alcance (borrador)

**Sistema:** API de cuentas y transferencias de Banco_MIBC_UMG (laboratorio, datos ficticios).

**Objetivos de negocio:** (1) disponibilidad objetivo 99.99 %; (2) integridad transaccional
(transacciones ACID e idempotencia); (3) cumplimiento PCI-DSS v4.0, NIST SP 800-218 y normativa SIB;
(4) entrega continua sin interrupción del servicio.

**Justificación de arquitectura:** (completar con el grupo)
- Node.js: runtime ligero, imagen distroless pequeña, pocas dependencias.
- PostgreSQL: consistencia ACID y respaldo/restauración medibles para RTO/RPO.
- Kubernetes (kind) con zonas por namespace y NetworkPolicy de confianza cero.
- GitOps (Argo CD) y despliegue Canary con análisis automático de métricas.
