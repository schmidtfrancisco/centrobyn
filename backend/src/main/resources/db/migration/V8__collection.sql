-- =====================================================================
--  V8 - Cobranza a domicilio y debito automatico
--
--  Dos formas de cobrar que no inventan un circuito propio: las dos
--  terminan en un payment comun, igual que el cobro en ventanilla.
--  Depende de V3 (members), V5 (billing_periods), V6 (payments,
--  financial_accounts, payment_methods) y V7 (charges).
-- =====================================================================


-- ---------------------------------------------------------------------
--  collectors
--  Rol de cobrador sobre people, igual que teachers.
--  Cada cobrador tiene su cuenta financiera "Cobranza a rendir" (tipo
--  TO_SETTLE): su saldo dice cuanta plata tiene sin rendir. Que la
--  cuenta sea de ese tipo lo valida el servicio.
--  Persona y cuenta son unicas entre los ACTIVOS, no en toda la tabla:
--  el reemplazo de un cobrador que se fue puede usar su misma cuenta.
--  commission_percentage es provisoria: todavia no se sabe como se
--  calcula la comision. Si se renegocia con el tiempo, entra una tabla
--  con valid_from, como los demas precios.
-- ---------------------------------------------------------------------
CREATE TABLE collectors (
  id                     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  person_id              INT           NOT NULL,
  financial_account_id   INT           NOT NULL,
  commission_percentage  DECIMAL(5,2),
  is_active              BOOLEAN       NOT NULL DEFAULT true,
  notes                  TEXT,
  created_at             TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT fk_collectors_person            FOREIGN KEY (person_id)            REFERENCES people (id),
  CONSTRAINT fk_collectors_financial_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts (id),

  CONSTRAINT ck_collectors_commission
    CHECK (commission_percentage IS NULL OR commission_percentage BETWEEN 0 AND 100)
);

CREATE UNIQUE INDEX ux_collectors_person_active
  ON collectors (person_id)
  WHERE is_active;

-- Dos cobradores activos nunca comparten cuenta: mezclarian rendiciones.
CREATE UNIQUE INDEX ux_collectors_account_active
  ON collectors (financial_account_id)
  WHERE is_active;


-- ---------------------------------------------------------------------
--  collection_assignments
--  La cartera del cobrador y el resultado de cada visita.
--  Los cobros exitosos se reconstruyen desde payments; los FRACASOS no
--  ("no habia nadie", "paga la semana que viene", "se nego"): esa
--  informacion solo existe aca, y es la que la secretaria necesita
--  para saber a quien llamar.
--  El importe a cobrar no se guarda: se calcula de los cargos
--  pendientes al momento de la visita.
--  payment_id solo si cobro.
-- ---------------------------------------------------------------------
CREATE TABLE collection_assignments (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  collector_id       INT           NOT NULL,
  member_id          INT           NOT NULL,
  billing_period_id  INT           NOT NULL,
  result             visit_result  NOT NULL DEFAULT 'PENDING',
  visit_notes        VARCHAR(200),
  visited_on         DATE,
  payment_id         BIGINT,
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),

  -- Un socio no le toca a dos cobradores el mismo mes: lo visitarian
  -- dos veces y se pagarian dos comisiones.
  CONSTRAINT ux_ca_member_period UNIQUE (member_id, billing_period_id),
  CONSTRAINT fk_ca_collector FOREIGN KEY (collector_id)      REFERENCES collectors (id),
  CONSTRAINT fk_ca_member    FOREIGN KEY (member_id)         REFERENCES members (id),
  CONSTRAINT fk_ca_period    FOREIGN KEY (billing_period_id) REFERENCES billing_periods (id),
  CONSTRAINT fk_ca_payment   FOREIGN KEY (payment_id)        REFERENCES payments (id),

  -- Pendiente si y solo si todavia no se visito.
  CONSTRAINT ck_ca_visited
    CHECK ((result = 'PENDING') = (visited_on IS NULL)),
  -- Cobrada si y solo si tiene pago.
  CONSTRAINT ck_ca_payment
    CHECK ((result = 'COLLECTED') = (payment_id IS NOT NULL))
);

CREATE INDEX ix_ca_collector ON collection_assignments (collector_id, billing_period_id);

-- "Que me falta visitar": la consulta del celular del cobrador.
CREATE INDEX ix_ca_pending
  ON collection_assignments (collector_id)
  WHERE result = 'PENDING';


-- ---------------------------------------------------------------------
--  debit_mandates
--  La autorizacion de debito: alguien firmo "debitenme de esta cuenta".
--  Es de la CUENTA BANCARIA, no del socio: suele debitarse a varios
--  socios de una familia desde la misma cuenta. Asi el CBU vive en un
--  solo lugar y un cambio de banco se actualiza una vez.
--  payer_person_id = titular de la cuenta (suele ser un familiar).
--  Nunca se guarda el numero de tarjeta completo, solo los ultimos
--  cuatro digitos. El CBU se muestra enmascarado.
-- ---------------------------------------------------------------------
CREATE TABLE debit_mandates (
  id                   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payer_person_id      INT                   NOT NULL,
  payment_method_id    INT                   NOT NULL,    -- debito en cuenta o en tarjeta
  cbu                  VARCHAR(22),
  card_last_four       VARCHAR(4),
  bank_name            VARCHAR(80),
  account_holder_name  VARCHAR(120),
  status               debit_mandate_status  NOT NULL DEFAULT 'ACTIVE',
  authorized_on        DATE                  NOT NULL,
  cancelled_on         DATE,
  cancelled_reason     VARCHAR(200),
  notes                TEXT,
  created_at           TIMESTAMPTZ           NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ           NOT NULL DEFAULT now(),

  CONSTRAINT fk_dm_payer  FOREIGN KEY (payer_person_id)   REFERENCES people (id),
  CONSTRAINT fk_dm_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id),

  -- Una cuenta o una tarjeta, al menos una.
  CONSTRAINT ck_dm_account
    CHECK (cbu IS NOT NULL OR card_last_four IS NOT NULL),
  CONSTRAINT ck_dm_cancel
    CHECK ((status = 'CANCELLED') = (cancelled_on IS NOT NULL))
);

CREATE INDEX ix_dm_payer  ON debit_mandates (payer_person_id);
CREATE INDEX ix_dm_status ON debit_mandates (status);


-- ---------------------------------------------------------------------
--  debit_mandate_members
--  A que socios cubre cada autorizacion. Se suma un hijo, se saca otro,
--  sin tocar la autorizacion.
--  Al salir se llena removed_on: no se borra, porque los lotes viejos
--  que lo incluian siguen teniendo sentido.
-- ---------------------------------------------------------------------
CREATE TABLE debit_mandate_members (
  id                INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  debit_mandate_id  INT          NOT NULL,
  member_id         INT          NOT NULL,
  added_on          DATE         NOT NULL,
  removed_on        DATE,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ux_dmm_mandate_member UNIQUE (debit_mandate_id, member_id),
  CONSTRAINT fk_dmm_mandate FOREIGN KEY (debit_mandate_id) REFERENCES debit_mandates (id),
  CONSTRAINT fk_dmm_member  FOREIGN KEY (member_id)        REFERENCES members (id),

  CONSTRAINT ck_dmm_dates
    CHECK (removed_on IS NULL OR removed_on >= added_on)
);

CREATE INDEX ix_dmm_member ON debit_mandate_members (member_id);

-- La regla que importa: un socio no puede estar en dos adhesiones
-- activas a la vez, o se le debitaria dos veces.
CREATE UNIQUE INDEX ux_dmm_member_active
  ON debit_mandate_members (member_id)
  WHERE removed_on IS NULL;


-- ---------------------------------------------------------------------
--  debit_batches
--  La presentacion del mes al banco. Su trabajo mas importante es ser
--  una puerta: PRESENTED bloquea el cobro en ventanilla de los cargos
--  incluidos; PROCESSED impide importar dos veces la respuesta.
--  credited_on = fecha de acreditacion, de todo el lote: de ahi sale
--  el paid_on de los pagos generados. processed_on = cuando se importo
--  el archivo, que puede no coincidir.
-- ---------------------------------------------------------------------
CREATE TABLE debit_batches (
  id                  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  billing_period_id   INT                 NOT NULL,
  status              debit_batch_status  NOT NULL DEFAULT 'DRAFT',
  item_count          INT                 NOT NULL DEFAULT 0,
  total_amount        DECIMAL(12,2)       NOT NULL DEFAULT 0,
  generated_on        DATE,
  presented_on        DATE,
  credited_on         DATE,
  processed_on        DATE,
  response_file_name  VARCHAR(160),
  created_by_user_id  INT,
  created_at          TIMESTAMPTZ         NOT NULL DEFAULT now(),

  CONSTRAINT fk_db_period     FOREIGN KEY (billing_period_id)  REFERENCES billing_periods (id),
  CONSTRAINT fk_db_created_by FOREIGN KEY (created_by_user_id) REFERENCES users (id),

  CONSTRAINT ck_db_processed
    CHECK ((status = 'PROCESSED') = (processed_on IS NOT NULL))
);

CREATE INDEX ix_db_period ON debit_batches (billing_period_id);
CREATE INDEX ix_db_status ON debit_batches (status);

-- Un lote por periodo. Si el club hace una segunda presentacion para
-- los que rebotaron, este indice hay que sacarlo.
CREATE UNIQUE INDEX ux_db_period_active
  ON debit_batches (billing_period_id)
  WHERE status <> 'CANCELLED';


-- ---------------------------------------------------------------------
--  debit_batch_items
--  Una linea por adhesion: lo que se le pidio al banco y que contesto.
--  Los aceptados se reconstruyen desde payments; los RECHAZADOS no: el
--  motivo solo existe aca, y es lo que dice a quien llamar y si la
--  adhesion sigue sirviendo.
--  Un rechazado no escribe nada mas: nunca hubo pago, no hay que
--  revertir.
--  reference viaja al banco y vuelve: sirve para emparejar la respuesta.
-- ---------------------------------------------------------------------
CREATE TABLE debit_batch_items (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  debit_batch_id    INT                NOT NULL,
  debit_mandate_id  INT                NOT NULL,
  reference         VARCHAR(40)        NOT NULL,
  amount            DECIMAL(12,2)      NOT NULL,
  result            debit_item_result  NOT NULL DEFAULT 'PENDING',
  rejection_code    VARCHAR(20),
  rejection_reason  VARCHAR(200),
  payment_id        BIGINT,
  created_at        TIMESTAMPTZ        NOT NULL DEFAULT now(),

  CONSTRAINT ux_dbi_batch_reference UNIQUE (debit_batch_id, reference),
  CONSTRAINT fk_dbi_batch   FOREIGN KEY (debit_batch_id)   REFERENCES debit_batches (id),
  CONSTRAINT fk_dbi_mandate FOREIGN KEY (debit_mandate_id) REFERENCES debit_mandates (id),
  CONSTRAINT fk_dbi_payment FOREIGN KEY (payment_id)       REFERENCES payments (id),

  CONSTRAINT ck_dbi_amount CHECK (amount > 0),
  CONSTRAINT ck_dbi_rejection
    CHECK ((result = 'REJECTED') = (rejection_reason IS NOT NULL)),
  CONSTRAINT ck_dbi_payment
    CHECK ((result = 'ACCEPTED') = (payment_id IS NOT NULL))
);

CREATE INDEX ix_dbi_mandate ON debit_batch_items (debit_mandate_id);
CREATE INDEX ix_dbi_result  ON debit_batch_items (result);


-- ---------------------------------------------------------------------
--  debit_batch_item_charges
--  Que cargos exactos cubre cada linea, congelados AL PRESENTAR.
--  Recalcularlos al importar daria otro conjunto si en el medio se
--  genero un mes nuevo o se anulo un cargo. Con esta foto, al importar
--  se verifica que sigan pendientes, y el bloqueo del cobro en
--  ventanilla sabe exactamente que cargos estan en un lote presentado.
-- ---------------------------------------------------------------------
CREATE TABLE debit_batch_item_charges (
  id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  debit_batch_item_id  BIGINT  NOT NULL,
  charge_id            BIGINT  NOT NULL,

  CONSTRAINT ux_dbic_item_charge UNIQUE (debit_batch_item_id, charge_id),
  CONSTRAINT fk_dbic_item   FOREIGN KEY (debit_batch_item_id) REFERENCES debit_batch_items (id),
  CONSTRAINT fk_dbic_charge FOREIGN KEY (charge_id)           REFERENCES charges (id)
);

-- "Este cargo, esta en un lote presentado?": el bloqueo de ventanilla.
CREATE INDEX ix_dbic_charge ON debit_batch_item_charges (charge_id);
