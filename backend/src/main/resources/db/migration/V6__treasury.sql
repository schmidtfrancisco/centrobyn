-- =====================================================================
--  V6 - Tesorería
--
--  Medios de pago, cuentas financieras, terceros y pagos de socios.
--  Depende de V2 (people, users, accounts).
--  Va antes que V7 porque charges apunta a payments.
-- =====================================================================


-- ---------------------------------------------------------------------
--  payment_methods
--  Tabla y no enum: un medio nuevo es un INSERT.
--  Lo usan los tres lados del dinero: pagos, movimientos manuales y
--  adhesiones de débito.
--  Nulo = sin restricción.
-- ---------------------------------------------------------------------
CREATE TABLE payment_methods (
  id                      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code                    VARCHAR(20),              -- CASH, TRANSFER, DEBIT, MP
  name                    VARCHAR(60)   NOT NULL,
  has_fee                 BOOLEAN       NOT NULL DEFAULT false,
  fee_percentage          DECIMAL(5,2),
  fee_expense_account_id  INT,                      -- donde va la comisión
  is_active               BOOLEAN       NOT NULL DEFAULT true,
  financial_account_type  financial_account_type,

  CONSTRAINT ux_pm_code UNIQUE (code),
  CONSTRAINT fk_pm_fee_account FOREIGN KEY (fee_expense_account_id) REFERENCES accounts (id),

  -- Sin comisión no hay porcentaje ni cuenta; con comisión, porcentaje.
  CONSTRAINT ck_pm_fee
    CHECK ((has_fee = false AND fee_percentage IS NULL
                            AND fee_expense_account_id IS NULL)
        OR (has_fee = true  AND fee_percentage IS NOT NULL)),
  CONSTRAINT ck_pm_fee_range
    CHECK (fee_percentage IS NULL OR fee_percentage BETWEEN 0 AND 100)
);


-- ---------------------------------------------------------------------
--  financial_accounts
-- ---------------------------------------------------------------------
CREATE TABLE financial_accounts (
  id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code          VARCHAR(20),
  name          VARCHAR(60)             NOT NULL,   -- Caja sede, Bco Provincia cta cte
  account_type  financial_account_type  NOT NULL,
  is_active     BOOLEAN                 NOT NULL DEFAULT true,
  account_id    INT                     NOT NULL,

  CONSTRAINT ux_fa_code UNIQUE (code),
  CONSTRAINT fk_fa_account FOREIGN KEY (account_id) REFERENCES accounts (id)
);


-- ---------------------------------------------------------------------
--  third_parties
--  No se unifica con people: CUIT y razón social contra DNI y fecha de
--  nacimiento; dirección fiscal contra particular.
-- ---------------------------------------------------------------------
CREATE TABLE third_parties (
  id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  legal_name  VARCHAR(120)  NOT NULL,     -- razón social
  tax_id      VARCHAR(20),                -- CUIT
  person_id   INT,
  email       VARCHAR(120),
  phone       VARCHAR(30),
  address     VARCHAR(150),
  notes       TEXT,
  is_active   BOOLEAN       NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT fk_tp_person FOREIGN KEY (person_id) REFERENCES people (id)
);

-- Los dos son opcionales: únicos solo donde hay dato.
CREATE UNIQUE INDEX ux_tp_tax_id
  ON third_parties (tax_id)
  WHERE tax_id IS NOT NULL;

CREATE UNIQUE INDEX ux_tp_person
  ON third_parties (person_id)
  WHERE person_id IS NOT NULL;

CREATE INDEX ix_tp_name ON third_parties (legal_name);


-- ---------------------------------------------------------------------
--  payments
-- ---------------------------------------------------------------------
CREATE TABLE payments (
  id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  receipt_number        VARCHAR(20)    NOT NULL,
  payer_person_id       INT,
  payment_method_id     INT            NOT NULL,
  financial_account_id  INT            NOT NULL,
  paid_on               DATE           NOT NULL,
  total_amount          DECIMAL(12,2)  NOT NULL,
  reference             VARCHAR(60),               -- nro de transferencia, etc.
  status                record_status  NOT NULL DEFAULT 'ACTIVE',
  cancelled_on          DATE,
  cancelled_reason      VARCHAR(200),
  cancelled_by_user_id  INT,
  received_by_user_id   INT,
  notes                 TEXT,
  created_at            TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT ux_payments_receipt UNIQUE (receipt_number),
  CONSTRAINT fk_payments_payer             FOREIGN KEY (payer_person_id)      REFERENCES people (id),
  CONSTRAINT fk_payments_method            FOREIGN KEY (payment_method_id)    REFERENCES payment_methods (id),
  CONSTRAINT fk_payments_financial_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts (id),
  CONSTRAINT fk_payments_cancelled_by      FOREIGN KEY (cancelled_by_user_id) REFERENCES users (id),
  CONSTRAINT fk_payments_received_by       FOREIGN KEY (received_by_user_id)  REFERENCES users (id),

  CONSTRAINT ck_payments_total        CHECK (total_amount > 0),
  CONSTRAINT ck_payments_cancellation CHECK ((status = 'CANCELLED') = (cancelled_on IS NOT NULL)),
  CONSTRAINT ck_payments_cancel_date  CHECK (cancelled_on IS NULL OR cancelled_on >= paid_on)
);

CREATE INDEX ix_payments_paid_on ON payments (paid_on);

CREATE INDEX ix_payments_account_date ON payments (financial_account_id, paid_on);

-- Pagos de una persona. Parcial: los pagos sin pagador no se buscan
-- por persona.
CREATE INDEX ix_payments_payer
  ON payments (payer_person_id)
  WHERE payer_person_id IS NOT NULL;
