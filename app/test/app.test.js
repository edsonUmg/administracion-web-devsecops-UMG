'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');
const { DomainError } = require('../src/errors');

const fakeDb = (over = {}) => ({
  ping: async () => {},
  getCuenta: async (id) => (id === 1 ? { id: '1', titular: 'Cuenta Demo A', saldo: '10000.00' } : null),
  transferir: async () => ({ id: '7', repetida: false }),
  ...over,
});

async function withServer(db, fn) {
  const srv = createApp({ db, adminToken: 'tok-test' }).listen(0, '127.0.0.1');
  await new Promise((r) => srv.once('listening', r));
  const base = `http://127.0.0.1:${srv.address().port}`;
  try { await fn(base); }
  finally { srv.closeAllConnections?.(); await new Promise((r) => srv.close(r)); }
}
const post = (url, body, headers = {}) =>
  fetch(url, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
const KEY = { 'Idempotency-Key': 'clave-0001-abcd' };

test('health/live responde ok', () => withServer(fakeDb(), async (b) => {
  const r = await fetch(`${b}/health/live`);
  assert.equal(r.status, 200);
}));

test('health/ready devuelve 503 si la BD cae', () =>
  withServer(fakeDb({ ping: async () => { throw new Error('down'); } }), async (b) => {
    assert.equal((await fetch(`${b}/health/ready`)).status, 503);
  }));

test('GET /cuentas/:id existente, inexistente e inválido', () => withServer(fakeDb(), async (b) => {
  assert.equal((await fetch(`${b}/cuentas/1`)).status, 200);
  assert.equal((await fetch(`${b}/cuentas/99`)).status, 404);
  assert.equal((await fetch(`${b}/cuentas/abc`)).status, 400);
}));

test('POST /transferencias exitosa', () => withServer(fakeDb(), async (b) => {
  const r = await post(`${b}/transferencias`, { origen: 1, destino: 2, monto: 100.5 }, KEY);
  assert.equal(r.status, 201);
}));

test('POST /transferencias valida entradas', () => withServer(fakeDb(), async (b) => {
  assert.equal((await post(`${b}/transferencias`, { origen: 1, destino: 1, monto: 5 }, KEY)).status, 400);
  assert.equal((await post(`${b}/transferencias`, { origen: 1, destino: 2, monto: -5 }, KEY)).status, 400);
  assert.equal((await post(`${b}/transferencias`, { origen: 1, destino: 2, monto: 1.234 }, KEY)).status, 400);
  assert.equal((await post(`${b}/transferencias`, { origen: 1, destino: 2, monto: 5 })).status, 400);
}));

test('fondos insuficientes devuelve 422', () =>
  withServer(fakeDb({ transferir: async () => { throw new DomainError('fondos_insuficientes', 422); } }), async (b) => {
    assert.equal((await post(`${b}/transferencias`, { origen: 1, destino: 2, monto: 9 }, KEY)).status, 422);
  }));

test('/admin/fallo exige token y provoca errores 500', () => withServer(fakeDb(), async (b) => {
  assert.equal((await post(`${b}/admin/fallo?pct=100`, {})).status, 403);
  assert.equal((await post(`${b}/admin/fallo?pct=100`, {}, { 'x-admin-token': 'tok-test' })).status, 200);
  assert.equal((await fetch(`${b}/cuentas/1`)).status, 500);
  assert.equal((await fetch(`${b}/health/live`)).status, 200); // las probes no se afectan
}));

test('/metrics expone métricas Prometheus', () => withServer(fakeDb(), async (b) => {
  await fetch(`${b}/cuentas/1`);
  const txt = await (await fetch(`${b}/metrics`)).text();
  assert.match(txt, /http_requests_total\{.*route="\/cuentas\/:id"/);
  assert.match(txt, /http_request_duration_seconds_bucket/);
}));
