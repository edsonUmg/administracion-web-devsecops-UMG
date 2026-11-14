# Fase 5: GitOps con Argo CD y despliegue Canary con rollback automático

## Qué se hizo
- Prometheus mínimo (kube-prometheus-stack) instalado con Terraform en el namespace `observabilidad`; recolecta las métricas de la API mediante un ServiceMonitor.
- Argo CD y Argo Rollouts instalados con Terraform en el namespace `gitops`, con versiones fijas.
- La API pasó de Deployment a Rollout (5 réplicas) con estrategia Canary: 20 % → pausa 60 s → 50 % → pausa 60 s → 100 %.
- Un AnalysisTemplate consulta a Prometheus la tasa de éxito (respuestas no 5xx) de la versión nueva. Si baja de 99 % de forma repetida, el Rollout se aborta y vuelve a la versión estable.
- Argo CD (Application `banca`) despliega el chart `helm/banca` desde Git, con sincronización automática (prune + selfHeal).

## Prueba realizada (hora local, 13-nov-2026)
1. Se cambió en Git la imagen a `1.0.1` (Canary sano): análisis exitoso, 100 % de pods nuevos.
2. Se cambió a `1.0.2` y se inyectó un fallo en el pod canary (`POST /admin/fallo?pct=50`) a las 19:13:51.
3. Mediciones del análisis: 19:14:14 = 1 (correcta), 19:14:29 = 0.6677 (falla), 19:14:44 = 0.6604 (falla).
4. Tras la segunda falla (`failureLimit: 1`) el Rollout se abortó (`RolloutAborted`) y se recuperaron los 5 pods estables. Detección y aborto: unos 53 s; recuperación total: menos de 60 s.
5. Se revirtió el cambio en Git y se volvió a la imagen base `1.0.0` mediante Canary sano. Estado final: Argo CD `Synced` / `Healthy`.

## Limitaciones (honestas)
- Las imágenes 1.0.1 y 1.0.2 son el mismo código con distinta etiqueta, cargadas localmente en el nodo kind (no vienen de GHCR). El fallo se simula con un endpoint de inyección.
- Los porcentajes del Canary se aproximan con la cantidad de pods (no hay un router de tráfico como Istio o NGINX por peso).
- El análisis necesita tráfico; en la prueba se usó un generador de carga con `curl`.
- Prometheus tarda unos segundos en reflejar el fallo, por eso la primera medición todavía salió correcta.
- Entorno local de laboratorio (WSL2 + Docker Desktop + kind), no producción.

## Evidencias
Capturas E5-01 a E5-12 (en el documento Word del proyecto).
