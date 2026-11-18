-- =====================================================================
--  V7 - Cargos y movimientos de dinero
--
--  Lo que deben los socios (charges), los movimientos manuales de
--  ingresos y egresos, las transferencias entre cuentas propias y los
--  cheques. Depende de V2 a V6.
--  checks va al final porque apunta a las otras tres.
-- =====================================================================


-- ---------------------------------------------------------------------
--  charges
-- ---------------------------------------------------------------------
CREATE TABLE charges (
  id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  billing_period_id    INT            NOT NULL,
  member_id            INT            NOT NULL,
  billed_to_person_id  INT            NOT NULL,
  charge_type          charge_type    NOT NULL,
  enrollment_id        BIGINT,                     -- solo actividades
  concept_id           INT            NOT NULL,
  description          VARCHAR(120)   NOT NULL,    -- Voley femenino - Marzo 2026
  amount               DECIMAL(12,2)  NOT NULL,
  income_account_id    INT            NOT NULL,
  due_date             DATE,
  status               charge_status  NOT NULL DEFAULT 'PENDING',
  payment_id           BIGINT,
  cancelled_on         DATE,
  cancelled_reason     VARCHAR(250),
  created_at           TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT fk_charges_period         FOREIGN KEY (billing_period_id)   REFERENCES billing_periods (id),
  CONSTRAINT fk_charges_member         FOREIGN KEY (member_id)           REFERENCES members (id),
  CONSTRAINT fk_charges_billed_to      FOREIGN KEY (billed_to_person_id) REFERENCES people (id),
  CONSTRAINT fk_charges_enrollment     FOREIGN KEY (enrollment_id)       REFERENCES enrollments (id),
  CONSTRAINT fk_charges_concept        FOREIGN KEY (concept_id)          REFERENCES billable_concepts (id),
  CONSTRAINT fk_charges_income_account FOREIGN KEY (income_account_id)   REFERENCES accounts (id),
  CONSTRAINT fk_charges_payment        FOREIGN KEY (payment_id)          REFERENCES payments (id),

  CONSTRAINT ck_charges_amount CHECK (amount >= 0),
  -- Pagado si y solo si tiene pago.
  CONSTRAINT ck_charges_paid
    CHECK ((status = 'PAID') = (payment_id IS NOT NULL)),
  -- Actividad si y solo si tiene inscripción.
  CONSTRAINT ck_charges_activity_enrollment
    CHECK ((charge_type = 'ACTIVITY') = (enrollment_id IS NOT NULL)),
  -- Anulado si y solo si tiene fecha de anulación.
  CONSTRAINT ck_charges_cancellation
    CHECK ((status = 'CANCELLED') = (cancelled_on IS NOT NULL))
);

CREATE INDEX ix_charges_member_status ON charges (member_id, status);

CREATE INDEX ix_charges_period ON charges (billing_period_id);

-- El JOIN de la vista contable. Parcial: los impagos no interesan ahi.
CREATE INDEX ix_charges_payment
  ON charges (payment_id)
  WHERE payment_id IS NOT NULL;

CREATE INDEX ix_charges_account ON charges (income_account_id);

-- La doble generación se impide en la base. Son dos índices y no uno
-- porque enrollment_id es nulo en la cuota social, y dos nulos no se
-- consideran iguales. Excluyen los anulados: si no, un cargo anulado
-- impediría para siempre volver a emitir ese mes.
-- Los OTHER quedan fuera de los dos: un socio puede tener varios.
CREATE UNIQUE INDEX ux_charges_membership
  ON charges (member_id, billing_period_id)
  WHERE charge_type = 'MEMBERSHIP' AND status <> 'CANCELLED';

CREATE UNIQUE INDEX ux_charges_activity
  ON charges (enrollment_id, billing_period_id)
  WHERE charge_type = 'ACTIVITY' AND status <> 'CANCELLED';


-- ---------------------------------------------------------------------
--  cash_transactions
--  Importe siempre positivo: el sentido lo dice direction.
-- ---------------------------------------------------------------------
CREATE TABLE cash_transactions (
  id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  direction             transaction_direction  NOT NULL,
  result_account_id     INT                    NOT NULL,
  financial_account_id  INT                    NOT NULL,
  payment_method_id     INT                    NOT NULL,
  transaction_date      DATE                   NOT NULL,
  description           VARCHAR(200)           NOT NULL,
  total_amount          DECIMAL(12,2)          NOT NULL,
  third_party_id        INT,                         -- contraparte registrada
  third_party_name      VARCHAR(120),                -- contraparte ocasional
  receipt_number        VARCHAR(20),                 -- solo INCOME: comprobante nuestro
  document_type         fiscal_document_type,        -- solo EXPENSE: comprobante ajeno
  document_number       VARCHAR(30),
  document_date         DATE,
  status                record_status          NOT NULL DEFAULT 'ACTIVE',
  cancelled_on          DATE,
  cancelled_reason      VARCHAR(200),
  cancelled_by_user_id  INT,
  created_by_user_id    INT,
  created_at            TIMESTAMPTZ            NOT NULL DEFAULT now(),

  CONSTRAINT fk_ct_result_account    FOREIGN KEY (result_account_id)    REFERENCES accounts (id),
  CONSTRAINT fk_ct_financial_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts (id),
  CONSTRAINT fk_ct_payment_method    FOREIGN KEY (payment_method_id)    REFERENCES payment_methods (id),
  CONSTRAINT fk_ct_third_party       FOREIGN KEY (third_party_id)       REFERENCES third_parties (id),
  CONSTRAINT fk_ct_cancelled_by      FOREIGN KEY (cancelled_by_user_id) REFERENCES users (id),
  CONSTRAINT fk_ct_created_by        FOREIGN KEY (created_by_user_id)   REFERENCES users (id),

  CONSTRAINT ck_ct_amount CHECK (total_amount > 0),
  -- El comprobante propio solo existe en ingresos.
  CONSTRAINT ck_ct_receipt_only_income
    CHECK (direction = 'INCOME' OR receipt_number IS NULL),
  -- El comprobante ajeno solo existe en egresos.
  CONSTRAINT ck_ct_document_only_expense
    CHECK (direction = 'EXPENSE'
           OR (document_number IS NULL AND document_date IS NULL
               AND document_type IS NULL)),
  -- La contraparte se identifica de una sola forma.
  CONSTRAINT ck_ct_counterparty
    CHECK (third_party_id IS NULL OR third_party_name IS NULL),
  CONSTRAINT ck_ct_cancellation
    CHECK ((status = 'CANCELLED') = (cancelled_on IS NOT NULL)),
  CONSTRAINT ck_ct_doc_date
    CHECK (document_date IS NULL OR document_date <= transaction_date)
);

-- Los tres que usa la vista contable. Parciales porque las anuladas
-- nunca aparecen en un reporte.
CREATE INDEX ix_ct_account_date
  ON cash_transactions (financial_account_id, transaction_date)
  WHERE status = 'ACTIVE';

CREATE INDEX ix_ct_result_date
  ON cash_transactions (result_account_id, transaction_date)
  WHERE status = 'ACTIVE';

CREATE INDEX ix_ct_date
  ON cash_transactions (transaction_date)
  WHERE status = 'ACTIVE';

-- "Todo lo que le pagamos a este proveedor".
CREATE INDEX ix_ct_third_party
  ON cash_transactions (third_party_id, transaction_date);

-- Único solo donde hay número: todos los egresos lo tienen nulo.
CREATE UNIQUE INDEX ux_ct_receipt_number
  ON cash_transactions (receipt_number)
  WHERE receipt_number IS NOT NULL;


-- ---------------------------------------------------------------------
--  account_transfers
--  Una sola fila con origen y destino: no puede existir media
--  transferencia. La vista la abre en una salida y una entrada.
-- ---------------------------------------------------------------------
CREATE TABLE account_transfers (
  id                         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  from_financial_account_id  INT            NOT NULL,
  to_financial_account_id    INT            NOT NULL,
  transfer_date              DATE           NOT NULL,
  amount                     DECIMAL(12,2)  NOT NULL,
  description                VARCHAR(200),
  status                     record_status  NOT NULL DEFAULT 'ACTIVE',
  cancelled_on               DATE,
  cancelled_reason           VARCHAR(200),
  cancelled_by_user_id       INT,
  created_by_user_id         INT,
  created_at                 TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT fk_at_from         FOREIGN KEY (from_financial_account_id) REFERENCES financial_accounts (id),
  CONSTRAINT fk_at_to           FOREIGN KEY (to_financial_account_id)   REFERENCES financial_accounts (id),
  CONSTRAINT fk_at_cancelled_by FOREIGN KEY (cancelled_by_user_id)      REFERENCES users (id),
  CONSTRAINT fk_at_created_by   FOREIGN KEY (created_by_user_id)        REFERENCES users (id),

  CONSTRAINT ck_at_amount   CHECK (amount > 0),
  CONSTRAINT ck_at_distinct CHECK (from_financial_account_id <> to_financial_account_id),
  CONSTRAINT ck_at_cancellation
    CHECK ((status = 'CANCELLED') = (cancelled_on IS NOT NULL))
);

-- Dos índices y no uno: la vista consulta la tabla una vez por punta.
CREATE INDEX ix_at_from ON account_transfers (from_financial_account_id, transfer_date);
CREATE INDEX ix_at_to   ON account_transfers (to_financial_account_id, transfer_date);
CREATE INDEX ix_at_date ON account_transfers (transfer_date);


-- ---------------------------------------------------------------------
--  checks
-- ---------------------------------------------------------------------
CREATE TABLE checks (
  id                            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  direction                     check_direction  NOT NULL,
  check_number                  VARCHAR(30)      NOT NULL,
  bank_name                     VARCHAR(80)      NOT NULL,
  amount                        DECIMAL(12,2)    NOT NULL,
  issue_date                    DATE             NOT NULL,
  due_date                      DATE             NOT NULL,
  is_electronic                 BOOLEAN          NOT NULL DEFAULT false,
  issuer_name                   VARCHAR(120),
  issuer_tax_id                 VARCHAR(20),
  payment_id                    BIGINT,
  received_cash_transaction_id  BIGINT,
  spent_cash_transaction_id     BIGINT,
  deposit_transfer_id           BIGINT,
  status                        check_status     NOT NULL,
  rejection_reason              VARCHAR(200),
  cancelled_reason              VARCHAR(200),
  notes                         TEXT,
  created_by_user_id            INT,
  created_at                    TIMESTAMPTZ      NOT NULL DEFAULT now(),
  updated_at                    TIMESTAMPTZ      NOT NULL DEFAULT now(),

  CONSTRAINT fk_checks_payment     FOREIGN KEY (payment_id)                   REFERENCES payments (id),
  CONSTRAINT fk_checks_received_tx FOREIGN KEY (received_cash_transaction_id) REFERENCES cash_transactions (id),
  CONSTRAINT fk_checks_spent_tx    FOREIGN KEY (spent_cash_transaction_id)    REFERENCES cash_transactions (id),
  CONSTRAINT fk_checks_deposit     FOREIGN KEY (deposit_transfer_id)          REFERENCES account_transfers (id),
  CONSTRAINT fk_checks_created_by  FOREIGN KEY (created_by_user_id)           REFERENCES users (id),

  -- ---- Básicos ----
  CONSTRAINT ck_checks_amount CHECK (amount > 0),
  CONSTRAINT ck_checks_dates  CHECK (due_date >= issue_date),
  CONSTRAINT ck_checks_rejection
    CHECK ((status = 'REJECTED') = (rejection_reason IS NOT NULL)),
  CONSTRAINT ck_checks_cancellation
    CHECK ((status = 'CANCELLED') = (cancelled_reason IS NOT NULL)),

  -- ---- Entrada: de donde vino ----
  -- Como mucho un origen.
  CONSTRAINT ck_checks_single_entry
    CHECK (NOT (payment_id IS NOT NULL AND received_cash_transaction_id IS NOT NULL)),
  -- Un recibido tiene exactamente uno; un emitido, ninguno.
  CONSTRAINT ck_checks_entry_by_direction
    CHECK ((direction = 'RECEIVED')
           = (payment_id IS NOT NULL OR received_cash_transaction_id IS NOT NULL)),

  -- ---- Salida: endoso o emisión ----
  -- Un emitido nace con su gasto.
  CONSTRAINT ck_checks_issued_spent
    CHECK (direction = 'RECEIVED' OR spent_cash_transaction_id IS NOT NULL),
  -- En un recibido, el gasto existe si y solo si fue endosado.
  CONSTRAINT ck_checks_endorsed
    CHECK (direction = 'ISSUED'
           OR (status = 'ENDORSED') = (spent_cash_transaction_id IS NOT NULL)),

  -- ---- Depósito ----
  -- Un emitido nunca se deposita.
  CONSTRAINT ck_checks_issued_no_deposit
    CHECK (direction = 'RECEIVED' OR deposit_transfer_id IS NULL),
  -- En un recibido, la transferencia existe si y solo si paso por el banco.
  CONSTRAINT ck_checks_deposited
    CHECK (direction = 'ISSUED'
           OR (deposit_transfer_id IS NOT NULL)
              = (status IN ('DEPOSITED', 'CLEARED', 'REJECTED'))),

  -- ---- Estados válidos según dirección ----
  CONSTRAINT ck_checks_issued_status
    CHECK (direction = 'RECEIVED'
           OR status IN ('DELIVERED', 'CLEARED', 'REJECTED', 'CANCELLED')),
  CONSTRAINT ck_checks_received_status
    CHECK (direction = 'ISSUED' OR status <> 'DELIVERED')
);

-- Red contra la doble carga del mismo cheque recibido. El CUIT es
-- opcional: con COALESCE, dos cargas sin CUIT también chocan (sin el,
-- PostgreSQL no compara nulos y las dos pasarían).
CREATE UNIQUE INDEX ux_checks_received
  ON checks (bank_name, check_number, COALESCE(issuer_tax_id, ''))
  WHERE direction = 'RECEIVED';

-- Una transferencia de depósito por cheque.
CREATE UNIQUE INDEX ux_checks_deposit_transfer
  ON checks (deposit_transfer_id)
  WHERE deposit_transfer_id IS NOT NULL;

-- "Que cheques tengo por vencer". Parcial: acreditados, rechazados y
-- anulados ya no interesan.
CREATE INDEX ix_checks_due
  ON checks (due_date)
  WHERE status IN ('IN_PORTFOLIO', 'DEPOSITED');

CREATE INDEX ix_checks_status ON checks (status);

-- Un solo cheque por pago.
CREATE UNIQUE INDEX ux_checks_payment
    ON checks (payment_id)
    WHERE payment_id IS NOT NULL;

CREATE INDEX ix_checks_received_tx
  ON checks (received_cash_transaction_id)
  WHERE received_cash_transaction_id IS NOT NULL;

CREATE INDEX ix_checks_spent_tx
  ON checks (spent_cash_transaction_id)
  WHERE spent_cash_transaction_id IS NOT NULL;
