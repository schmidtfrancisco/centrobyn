-- =====================================================================
--  V1 - Tipos enumerados
--
--  Todos los enums del modelo, juntos y antes que cualquier tabla.
--  Valores en MAYUSCULAS para que coincidan con las constantes de Java
--  (Hibernate mapea el enum nativo por el nombre exacto).
--
--  Agregar un valor despues: ALTER TYPE ... ADD VALUE en una migracion
--  nueva. Sacar o reordenar un valor exige recrear el tipo: evitarlo.
-- =====================================================================


-- ---- Personas y socios ----------------------------------------------

-- Fijado por el Estado, no por el club: por eso enum y no tabla.
CREATE TYPE document_type AS ENUM (
  'DNI',
  'LC',
  'LE',
  'CI',
  'PASSPORT'
);

-- Sin SUSPENDED: el club no suspende socios.
CREATE TYPE member_status AS ENUM (
  'ACTIVE',
  'INACTIVE'
);


-- ---- Actividades ----------------------------------------------------

CREATE TYPE group_gender AS ENUM (
  'FEMALE',
  'MALE',
  'MIXED'
);

CREATE TYPE teacher_role AS ENUM (
  'HEAD',
  'ASSISTANT'
);


-- ---- Facturacion ----------------------------------------------------

CREATE TYPE billing_period_status AS ENUM (
  'OPEN',
  'GENERATED'
);

-- OTHER: cargos esporadicos, siempre desde un concepto del catalogo.
CREATE TYPE charge_type AS ENUM (
  'MEMBERSHIP',
  'ACTIVITY',
  'OTHER'
);

-- Sin PARTIAL: no se aceptan pagos parciales.
CREATE TYPE charge_status AS ENUM (
  'PENDING',
  'PAID',
  'CANCELLED'
);


-- ---- Estado de registros de dinero ----------------------------------

-- Compartido por payments, cash_transactions y account_transfers.
-- Un solo tipo para las tres tablas: no pueden desfasarse.
CREATE TYPE record_status AS ENUM (
  'ACTIVE',
  'CANCELLED'
);


-- ---- Cobranza a domicilio -------------------------------------------

CREATE TYPE visit_result AS ENUM (
  'COLLECTED',
  'NOT_HOME',
  'WILL_PAY_LATER',
  'ALREADY_PAID',
  'REFUSED',
  'MOVED',
  'PENDING'
);


-- ---- Debito automatico ----------------------------------------------

CREATE TYPE debit_mandate_status AS ENUM (
  'ACTIVE',
  'SUSPENDED',
  'CANCELLED'
);

CREATE TYPE debit_batch_status AS ENUM (
  'DRAFT',      -- armandose
  'PRESENTED',  -- enviado al banco: sus cargos quedan bloqueados
  'PROCESSED',  -- respuesta del banco importada
  'CANCELLED'
);

CREATE TYPE debit_item_result AS ENUM (
  'PENDING',
  'ACCEPTED',
  'REJECTED'
);


-- ---- Contabilidad y tesoreria ---------------------------------------

CREATE TYPE account_type AS ENUM (
  'ASSET',
  'LIABILITY',
  'EQUITY',
  'INCOME',
  'EXPENSE'
);

-- CHECKS    = "Cheques en cartera"
-- TO_SETTLE = "Cobranza a rendir", una cuenta por cobrador
CREATE TYPE financial_account_type AS ENUM (
  'CASH',
  'BANK',
  'WALLET',
  'CHECKS',
  'TO_SETTLE'
);

CREATE TYPE transaction_direction AS ENUM (
  'INCOME',
  'EXPENSE'
);

CREATE TYPE fiscal_document_type AS ENUM (
  'FACTURA_A',
  'FACTURA_B',
  'FACTURA_C',
  'RECIBO',
  'TICKET'
);


-- ---- Cheques --------------------------------------------------------

CREATE TYPE check_direction AS ENUM (
  'RECEIVED',
  'ISSUED'
);

CREATE TYPE check_status AS ENUM (
  'IN_PORTFOLIO',
  'DEPOSITED',
  'CLEARED',
  'REJECTED',
  'ENDORSED',
  'DELIVERED',
  'CANCELLED'
);


-- ---- Usuarios -------------------------------------------------------

-- Enum y no tabla: un rol nuevo sin el codigo que lo respete no sirve.
CREATE TYPE user_role AS ENUM (
  'ADMIN',
  'STAFF',
  'GATEKEEPER',
  'TEACHER',
  'MEMBER',
  'ACCOUNTANT',
  'COLLECTOR'
);


-- ---- Correo ---------------------------------------------------------

CREATE TYPE email_status AS ENUM (
  'PENDING',
  'SENT',
  'FAILED'
);
