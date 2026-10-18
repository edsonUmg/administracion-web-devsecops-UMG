'use strict';
const { Pool } = require('pg');
const { DomainError } = require('./errors');

// Conexión por variables PGHOST, PGUSER, PGPASSWORD, PGDATABASE (nunca en código).
function createDb(pool = new Pool({ max: 10, connectionTimeoutMillis: 3000 })) {
  return {
    ping: () => pool.query('SELECT 1'),

    async getCuenta(id) {
      const r = await pool.query(
        'SELECT id, titular, saldo FROM cuentas WHERE id = $1', [id]);
      return r.rows[0] || null;
    },

    async transferir({ origen, destino, monto, clave }) {
      const c = await pool.connect();
      try {
        await c.query('BEGIN');
        const prev = await c.query(
          'SELECT id FROM transferencias WHERE clave_idempotencia = $1', [clave]);
        if (prev.rows[0]) {
          await c.query('ROLLBACK');
          return { id: prev.rows[0].id, repetida: true };
        }
        // Bloqueo en orden de id para evitar deadlocks entre transferencias cruzadas
        const ids = [origen, destino].sort((a, b) => a - b);
        const locked = await c.query(
          'SELECT id FROM cuentas WHERE id = ANY($1::bigint[]) ORDER BY id FOR UPDATE', [ids]);
        if (locked.rows.length !== 2) throw new DomainError('cuenta_inexistente', 404);

        const debit = await c.query(
          'UPDATE cuentas SET saldo = saldo - $1 WHERE id = $2 AND saldo >= $1', [monto, origen]);
        if (debit.rowCount === 0) throw new DomainError('fondos_insuficientes', 422);
        await c.query('UPDATE cuentas SET saldo = saldo + $1 WHERE id = $2', [monto, destino]);

        const ins = await c.query(
          `INSERT INTO transferencias (origen, destino, monto, clave_idempotencia)
           VALUES ($1, $2, $3, $4) RETURNING id`, [origen, destino, monto, clave]);
        await c.query('COMMIT');
        return { id: ins.rows[0].id, repetida: false };
      } catch (err) {
        await c.query('ROLLBACK').catch(() => {});
        if (err.code === '23505') throw new DomainError('transferencia_duplicada', 409);
        throw err;
      } finally {
        c.release();
      }
    },

    close: () => pool.end(),
  };
}

module.exports = { createDb };
