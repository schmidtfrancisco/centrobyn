-- =====================================================================
--  V9 - Configuracion del club y cola de correo
--
--  Va al final porque club_settings apunta a categorias y conceptos,
--  y email_deliveries a payments. Depende de V3, V5 y V6.
-- =====================================================================


-- ---------------------------------------------------------------------
--  club_settings
--  Parametros que no pertenecen a ninguna entidad y que el club puede
--  cambiar sin tocar codigo. UNA SOLA FILA, con columnas tipadas: no es
--  una tabla clave/valor, que no validaria nada.
--  Nadie la referencia: es estado del sistema, se lee por su id fijo.
--
--  id NO es identity: siempre vale 1. Con identity, un alta fallida
--  consumiria el 1 y la fila nunca mas se podria crear.
--
--  Tres talonarios de recibos, uno por serie. Cada serie lleva su
--  prefijo, que lo fija el codigo. Para asignar un numero: bloquear la
--  fila (SELECT ... FOR UPDATE), sumar uno y guardar, en la misma
--  transaccion que el pago. Si el pago falla se deshace todo y el
--  numero no se consume: por eso no quedan huecos. Anular un recibo NO
--  libera su numero.
--
--  ATENCION: cambiar grace_period_days cambia quien es moroso, al
--  instante y para atras. Es el unico parametro del modelo que reescribe
--  el pasado: la pantalla tiene que pedir confirmacion.
-- ---------------------------------------------------------------------
CREATE TABLE club_settings (
  id                              INT           PRIMARY KEY DEFAULT 1,
  club_name                       VARCHAR(120)  NOT NULL,
  grace_period_days               SMALLINT      NOT NULL DEFAULT 10,
  payment_due_day                 SMALLINT      NOT NULL DEFAULT 10,
  morosity_prolonged              SMALLINT      NOT NULL DEFAULT 60,   -- dias para el aviso de morosidad prolongada
  special_price_default_category  INT,                                 -- categoria con precio especial
  enrollment_concept_id           INT,                                 -- concepto del catalogo que es la inscripcion
  last_desk_receipt_number        BIGINT        NOT NULL DEFAULT 0,    -- cobranza en secretaria
  last_collector_receipt_number   BIGINT        NOT NULL DEFAULT 0,    -- cobranza a domicilio
  last_income_receipt_number      BIGINT        NOT NULL DEFAULT 0,    -- ingresos varios
  created_at                      TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at                      TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT fk_settings_special_category
    FOREIGN KEY (special_price_default_category) REFERENCES member_categories (id),
  CONSTRAINT fk_settings_enrollment_concept
    FOREIGN KEY (enrollment_concept_id) REFERENCES billable_concepts (id),

  -- Lo que garantiza que haya una sola fila.
  CONSTRAINT ck_settings_singleton CHECK (id = 1),
  CONSTRAINT ck_settings_grace     CHECK (grace_period_days BETWEEN 0 AND 90),
  -- Hasta 28 y no 31 por febrero.
  CONSTRAINT ck_settings_due_day   CHECK (payment_due_day BETWEEN 1 AND 28),
  CONSTRAINT ck_settings_receipts
    CHECK (last_desk_receipt_number >= 0
       AND last_collector_receipt_number >= 0
       AND last_income_receipt_number >= 0)
);


-- ---------------------------------------------------------------------
--  email_deliveries
--  Cola de correos salientes: recibos y recuperacion de contrasenia.
--  El mail NUNCA se envia dentro de la transaccion del pago: se guarda
--  el pago, se encola aca, y un proceso en segundo plano los envia y
--  reintenta los que fallan (patron outbox). Asi un servidor de correo
--  lento no deja al cobrador esperando en la puerta.
--  Ademas responde "le llego el recibo?" mirando el estado.
--
--  PURGA PENDIENTE: la tabla crece sin techo (un registro por recibo).
--  Se van a borrar los SENT con mas de un anio; los FAILED se conservan.
--  Se programa como tarea aparte, no en esta migracion.
-- ---------------------------------------------------------------------
CREATE TABLE email_deliveries (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  to_address  VARCHAR(120)  NOT NULL,
  subject     VARCHAR(200)  NOT NULL,
  template    VARCHAR(50)   NOT NULL,     -- RECEIPT | PASSWORD_RESET
  payload     TEXT,                       -- datos para armar el cuerpo
  status      email_status  NOT NULL DEFAULT 'PENDING',
  attempts    SMALLINT      NOT NULL DEFAULT 0,
  last_error  VARCHAR(300),
  payment_id  BIGINT,                     -- si es un recibo
  sent_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT fk_ed_payment FOREIGN KEY (payment_id) REFERENCES payments (id),

  CONSTRAINT ck_ed_sent     CHECK ((status = 'SENT') = (sent_at IS NOT NULL)),
  CONSTRAINT ck_ed_attempts CHECK (attempts >= 0)
);

-- Lo que consulta el proceso de envio: "que falta mandar", por
-- antiguedad. Parcial: miles de enviados y un punado de pendientes.
CREATE INDEX ix_ed_pending
  ON email_deliveries (created_at)
  WHERE status = 'PENDING';

-- "Le llego el recibo?"
CREATE INDEX ix_ed_payment
  ON email_deliveries (payment_id)
  WHERE payment_id IS NOT NULL;

-- La bandeja de problemas.
CREATE INDEX ix_ed_failed
  ON email_deliveries (created_at DESC)
  WHERE status = 'FAILED';
