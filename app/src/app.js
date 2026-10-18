'use strict';
const crypto = require('node:crypto');
const express = require('express');
const client = require('prom-client');
const { DomainError } = require('./errors');

const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const isId = (v) => Number.isSafeInteger(v) && v > 0;
const isMonto = (v) =>
  typeof v === 'number' && Number.isFinite(v) && v > 0 && v <= 1e9 &&
  Math.abs(v * 100 - Math.round(v * 100)) < 1e-6;

function safeEqual(a, b) {
  const ha = crypto.createHash('sha256').update(String(a)).digest();
  const hb = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(ha, hb);
}

function createApp({ db, adminToken = process.env.ADMIN_TOKEN } = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '10kb' }));

  // ---- Métricas (base de los SLI) ----
  const registry = new client.Registry();
  client.collectDefaultMetrics({ register: registry });
  const labelNames = ['method', 'route', 'status_code'];
  const httpDuration = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Latencia de peticiones HTTP',
    labelNames,
    buckets: [0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
    registers: [registry],
  });
  const httpTotal = new client.Counter({
    name: 'http_requests_total',
    help: 'Total de peticiones HTTP',
    labelNames,
    registers: [registry],
  });

  app.use((req, res, next) => {
    const end = httpDuration.startTimer();
    res.on('finish', () => {
      // route normalizada para no explotar la cardinalidad
      const route = req.route ? (req.baseUrl || '') + req.route.path : 'no_route';
      const labels = { method: req.method, route, status_code: res.statusCode };
      end(labels);
      httpTotal.inc(labels);
    });
    next();
  });

  // ---- Inyección de fallos (solo rutas de negocio) ----
  let failPct = 0;
  const injectFault = (req, res, next) =>
    failPct > 0 && Math.random() * 100 < failPct
      ? res.status(500).json({ error: 'fallo_inyectado' })
      : next();

  // ---- Probes y métricas ----
  app.get('/health/live', (req, res) => res.json({ status: 'ok' }));
  app.get('/health/ready', wrap(async (req, res) => {
    try {
      await db.ping();
      res.json({ status: 'ready' });
    } catch {
      res.status(503).json({ status: 'db_no_disponible' });
    }
  }));
  app.get('/metrics', wrap(async (req, res) => {
    res.set('Content-Type', registry.contentType);
    res.end(await registry.metrics());
  }));

  // ---- Negocio ----
  app.get('/cuentas/:id', injectFault, wrap(async (req, res) => {
    if (!/^\d{1,15}$/.test(req.params.id)) throw new DomainError('id_invalido', 400);
    const cuenta = await db.getCuenta(Number(req.params.id));
    if (!cuenta) throw new DomainError('cuenta_inexistente', 404);
    res.json(cuenta);
  }));

  app.post('/transferencias', injectFault, wrap(async (req, res) => {
    const { origen, destino, monto } = req.body || {};
    const clave = req.get('Idempotency-Key');
    if (!isId(origen) || !isId(destino) || origen === destino)
      throw new DomainError('cuentas_invalidas', 400);
    if (!isMonto(monto)) throw new DomainError('monto_invalido', 400);
    if (!clave || !/^[A-Za-z0-9-]{8,64}$/.test(clave))
      throw new DomainError('idempotency_key_requerida', 400);
    const r = await db.transferir({ origen, destino, monto, clave });
    res.status(r.repetida ? 200 : 201).json({ id: r.id, estado: 'completada' });
  }));

  // ---- Administración (protegida) ----
  app.post('/admin/fallo', (req, res) => {
    const token = req.get('x-admin-token');
    if (!adminToken || !token || !safeEqual(token, adminToken))
      return res.status(403).json({ error: 'prohibido' });
    const pct = Number(req.query.pct);
    if (!Number.isInteger(pct) || pct < 0 || pct > 100)
      return res.status(400).json({ error: 'pct_invalido' });
    failPct = pct;
    res.json({ fallo_pct: failPct });
  });

  app.use((req, res) => res.status(404).json({ error: 'ruta_inexistente' }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err instanceof DomainError) return res.status(err.status).json({ error: err.code });
    if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'json_invalido' });
    console.error(JSON.stringify({ level: 'error', msg: err.message }));
    res.status(500).json({ error: 'error_interno' });
  });

  return app;
}

module.exports = { createApp };

// PRUEBA NEGATIVA: patrón inseguro intencional (se descarta, no se mergea)
const { exec } = require('node:child_process');
module.exports.inseguro = (req) => exec('ls ' + req.query.dir);
