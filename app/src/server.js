'use strict';
const { createApp } = require('./app');
const { createDb } = require('./db');

const db = createDb();
const app = createApp({ db });
const port = Number(process.env.PORT || 8080);
const server = app.listen(port, '0.0.0.0', () =>
  console.log(JSON.stringify({ level: 'info', msg: 'Banco_MIBC_UMG API iniciada', port })));

// Cierre ordenado: Kubernetes envía SIGTERM en cada rollout (zero-downtime)
function shutdown(signal) {
  console.log(JSON.stringify({ level: 'info', msg: 'cierre ordenado', signal }));
  server.close(async () => {
    await db.close().catch(() => {});
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
