-- =====================================================================
--  R__v_cash_movements - El libro de caja
--
--  Migracion REPETIBLE: se vuelve a crear cada vez que cambia este
--  archivo. Se borra y se crea de nuevo porque CREATE OR REPLACE VIEW
--  no admite cambiar las columnas.
--
--  Une todo lo que movio plata, una fila por movimiento:
--    1. Cobranza a socios, abierta POR CARGO: un recibo que cubre cuota
--       social, voley y natacion da tres filas, cada una con su cuenta
--       de ingreso. La clasificacion vive en los cargos, no en el pago.
--    2. Movimientos manuales: gastos e ingresos varios.
--    3 y 4. Transferencias entre cuentas propias, abiertas en una
--       salida y una entrada. Sin cuenta de resultado: no son ingreso
--       ni egreso, pero sin ellas el resumen bancario no cierra.
--
--  direction es 'IN' / 'OUT', el sentido de la plata. En
--  cash_transactions la columna dice INCOME / EXPENSE, y se traduce:
--  una transferencia es entrada y salida, pero no ingreso ni egreso.
--
--  Vista y no tabla: todo es reconstruible desde sus origenes, asi que
--  no se puede desincronizar. Si alguna vez se permite EDITAR pagos o
--  movimientos (hoy solo se anulan), hay que volver a una tabla.
--
--  Los tres reportes del contador son esta vista filtrada distinto:
--    - por cuenta:   GROUP BY result_account_id
--                    WHERE result_account_id IS NOT NULL
--                    (el IS NOT NULL saca las transferencias)
--    - del mes:      WHERE direction = 'IN' AND movement_date BETWEEN ...
--    - por cuenta financiera: WHERE financial_account_id = ...
--
--  OJO: COUNT(*) cuenta movimientos, no recibos. La cantidad de cobros
--  sale de payments.
-- =====================================================================

DROP VIEW IF EXISTS v_cash_movements;

CREATE VIEW v_cash_movements AS

-- 1. Cobranza a socios, una fila por cargo
SELECT
    'PAYMENT'                AS source_type,
    p.id                     AS source_id,
    p.paid_on                AS movement_date,
    'IN'                     AS direction,
    c.income_account_id      AS result_account_id,
    p.financial_account_id   AS financial_account_id,
    c.amount                 AS amount,
    c.description            AS description,
    p.receipt_number         AS reference
FROM charges c
JOIN payments p ON p.id = c.payment_id
WHERE p.status = 'ACTIVE'
  AND c.status = 'PAID'

UNION ALL

-- 2. Movimientos manuales: gastos e ingresos varios
SELECT
    'TRANSACTION',
    t.id,
    t.transaction_date,
    CASE t.direction WHEN 'INCOME' THEN 'IN' ELSE 'OUT' END,
    t.result_account_id,
    t.financial_account_id,
    t.total_amount,
    t.description,
    COALESCE(t.receipt_number, t.document_number)
FROM cash_transactions t
WHERE t.status = 'ACTIVE'

UNION ALL

-- 3. Transferencias: la punta que sale
SELECT
    'TRANSFER_OUT',
    tr.id,
    tr.transfer_date,
    'OUT',
    NULL,
    tr.from_financial_account_id,
    tr.amount,
    tr.description,
    NULL
FROM account_transfers tr
WHERE tr.status = 'ACTIVE'

UNION ALL

-- 4. Transferencias: la punta que entra
SELECT
    'TRANSFER_IN',
    tr.id,
    tr.transfer_date,
    'IN',
    NULL,
    tr.to_financial_account_id,
    tr.amount,
    tr.description,
    NULL
FROM account_transfers tr
WHERE tr.status = 'ACTIVE';
