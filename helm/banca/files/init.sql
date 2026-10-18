-- Datos 100% ficticios (laboratorio). No usar datos personales reales.
CREATE TABLE IF NOT EXISTS cuentas (
  id      BIGSERIAL PRIMARY KEY,
  titular TEXT NOT NULL,
  saldo   NUMERIC(14,2) NOT NULL CHECK (saldo >= 0)
);
CREATE TABLE IF NOT EXISTS transferencias (
  id                 BIGSERIAL PRIMARY KEY,
  origen             BIGINT NOT NULL REFERENCES cuentas(id),
  destino            BIGINT NOT NULL REFERENCES cuentas(id),
  monto              NUMERIC(14,2) NOT NULL CHECK (monto > 0),
  clave_idempotencia TEXT NOT NULL UNIQUE,
  creada_en          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (origen <> destino)
);
INSERT INTO cuentas (titular, saldo)
SELECT * FROM (VALUES ('Cuenta Demo A', 10000.00),
                      ('Cuenta Demo B',  5000.00),
                      ('Cuenta Demo C',  2500.00)) v
WHERE NOT EXISTS (SELECT 1 FROM cuentas);
