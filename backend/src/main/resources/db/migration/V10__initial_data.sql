-- =====================================================================
--  V10 - Datos iniciales
--
--  Lo minimo para que el sistema arranque, nada mas:
--    1. El plan de cuentas del contador (INFORME671), con las
--       abreviaturas del sistema actual.
--    2. Las cuentas financieras: donde esta la plata.
--    3. Los medios de pago.
--    4. La fila unica de configuracion del club.
--  Categorias de socio, disciplinas y usuarios NO van aca: los carga el
--  club desde las pantallas.
--
--  Como los id son GENERATED ALWAYS no se pueden escribir a mano, y
--  ademas un alta fallida consume numeros. Por eso nada de este archivo
--  usa un id fijo: todo se busca por number_code o por code.
-- =====================================================================


-- ---------------------------------------------------------------------
--  1. Plan de cuentas
--
--  Se carga en tres pasos:
--    a) una tabla temporal con el plan tal como viene del contador,
--       cada cuenta con el number_code de su padre;
--    b) se copian todas las cuentas a accounts, sin padre;
--    c) se completa parent_id buscando al padre por su number_code.
--  Hace falta el paso c) porque un INSERT no ve las filas que el mismo
--  INSERT esta agregando: el padre todavia "no existe" para su hijo.
--
--  El padre de una cuenta es la misma numeracion con el ultimo tramo
--  distinto de cero puesto en cero:
--    4.3.2.04.003 -> 4.3.2.04.000 -> 4.3.2.00.000 -> 4.3.0.00.000 -> 4.0.0.00.000
--
--  Dos reglas que salen del numero, no se escriben cuenta por cuenta:
--    - is_postable: las que terminan en 000 son titulos y no se puede
--      imputar en ellas. INDUMENTARIA DEPORTIVA (1.1.4.01.000) y PASIVO
--      NO CORRIENTE quedan como titulos sin hijos hasta que el contador
--      les agregue subcuentas.
--    - account_type, por rango: 1 activo, 2 pasivo, 3 patrimonio,
--      4.1 ingresos, 4.2 y 4.3 gastos. 4.0.0.00.000 RESULTADOS queda sin
--      tipo porque agrupa ingresos y gastos. A confirmar con el contador.
--
--  Nombres: los del plan del contador, con los errores de tipeo
--  corregidos (PROESORES, MANTNIMIENTO, CUIERTA, ACTIVIDAES).
--
--  Abreviaturas (code): las del sistema actual. Quedan sin abreviatura
--  las cuentas que no tenian una, y DONACIONES REALIZADAS, porque DYC
--  ya lo usa DONACIONES RECIBIDAS y code es unico.
--  Quedaron afuera cuatro abreviaturas viejas que no tienen cuenta en
--  el plan nuevo: PROBF, MAPCL, CSAP y PACS.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_plan (
  number_code  VARCHAR(20)  PRIMARY KEY,
  parent_code  VARCHAR(20),
  code         VARCHAR(20),
  name         VARCHAR(80)  NOT NULL
) ON COMMIT DROP;

INSERT INTO tmp_plan (number_code, parent_code, code, name) VALUES
  ('1.0.0.00.000', NULL            , NULL      , 'ACTIVO'),
  ('1.1.0.00.000', '1.0.0.00.000'  , NULL      ,   'ACTIVO CORRIENTE'),
  ('1.1.1.00.000', '1.1.0.00.000'  , NULL      ,     'CAJA Y BANCOS'),
  ('1.1.1.01.000', '1.1.1.00.000'  , NULL      ,       'CAJA'),
  ('1.1.1.01.001', '1.1.1.01.000'  , NULL      ,         'RECAUDACIONES A DEPOSITAR'),
  ('1.1.1.01.002', '1.1.1.01.000'  , NULL      ,         'CAJA CHICA'),
  ('1.1.1.01.003', '1.1.1.01.000'  , NULL      ,         'CAJA MONEDA EXTRANJERA'),
  ('1.1.1.01.004', '1.1.1.01.000'  , NULL      ,         'CHEQUES EN CARTERA'),
  ('1.1.1.02.000', '1.1.1.00.000'  , NULL      ,       'BANCOS'),
  ('1.1.1.02.001', '1.1.1.02.000'  , NULL      ,         'BANCO PROVINCIA CTA CTE'),
  ('1.1.1.02.002', '1.1.1.02.000'  , NULL      ,         'BANCO SANTANDER'),
  ('1.1.1.02.003', '1.1.1.02.000'  , NULL      ,         'MERCADO PAGO'),
  ('1.1.1.02.004', '1.1.1.02.000'  , NULL      ,         'BANCO PROVINCIA - CTA CTE TIENDA'),
  ('1.1.2.00.000', '1.1.0.00.000'  , NULL      ,     'INVERSIONES TEMPORARIAS'),
  ('1.1.2.01.000', '1.1.2.00.000'  , NULL      ,       'DEPOSITOS A PLAZO FIJO'),
  ('1.1.2.01.001', '1.1.2.01.000'  , NULL      ,         'PLAZO FIJO BPBA EN $'),
  ('1.1.3.00.000', '1.1.0.00.000'  , NULL      ,     'CREDITOS'),
  ('1.1.3.01.000', '1.1.3.00.000'  , NULL      ,       'CREDITOS SOCIOS'),
  ('1.1.3.01.001', '1.1.3.01.000'  , NULL      ,         'CUOTAS SOCIOS A COBRAR'),
  ('1.1.3.02.000', '1.1.3.00.000'  , NULL      ,       'CREDITOS VARIOS'),
  ('1.1.3.02.001', '1.1.3.02.000'  , 'TAC'     ,         'TARJETAS A COBRAR'),
  ('1.1.3.02.002', '1.1.3.02.000'  , NULL      ,         'ANTICIPO A PROVEEDORES'),
  ('1.1.3.03.000', '1.1.3.00.000'  , NULL      ,       'CREDITOS IMPOSITIVOS'),
  ('1.1.3.03.001', '1.1.3.03.000'  , NULL      ,         'GANANCIAS RETENCIONES Y PERCEP.'),
  ('1.1.3.03.002', '1.1.3.03.000'  , NULL      ,         'IVA RETENCIONES Y PERCEPCIONES'),
  ('1.1.3.03.003', '1.1.3.03.000'  , NULL      ,         'IIBB RETENCIONES Y PERCEPCIONES'),
  ('1.1.3.03.004', '1.1.3.03.000'  , NULL      ,         'IVA CREDITO FISCAL'),
  ('1.1.3.03.005', '1.1.3.03.000'  , NULL      ,         'IVA SALDO DE DDJJ'),
  ('1.1.3.03.006', '1.1.3.03.000'  , NULL      ,         'IIBB SALDO DE DDJJ'),
  ('1.1.3.03.007', '1.1.3.03.000'  , NULL      ,         'GANANCIAS SALDO DE DDJJ'),
  ('1.1.3.03.008', '1.1.3.03.000'  , NULL      ,         'SUSS RETENCIONES'),
  ('1.1.4.00.000', '1.1.0.00.000'  , NULL      ,     'BIENES DE CAMBIO'),
  ('1.1.4.01.000', '1.1.4.00.000'  , NULL      ,       'INDUMENTARIA DEPORTIVA'),
  ('1.2.0.00.000', '1.0.0.00.000'  , NULL      ,   'ACTIVO NO CORRIENTE'),
  ('1.2.1.00.000', '1.2.0.00.000'  , NULL      ,     'BIENES DE USO'),
  ('1.2.1.01.000', '1.2.1.00.000'  , NULL      ,       'INMUEBLES'),
  ('1.2.1.01.001', '1.2.1.01.000'  , NULL      ,         'INMUEBLE SEDE SOCIAL'),
  ('1.2.1.01.002', '1.2.1.01.000'  , NULL      ,         'PILETA CUBIERTA'),
  ('1.2.1.01.003', '1.2.1.01.000'  , NULL      ,         'INMUEBLE PARQUE'),
  ('1.2.1.01.004', '1.2.1.01.000'  , NULL      ,         'EDIFICIOS Y MEJORAS'),
  ('1.2.1.01.005', '1.2.1.01.000'  , NULL      ,         'MEJORAS PARQUE'),
  ('1.2.1.01.006', '1.2.1.01.000'  , NULL      ,         'MEJORAS GIMNASIO'),
  ('1.2.1.01.007', '1.2.1.01.000'  , NULL      ,         'MEJORAS ANEXO'),
  ('1.2.1.01.008', '1.2.1.01.000'  , NULL      ,         'OBRAS ESQ. MITRE Y GARIBALDI'),
  ('1.2.1.02.000', '1.2.1.00.000'  , NULL      ,       'INSTALACIONES'),
  ('1.2.1.02.001', '1.2.1.02.000'  , NULL      ,         'INSTALACIONES SEDE'),
  ('1.2.1.02.002', '1.2.1.02.000'  , NULL      ,         'INSTALACIONES PARQUE'),
  ('1.2.1.02.003', '1.2.1.02.000'  , NULL      ,         'INSTALACIONES PILETA'),
  ('1.2.1.02.004', '1.2.1.02.000'  , NULL      ,         'INSTALACIONES TENIS'),
  ('1.2.1.02.005', '1.2.1.02.000'  , NULL      ,         'INSTALACIONES HOCKEY'),
  ('1.2.1.02.006', '1.2.1.02.000'  , NULL      ,         'INSTALACIONES GIMNASIO'),
  ('1.2.1.02.007', '1.2.1.02.000'  , NULL      ,         'INSTALACIONES PREDIO'),
  ('1.2.1.02.008', '1.2.1.02.000'  , NULL      ,         'INSTALACIONES ANEXO'),
  ('1.2.1.03.000', '1.2.1.00.000'  , NULL      ,       'MUEBLES Y UTILES'),
  ('1.2.1.03.001', '1.2.1.03.000'  , NULL      ,         'MUEBLES Y UTILES ACTIVIDADES DEPORT'),
  ('1.2.1.04.000', '1.2.1.00.000'  , NULL      ,       'SOFTWARE'),
  ('1.2.1.04.001', '1.2.1.04.000'  , NULL      ,         'SOFTWARE DE GESTION'),
  ('2.0.0.00.000', NULL            , NULL      , 'PASIVO'),
  ('2.1.0.00.000', '2.0.0.00.000'  , NULL      ,   'PASIVO CORRIENTE'),
  ('2.1.1.00.000', '2.1.0.00.000'  , NULL      ,     'DEUDAS COMERCIALES'),
  ('2.1.1.01.000', '2.1.1.00.000'  , NULL      ,       'PROVEEDORES'),
  ('2.1.1.01.001', '2.1.1.01.000'  , NULL      ,         'PROVEEDORES VARIOS'),
  ('2.1.1.02.000', '2.1.1.00.000'  , NULL      ,       'HONORARIOS A PAGAR'),
  ('2.1.1.02.001', '2.1.1.02.000'  , 'HPAP'    ,         'HONORARIOS PROFESIONALES A PAGAR'),
  ('2.1.1.03.000', '2.1.1.00.000'  , NULL      ,       'CHEQUES DIFERIDOS'),
  ('2.1.1.03.001', '2.1.1.03.000'  , NULL      ,         'CHEQUES DIFERIDOS A PAGAR'),
  ('2.1.2.00.000', '2.1.0.00.000'  , NULL      ,     'DEUDAS PREVISIONALES'),
  ('2.1.2.01.000', '2.1.2.00.000'  , NULL      ,       'SUELDOS'),
  ('2.1.2.01.001', '2.1.2.01.000'  , 'SAP'     ,         'SUELDOS A PAGAR'),
  ('2.1.2.02.000', '2.1.2.00.000'  , NULL      ,       'CARGAS SOCIALES'),
  ('2.1.2.02.001', '2.1.2.02.000'  , NULL      ,         'SEGURIDAD SOCIAL A PAGAR'),
  ('2.1.2.02.002', '2.1.2.02.000'  , NULL      ,         'OBRA SOCIAL A PAGAR'),
  ('2.1.2.02.003', '2.1.2.02.000'  , NULL      ,         'ART A PAGAR'),
  ('2.1.2.02.004', '2.1.2.02.000'  , NULL      ,         'UTEDYC A PAGAR'),
  ('2.1.2.02.005', '2.1.2.02.000'  , NULL      ,         'ARCA - SUSS PLAN DE PAGOS'),
  ('2.2.0.00.000', '2.0.0.00.000'  , NULL      ,   'PASIVO NO CORRIENTE'),
  ('3.0.0.00.000', NULL            , NULL      , 'PATRIMONIO NETO'),
  ('3.1.0.00.000', '3.0.0.00.000'  , NULL      ,   'APORTES DE LOS ASOCIADOS'),
  ('3.1.1.00.000', '3.1.0.00.000'  , NULL      ,     'CAPITAL'),
  ('3.1.1.01.000', '3.1.1.00.000'  , NULL      ,       'CAPITAL SOCIAL'),
  ('3.1.1.01.001', '3.1.1.01.000'  , NULL      ,         'CAPITAL SOCIAL'),
  ('3.1.1.01.002', '3.1.1.01.000'  , NULL      ,         'AJUSTE DE CAPITAL'),
  ('3.2.0.00.000', '3.0.0.00.000'  , NULL      ,   'GANANCIAS RESERVADAS'),
  ('3.2.1.00.000', '3.2.0.00.000'  , NULL      ,     'RESERVAS'),
  ('3.2.1.01.000', '3.2.1.00.000'  , NULL      ,       'RESERVAS'),
  ('3.2.1.01.001', '3.2.1.01.000'  , NULL      ,         'RESERVA LEGAL'),
  ('3.2.1.01.002', '3.2.1.01.000'  , NULL      ,         'RESERVA ESTATUTARIA'),
  ('3.2.1.01.003', '3.2.1.01.000'  , NULL      ,         'RESERVA FACULTATIVA'),
  ('3.3.0.00.000', '3.0.0.00.000'  , NULL      ,   'RESULTADOS ACUMULADOS'),
  ('3.3.1.00.000', '3.3.0.00.000'  , NULL      ,     'RESULTADOS'),
  ('3.3.1.01.000', '3.3.1.00.000'  , NULL      ,       'RESULTADOS'),
  ('3.3.1.01.001', '3.3.1.01.000'  , NULL      ,         'RESULTADO DEL EJERCICIO'),
  ('3.3.1.01.002', '3.3.1.01.000'  , NULL      ,         'RESULTADOS NO ASIGNADOS'),
  ('3.3.1.01.003', '3.3.1.01.000'  , NULL      ,         'A.R.E.A.'),
  ('4.0.0.00.000', NULL            , NULL      , 'RESULTADOS'),
  ('4.1.0.00.000', '4.0.0.00.000'  , NULL      ,   'RECURSOS'),
  ('4.1.1.00.000', '4.1.0.00.000'  , NULL      ,     'ACTIVIDAD SOCIAL'),
  ('4.1.1.01.000', '4.1.1.00.000'  , NULL      ,       'CUOTA SOCIAL'),
  ('4.1.1.01.001', '4.1.1.01.000'  , 'CS'      ,         'CUOTAS SOCIALES'),
  ('4.1.1.01.002', '4.1.1.01.000'  , 'CEA'     ,         'CAMPAÑA EXT ASOC. (DECANOS)'),
  ('4.1.1.01.003', '4.1.1.01.000'  , 'CSA'     ,         'CONTRIB. EXT. CAMPAÑA SOCIO ADHE.'),
  ('4.1.2.00.000', '4.1.0.00.000'  , NULL      ,     'ACTIVIDADES DEPORTIVAS Y CULTURALES'),
  ('4.1.2.01.000', '4.1.2.00.000'  , NULL      ,       'FUTBOL'),
  ('4.1.2.01.001', '4.1.2.01.000'  , 'FMA'     ,         'FUTBOL MAYOR'),
  ('4.1.2.01.002', '4.1.2.01.000'  , 'FME'     ,         'FUTBOL MENOR'),
  ('4.1.2.01.003', '4.1.2.01.000'  , 'FR'      ,         'FUTBOL RECREATIVO'),
  ('4.1.2.01.004', '4.1.2.01.000'  , 'FF'      ,         'FUTBOL FEMENINO'),
  ('4.1.2.02.000', '4.1.2.00.000'  , NULL      ,       'BASQUET'),
  ('4.1.2.02.001', '4.1.2.02.000'  , NULL      ,         'BASQUET MAYOR'),
  ('4.1.2.02.002', '4.1.2.02.000'  , 'BME'     ,         'BASQUET MENOR'),
  ('4.1.2.02.003', '4.1.2.02.000'  , 'BR'      ,         'BASQUET RECREATIVO'),
  ('4.1.2.02.004', '4.1.2.02.000'  , 'BF'      ,         'BASQUET FEMENINO'),
  ('4.1.2.02.005', '4.1.2.02.000'  , 'BS'      ,         'BASQUET SENIOR'),
  ('4.1.2.03.000', '4.1.2.00.000'  , NULL      ,       'TENIS'),
  ('4.1.2.03.001', '4.1.2.03.000'  , 'TL'      ,         'TENIS LIBRE'),
  ('4.1.2.03.002', '4.1.2.03.000'  , 'TE'      ,         'TENIS ESCUELA'),
  ('4.1.2.04.000', '4.1.2.00.000'  , NULL      ,       'HOCKEY'),
  ('4.1.2.04.001', '4.1.2.04.000'  , 'HEF'     ,         'HOCKEY ESCUELA FEMENINO'),
  ('4.1.2.04.002', '4.1.2.04.000'  , 'HEM'     ,         'HOCKEY ESCUELA MASCULINO'),
  ('4.1.2.04.003', '4.1.2.04.000'  , 'HCF'     ,         'HOCKEY COMPETITIVO'),
  ('4.1.2.05.000', '4.1.2.00.000'  , NULL      ,       'PILETA ABIERTA'),
  ('4.1.2.05.001', '4.1.2.05.000'  , 'NPA'     ,         'NATACION PILETA ABIERTA LIBRE'),
  ('4.1.2.05.002', '4.1.2.05.000'  , 'CV'      ,         'COLONIA DE VACACIONES VERANO'),
  ('4.1.2.06.000', '4.1.2.00.000'  , NULL      ,       'PILETA CUBIERTA'),
  ('4.1.2.06.001', '4.1.2.06.000'  , 'NE'      ,         'NATACION PILETA CUBIERTA ESCUELA'),
  ('4.1.2.06.002', '4.1.2.06.000'  , 'CI'      ,         'COLONIA DE VACACIONES INVIERNO'),
  ('4.1.2.07.000', '4.1.2.00.000'  , NULL      ,       'OTRAS ACTIVIDADES DEPORTIVAS Y CULT'),
  ('4.1.2.07.001', '4.1.2.07.000'  , 'VF'      ,         'VOLEY FEMENINO'),
  ('4.1.2.07.002', '4.1.2.07.000'  , 'VM'      ,         'VOLEY MASCULINO'),
  ('4.1.2.07.003', '4.1.2.07.000'  , 'BC'      ,         'BOCHAS COMPETITIVO'),
  ('4.1.2.07.004', '4.1.2.07.000'  , 'BOR'     ,         'BOCHAS RECREATIVO'),
  ('4.1.2.07.005', '4.1.2.07.000'  , 'PR'      ,         'PALETA RECREATIVA'),
  ('4.1.2.07.006', '4.1.2.07.000'  , NULL      ,         'PALETA COMPETITIVA'),
  ('4.1.2.07.007', '4.1.2.07.000'  , 'ID'      ,         'INICIACION DEPORTIVA'),
  ('4.1.2.07.008', '4.1.2.07.000'  , 'YO'      ,         'YOGA'),
  ('4.1.2.07.009', '4.1.2.07.000'  , 'KA'      ,         'KARATE-DO'),
  ('4.1.2.07.010', '4.1.2.07.000'  , 'STRE'    ,         'STRETCHING'),
  ('4.1.2.07.011', '4.1.2.07.000'  , 'AI'      ,         'ACADEMIA DE INGLES'),
  ('4.1.2.07.012', '4.1.2.07.000'  , 'PE'      ,         'PERCUSION'),
  ('4.1.2.07.013', '4.1.2.07.000'  , 'AVI'     ,         'ARTES VISUALES'),
  ('4.1.2.07.014', '4.1.2.07.000'  , 'TEA'     ,         'TALLER DE TEATRO'),
  ('4.1.2.07.015', '4.1.2.07.000'  , 'FO'      ,         'FOLKLORE'),
  ('4.1.2.07.016', '4.1.2.07.000'  , 'DA'      ,         'DANZAS'),
  ('4.1.3.00.000', '4.1.0.00.000'  , NULL      ,     'OTRAS ACTIVIDADES GENERALES'),
  ('4.1.3.01.000', '4.1.3.00.000'  , NULL      ,       'ALQUILERES'),
  ('4.1.3.01.001', '4.1.3.01.000'  , 'ASB'     ,         'ALQUILER SALON JJ BONIFACIO'),
  ('4.1.3.01.002', '4.1.3.01.000'  , 'AV'      ,         'ALQUILERES VARIOS'),
  ('4.1.3.02.000', '4.1.3.00.000'  , NULL      ,       'VENTAS'),
  ('4.1.3.02.001', '4.1.3.02.000'  , 'MERCH'   ,         'VENTA DE MERCHANDISING'),
  ('4.1.3.03.000', '4.1.3.00.000'  , NULL      ,       'PUBLICIDAD'),
  ('4.1.3.03.001', '4.1.3.03.000'  , 'PUGIM'   ,         'PUBLICIDAD GIMNASIO'),
  ('4.1.3.03.002', '4.1.3.03.000'  , 'PUHO'    ,         'PUBLICIDAD HOCKEY'),
  ('4.1.3.03.003', '4.1.3.03.000'  , 'PUPAL'   ,         'PUBLICIDAD PALETA'),
  ('4.1.3.03.004', '4.1.3.03.000'  , 'PF'      ,         'PUBLICIDAD PARQUE'),
  ('4.1.3.03.005', '4.1.3.03.000'  , 'PUSE'    ,         'PUBLICIDAD SEDE'),
  ('4.1.3.03.006', '4.1.3.03.000'  , 'PUTE'    ,         'PUBLICIDAD TENIS'),
  ('4.1.3.04.000', '4.1.3.00.000'  , NULL      ,       'VARIOS'),
  ('4.1.3.04.001', '4.1.3.04.000'  , 'AGA'     ,         'AGASAJOS'),
  ('4.1.3.05.000', '4.1.3.00.000'  , NULL      ,       'SUBSIDIOS Y DONACIONES'),
  ('4.1.3.05.001', '4.1.3.05.000'  , 'DYC'     ,         'DONACIONES RECIBIDAS'),
  ('4.1.3.05.002', '4.1.3.05.000'  , NULL      ,         'SUBSIDIOS RECIBIDOS'),
  ('4.1.3.05.003', '4.1.3.05.000'  , 'PODE'    ,         'POTENCIAR DEPORTE'),
  ('4.1.3.06.000', '4.1.3.00.000'  , NULL      ,       'REINTEGROS'),
  ('4.1.3.06.001', '4.1.3.06.000'  , 'RESEFMA' ,         'REINTEGRO SEGUROS FUTBOL MAYOR'),
  ('4.2.0.00.000', '4.0.0.00.000'  , NULL      ,   'GASTOS'),
  ('4.2.1.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS ACTIVIDAD SOCIAL'),
  ('4.2.1.01.000', '4.2.1.00.000'  , NULL      ,       'GASTOS COBRANZA CUOTA SOCIAL'),
  ('4.2.1.01.001', '4.2.1.01.000'  , 'CC'      ,         'COMISION COBRANZA CUOTA SOCIAL'),
  ('4.2.1.01.002', '4.2.1.01.000'  , 'CCSA'    ,         'COMISION CAMPAÑA SOCIO ADHERENTE'),
  ('4.2.1.02.000', '4.2.1.00.000'  , NULL      ,       'GASTOS VARIOS'),
  ('4.2.1.02.001', '4.2.1.02.000'  , 'ICEA'    ,         'IMPRENTA CAMPAÑA EXTRAORD (DECANOS)'),
  ('4.2.1.03.000', '4.2.1.00.000'  , NULL      ,       'PREMIOS'),
  ('4.2.1.03.001', '4.2.1.03.000'  , 'PCEA'    ,         'PREMIOS CAMPAÑA EXT.ASOC. (DECANOS)'),
  ('4.2.1.03.002', '4.2.1.03.000'  , 'PRCSA'   ,         'PREMIOS CAMPAÑA SOCIO ADHERENTE'),
  ('4.2.2.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS FUTBOL'),
  ('4.2.2.01.000', '4.2.2.00.000'  , NULL      ,       'GASTOS FUTBOL MAYOR'),
  ('4.2.2.01.001', '4.2.2.01.000'  , 'AFILFMA' ,         'AFILIACIONES FUTBOL MAYOR'),
  ('4.2.2.01.002', '4.2.2.01.000'  , 'ARBFMA'  ,         'ARBITROS FUTBOL MAYOR'),
  ('4.2.2.01.003', '4.2.2.01.000'  , 'DMFMA'   ,         'DEP. MEDICO FUTBOL MAYOR'),
  ('4.2.2.01.004', '4.2.2.01.000'  , 'GGFMA'   ,         'GASTOS GENERALES FUTBOL MAYOR'),
  ('4.2.2.01.005', '4.2.2.01.000'  , 'EFMA'    ,         'EDES MED. 741638 FUTBOL MAYOR'),
  ('4.2.2.01.006', '4.2.2.01.000'  , 'INDFMA'  ,         'INDUMENTARIA FUTBOL MAYOR'),
  ('4.2.2.01.007', '4.2.2.01.000'  , 'MAFMA'   ,         'MANTENIMIENTO FUTBOL MAYOR'),
  ('4.2.2.01.008', '4.2.2.01.000'  , 'SEGFMA'  ,         'SEGURO FUTBOL MAYOR'),
  ('4.2.2.01.009', '4.2.2.01.000'  , 'UTFMA'   ,         'UTILERIA FUTBOL MAYOR'),
  ('4.2.2.01.010', '4.2.2.01.000'  , 'VYMFMA'  ,         'VIATICOS Y MOVILIDAD FUTBOL MAYOR'),
  ('4.2.2.01.011', '4.2.2.01.000'  , 'PROFMA'  ,         'PROFESORES FUTBOL MAYOR'),
  ('4.2.2.02.000', '4.2.2.00.000'  , NULL      ,       'GASTOS FUTBOL MENOR'),
  ('4.2.2.02.001', '4.2.2.02.000'  , 'AFILFME' ,         'AFILIACIONES FUTBOL MENOR'),
  ('4.2.2.02.002', '4.2.2.02.000'  , 'ARBFME'  ,         'ARBITROS FUTBOL MENOR'),
  ('4.2.2.02.003', '4.2.2.02.000'  , 'DMFME'   ,         'DEP. MEDICO FUTBOL MENOR'),
  ('4.2.2.02.004', '4.2.2.02.000'  , 'MAFME'   ,         'MANTENIMIENTO FUTBOL MENOR'),
  ('4.2.2.02.005', '4.2.2.02.000'  , 'UTFME'   ,         'UTILERIA FUTBOL MENOR'),
  ('4.2.2.02.006', '4.2.2.02.000'  , 'PROFME'  ,         'PROFESORES FUTBOL MENOR'),
  ('4.2.2.03.000', '4.2.2.00.000'  , NULL      ,       'GASTOS FUTBOL FEMENINO'),
  ('4.2.2.03.001', '4.2.2.03.000'  , 'ARBFF'   ,         'ARBITROS FUTBOL FEMENINO'),
  ('4.2.2.03.002', '4.2.2.03.000'  , 'DMFF'    ,         'DEP. MEDICO FUTBOL FEMENINO'),
  ('4.2.2.03.003', '4.2.2.03.000'  , 'GGFF'    ,         'GASTOS GENERALES FUTBOL FEMENINO'),
  ('4.2.2.03.004', '4.2.2.03.000'  , 'UTFF'    ,         'UTILERIA FUTBOL FEMENINO'),
  ('4.2.2.03.005', '4.2.2.03.000'  , 'PROFF'   ,         'PROFESORES FUTBOL FEMENINO'),
  ('4.2.2.04.000', '4.2.2.00.000'  , NULL      ,       'GASTOS FUTBOL RECREATIVO'),
  ('4.2.2.04.001', '4.2.2.04.000'  , 'GGFR'    ,         'GASTOS GENERALES FUTBOL RECREATIVO'),
  ('4.2.2.04.002', '4.2.2.04.000'  , 'UTFR'    ,         'UTILERIA FUTBOL RECREATIVO'),
  ('4.2.2.04.003', '4.2.2.04.000'  , 'PROFR'   ,         'PROFESORES FUTBOL RECREATIVO'),
  ('4.2.3.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS BASQUET'),
  ('4.2.3.01.000', '4.2.3.00.000'  , NULL      ,       'GASTOS BASQUET MAYOR'),
  ('4.2.3.01.001', '4.2.3.01.000'  , 'AFBMA'   ,         'AFILIACIONES BASQUET MAYOR'),
  ('4.2.3.01.002', '4.2.3.01.000'  , 'DMBMA'   ,         'DEP. MEDICO BASQUET MAYOR'),
  ('4.2.3.01.003', '4.2.3.01.000'  , 'UTBMA'   ,         'UTILERIA BASQUET MAYORES'),
  ('4.2.3.01.004', '4.2.3.01.000'  , 'VYMBMA'  ,         'VIATICOS Y MOVILIDAD BASQUET MAYOR'),
  ('4.2.3.01.005', '4.2.3.01.000'  , 'PROBMA'  ,         'PROFESORES BASQUET MAYORES'),
  ('4.2.3.02.000', '4.2.3.00.000'  , NULL      ,       'GASTOS BASQUET MENOR'),
  ('4.2.3.02.001', '4.2.3.02.000'  , 'AFBME'   ,         'AFILIACIONES BASQUET MENOR'),
  ('4.2.3.02.002', '4.2.3.02.000'  , 'DMBME'   ,         'DEP. MEDICO BASQUET MENOR'),
  ('4.2.3.02.003', '4.2.3.02.000'  , 'MBME'    ,         'MANTENIMIENTO BASQUET MENOR'),
  ('4.2.3.02.004', '4.2.3.02.000'  , 'UTBME'   ,         'UTILERIA BASQUET MENORES'),
  ('4.2.3.02.005', '4.2.3.02.000'  , 'PROBME'  ,         'PROFESORES BASQUET MENORES'),
  ('4.2.3.03.000', '4.2.3.00.000'  , NULL      ,       'GASTOS BASQUET RECREATIVO'),
  ('4.2.3.03.001', '4.2.3.03.000'  , 'PROBR'   ,         'PROFESORES BASQUET RECREATIVO'),
  ('4.2.3.04.000', '4.2.3.00.000'  , NULL      ,       'GASTOS BASQUET SENIOR'),
  ('4.2.3.04.001', '4.2.3.04.000'  , 'UTBS'    ,         'UTILERIA BASQUET SENIOR'),
  ('4.2.3.04.002', '4.2.3.04.000'  , 'PROBS'   ,         'PROFESORES BASQUET SENIOR'),
  ('4.2.4.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS TENIS'),
  ('4.2.4.01.000', '4.2.4.00.000'  , NULL      ,       'GASTOS TENIS LIBRE'),
  ('4.2.4.01.001', '4.2.4.01.000'  , 'EDESTL'  ,         'EDES TENIS LIBRE'),
  ('4.2.4.01.002', '4.2.4.01.000'  , 'MTL'     ,         'MANTENIMIENTO TENIS LIBRE'),
  ('4.2.4.02.000', '4.2.4.00.000'  , NULL      ,       'GASTOS TENIS ESCUELA'),
  ('4.2.4.02.001', '4.2.4.02.000'  , 'ETE'     ,         'EDES TENIS ESCUELA'),
  ('4.2.4.02.002', '4.2.4.02.000'  , 'MATE'    ,         'MANTENIMIENTO TENIS ESCUELA'),
  ('4.2.4.02.003', '4.2.4.02.000'  , 'PROTE'   ,         'PROFESOR TENIS ESCUELA'),
  ('4.2.5.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS HOCKEY'),
  ('4.2.5.01.000', '4.2.5.00.000'  , NULL      ,       'GASTOS HOCKEY ESCUELA FEMENINO'),
  ('4.2.5.01.001', '4.2.5.01.000'  , 'PROHEF'  ,         'PROFESORES HOCKEY ESCUELA FEMENINO'),
  ('4.2.5.02.000', '4.2.5.00.000'  , NULL      ,       'GASTOS HOCKEY ESCUELA MASCULINO'),
  ('4.2.5.02.001', '4.2.5.02.000'  , 'PROHEM'  ,         'PROFESORES HOCKEY ESCUELA MASCULINO'),
  ('4.2.5.03.000', '4.2.5.00.000'  , NULL      ,       'HOCKEY COMPETITIVO'),
  ('4.2.5.03.001', '4.2.5.03.000'  , 'AHCF'    ,         'AFILIACIONES HOCKEY COMPETITIVO'),
  ('4.2.5.03.002', '4.2.5.03.000'  , 'DMHCF'   ,         'DEP. MEDICO HOCKEY COMPETITIVO'),
  ('4.2.5.03.003', '4.2.5.03.000'  , 'MHCF'    ,         'MANTENIMIENTO HOCKEY COMPETITIVO'),
  ('4.2.5.03.004', '4.2.5.03.000'  , 'GGHCF'   ,         'GASTOS GENERALES HOCKEY COMPETITIVO'),
  ('4.2.5.03.005', '4.2.5.03.000'  , 'PROHCF'  ,         'PROFESORES HOCKEY COMPETITIVO'),
  ('4.2.6.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS PILETA ABIERTA'),
  ('4.2.6.01.000', '4.2.6.00.000'  , NULL      ,       'NATACION PILETA ABIERTA LIBRE'),
  ('4.2.6.01.001', '4.2.6.01.000'  , 'MNPA'    ,         'MANTENIM. NATACION PILETA ABIERTA'),
  ('4.2.6.02.000', '4.2.6.00.000'  , NULL      ,       'COLONIA DE VACACIONES VERANO'),
  ('4.2.6.02.001', '4.2.6.02.000'  , 'PROCV'   ,         'PROF. COLONIA DE VACACIONES VERANO'),
  ('4.2.7.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS PILETA CUBIERTA'),
  ('4.2.7.01.000', '4.2.7.00.000'  , NULL      ,       'NATACION PILETA CUBIERTA ESCUELA'),
  ('4.2.7.01.001', '4.2.7.01.000'  , 'AFILNC'  ,         'AFILIACIONES NATACION COMPETITIVO'),
  ('4.2.7.01.002', '4.2.7.01.000'  , 'ENE'     ,         'EDES MED 354003 PILETA CUBIERTA'),
  ('4.2.7.01.003', '4.2.7.01.000'  , 'GNE'     ,         'GAS PILETA CUBIERTA'),
  ('4.2.7.01.004', '4.2.7.01.000'  , 'MNE'     ,         'MANTENIMIENTO PILETA CUBIERTA'),
  ('4.2.7.01.005', '4.2.7.01.000'  , 'PRONE'   ,         'PROFESOR NATACION PILETA CUBIERTA'),
  ('4.2.7.02.000', '4.2.7.00.000'  , NULL      ,       'COLONIA DE VACACIONES INVIERNO'),
  ('4.2.7.02.001', '4.2.7.02.000'  , 'PROCI'   ,         'PROF.COLONIA DE VACACIONES INVIERNO'),
  ('4.2.8.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS OTRAS ACTIVIDADES DEP-CULT'),
  ('4.2.8.01.000', '4.2.8.00.000'  , NULL      ,       'GASTOS VOLEY'),
  ('4.2.8.01.001', '4.2.8.01.000'  , 'AFILVD'  ,         'AFILIACIONES VOLEY DAMAS'),
  ('4.2.8.01.002', '4.2.8.01.000'  , 'DMVD'    ,         'DEP. MEDICOS VOLEY DAMAS'),
  ('4.2.8.01.003', '4.2.8.01.000'  , 'PROVD'   ,         'PROFESORES VOLEY DAMAS'),
  ('4.2.8.01.004', '4.2.8.01.000'  , 'AFILVC'  ,         'AFILIACIONES VOLEY CABALLEROS'),
  ('4.2.8.01.005', '4.2.8.01.000'  , 'PROVC'   ,         'PROFESORES VOLEY CABALLEROS'),
  ('4.2.8.02.000', '4.2.8.00.000'  , NULL      ,       'GASTOS BOCHAS'),
  ('4.2.8.02.001', '4.2.8.02.000'  , 'PROBOR'  ,         'PROFESOR BOCHAS RECREATIVO'),
  ('4.2.8.02.002', '4.2.8.02.000'  , 'AFILBC'  ,         'AFILIACIONES BOCHAS COMPETITIVO'),
  ('4.2.8.02.003', '4.2.8.02.000'  , 'MBC'     ,         'MANTENIMIENTO BOCHAS COMPETITIVO'),
  ('4.2.8.02.004', '4.2.8.02.000'  , 'VYMBC'   ,         'GASTOS Y MOVILIDAD BOCHAS'),
  ('4.2.8.03.000', '4.2.8.00.000'  , NULL      ,       'OTRAS ACTIVIDADES DEPORTIVAS'),
  ('4.2.8.03.001', '4.2.8.03.000'  , 'MPR'     ,         'MANTENIMIENTO PALETA'),
  ('4.2.8.03.002', '4.2.8.03.000'  , NULL      ,         'PROFESOR PALETA'),
  ('4.2.8.03.003', '4.2.8.03.000'  , 'PROGIM'  ,         'PROFESOR GIMNASIO'),
  ('4.2.8.03.004', '4.2.8.03.000'  , NULL      ,         'MANTENIMIENTO GIMNASIO'),
  ('4.2.8.03.005', '4.2.8.03.000'  , 'PROID'   ,         'PROFESOR INICIACION DEPORTIVA'),
  ('4.2.8.03.006', '4.2.8.03.000'  , 'AFIKA'   ,         'AFILIACIONES KARATE'),
  ('4.2.8.03.007', '4.2.8.03.000'  , 'PROKA'   ,         'PROFESOR KARATE'),
  ('4.2.8.03.008', '4.2.8.03.000'  , 'GGYO'    ,         'GASTOS GENERALES YOGA'),
  ('4.2.8.03.009', '4.2.8.03.000'  , 'PROSTRE' ,         'PROFESOR STRETCHING'),
  ('4.2.8.04.000', '4.2.8.00.000'  , NULL      ,       'ACADEMIA DE INGLES'),
  ('4.2.8.04.001', '4.2.8.04.000'  , 'PROAI'   ,         'PROFESOR ACADEMIA DE INGLES'),
  ('4.2.8.05.000', '4.2.8.00.000'  , NULL      ,       'TALLERES'),
  ('4.2.8.05.001', '4.2.8.05.000'  , 'PROTEA'  ,         'PROFESOR TEATRO'),
  ('4.2.8.05.002', '4.2.8.05.000'  , 'PROAVI'  ,         'PROFESOR ARTES VISUALES'),
  ('4.2.8.05.003', '4.2.8.05.000'  , 'PROPE'   ,         'PROFESOR PERCUSION'),
  ('4.2.8.06.000', '4.2.8.00.000'  , NULL      ,       'DANZAS'),
  ('4.2.8.06.001', '4.2.8.06.000'  , 'PROFO'   ,         'PROFESOR FOLKLORE'),
  ('4.2.9.00.000', '4.2.0.00.000'  , NULL      ,     'GASTOS OTRAS ACTIVIDADES GENERALES'),
  ('4.2.9.01.000', '4.2.9.00.000'  , NULL      ,       'ALQUILERES'),
  ('4.2.9.01.001', '4.2.9.01.000'  , NULL      ,         'GASTOS ALQUILERES FIJOS'),
  ('4.2.9.01.002', '4.2.9.01.000'  , NULL      ,         'GASTOS ALQUILERES VARIOS'),
  ('4.2.9.01.003', '4.2.9.01.000'  , NULL      ,         'GASTOS ALQUILER SALON JJ BONIFACIO'),
  ('4.2.9.02.000', '4.2.9.00.000'  , NULL      ,       'VENTAS'),
  ('4.2.9.02.001', '4.2.9.02.000'  , 'GMERCH'  ,         'GASTOS MERCHANDISING'),
  ('4.2.9.03.000', '4.2.9.00.000'  , NULL      ,       'PUBLICIDAD'),
  ('4.2.9.03.001', '4.2.9.03.000'  , 'COPUHO'  ,         'COMISION PUBLICIDAD HOCKEY'),
  ('4.2.9.03.002', '4.2.9.03.000'  , 'MAPUHO'  ,         'MANTENIMIENTO PUBLICIDAD HOCKEY'),
  ('4.2.9.03.003', '4.2.9.03.000'  , 'COPUPAL' ,         'COMISION PUBLICIDAD PALETA'),
  ('4.2.9.03.004', '4.2.9.03.000'  , 'MPUPAL'  ,         'MANTENIMIENTO PUBLICIDAD PALETA'),
  ('4.2.9.03.005', '4.2.9.03.000'  , 'COPUPA'  ,         'COMISION PUBLICIDAD PARQUE'),
  ('4.2.9.03.006', '4.2.9.03.000'  , 'MAPUPA'  ,         'MANTENIMIENTO PUBLICIDAD PARQUE'),
  ('4.2.9.03.007', '4.2.9.03.000'  , 'COPUSE'  ,         'COMISION PUBLICIDAD SEDE'),
  ('4.2.9.03.008', '4.2.9.03.000'  , 'MAPUSE'  ,         'MANTENIMIENTO PUBLICIDAD SEDE'),
  ('4.2.9.03.009', '4.2.9.03.000'  , NULL      ,         'COMISION PUBLICIDAD TENIS'),
  ('4.2.9.03.010', '4.2.9.03.000'  , 'MAPUTE'  ,         'MANTENIMIENTO PUBLICIDAD TENIS'),
  ('4.2.9.04.000', '4.2.9.00.000'  , NULL      ,       'VARIOS'),
  ('4.2.9.04.001', '4.2.9.04.000'  , 'GAG'     ,         'GASTOS AGASAJOS'),
  ('4.2.9.04.002', '4.2.9.04.000'  , NULL      ,         'DONACIONES REALIZADAS'),
  ('4.3.0.00.000', '4.0.0.00.000'  , NULL      ,   'GASTOS GENERALES'),
  ('4.3.1.00.000', '4.3.0.00.000'  , NULL      ,     'INTENDENCIA'),
  ('4.3.1.01.000', '4.3.1.00.000'  , NULL      ,       'INTENDENCIA PALACIO'),
  ('4.3.1.01.001', '4.3.1.01.000'  , 'SYJIPAL' ,         'SUELDOS INTENDENCIA PALACIO'),
  ('4.3.1.01.002', '4.3.1.01.000'  , 'CSIPAL'  ,         'CARGAS SOCIALES INTENDENCIA PALACIO'),
  ('4.3.1.01.003', '4.3.1.01.000'  , 'MPAL'    ,         'MANTENIMIENTO INTENDENCIA PALACIO'),
  ('4.3.1.01.004', '4.3.1.01.000'  , 'EIPAL'   ,         'EDES 741732-173809 PALACIO'),
  ('4.3.1.01.005', '4.3.1.01.000'  , 'TEPAL'   ,         'TELEFONO INTENDENCIA PALACIO'),
  ('4.3.1.01.006', '4.3.1.01.000'  , 'GPAL'    ,         'GAS INTENDENCIA PALACIO'),
  ('4.3.1.02.000', '4.3.1.00.000'  , NULL      ,       'INTENDENCIA PARQUE'),
  ('4.3.1.02.001', '4.3.1.02.000'  , 'SYJIPAR' ,         'SUELDOS INTENDENCIA PARQUE'),
  ('4.3.1.02.002', '4.3.1.02.000'  , 'CSIPAR'  ,         'CARGAS SOCIALES INTENDENCIA PARQUE'),
  ('4.3.1.02.003', '4.3.1.02.000'  , 'MPAR'    ,         'MANTENIMIENTO INTENDENCIA PARQUE'),
  ('4.3.1.02.004', '4.3.1.02.000'  , 'EIPAR'   ,         'EDES INTENDENCIA PARQUE'),
  ('4.3.1.02.005', '4.3.1.02.000'  , 'GPAR'    ,         'GAS INTENDENCIA PARQUE'),
  ('4.3.1.03.000', '4.3.1.00.000'  , NULL      ,       'INTENDENCIA PREDIO'),
  ('4.3.1.03.001', '4.3.1.03.000'  , 'MPRE'    ,         'MANTENIMIENTO PREDIO ALQUILADO'),
  ('4.3.1.03.002', '4.3.1.03.000'  , 'EPRE'    ,         'EDES PREDIO'),
  ('4.3.1.03.003', '4.3.1.03.000'  , 'ALPRE'   ,         'ALQUILER PREDIO'),
  ('4.3.2.00.000', '4.3.0.00.000'  , NULL      ,     'ADMINISTRACION GENERAL'),
  ('4.3.2.01.000', '4.3.2.00.000'  , NULL      ,       'SUELDOS'),
  ('4.3.2.01.001', '4.3.2.01.000'  , 'SYJAG'   ,         'SUELDOS ADMINISTRACION GENERAL'),
  ('4.3.2.01.002', '4.3.2.01.000'  , 'CSAG'    ,         'CARGAS SOCIALES ADMINISTRACION GRAL'),
  ('4.3.2.02.000', '4.3.2.00.000'  , NULL      ,       'VARIOS'),
  ('4.3.2.02.001', '4.3.2.02.000'  , 'GGAG'    ,         'GASTOS GENERALES ADMINISTRACION'),
  ('4.3.2.02.002', '4.3.2.02.000'  , 'UOAG'    ,         'UTILES OFICINA ADMINISTRACION'),
  ('4.3.2.02.003', '4.3.2.02.000'  , 'FAG'     ,         'FRANQUEOS ADMINISTRACION'),
  ('4.3.2.02.004', '4.3.2.02.000'  , 'IAG'     ,         'IMPRENTA ADMINISTRACION GENERAL'),
  ('4.3.2.02.005', '4.3.2.02.000'  , 'HAAG'    ,         'HONORARIOS ADMINISTRACION GENERAL'),
  ('4.3.2.02.006', '4.3.2.02.000'  , 'HCAG'    ,         'HONORARIOS COMPUTACION ADM GRAL'),
  ('4.3.2.03.000', '4.3.2.00.000'  , NULL      ,       'SEGUROS'),
  ('4.3.2.03.001', '4.3.2.03.000'  , 'ESS'     ,         'SEGURO SOCIOS'),
  ('4.3.2.04.000', '4.3.2.00.000'  , NULL      ,       'GASTOS BANCARIOS Y FINANCIEROS'),
  ('4.3.2.04.001', '4.3.2.04.000'  , 'GAUTOM'  ,         'GASTOS DEBITO AUTOMATICO'),
  ('4.3.2.04.002', '4.3.2.04.000'  , 'GTAR'    ,         'GASTOS TARJETAS'),
  ('4.3.2.04.003', '4.3.2.04.000'  , 'GYDB'    ,         'GASTOS BANCARIOS'),
  ('4.3.2.04.004', '4.3.2.04.000'  , NULL      ,         'LEY 25413 - IDYC'),
  ('4.3.2.05.000', '4.3.2.00.000'  , NULL      ,       'IMPOSITIVOS'),
  ('4.3.2.05.001', '4.3.2.05.000'  , NULL      ,         'GASTOS IMPOSITIVOS')
;

-- b) Todas las cuentas, en el orden del plan.
INSERT INTO accounts (code, number_code, name, account_type, is_postable)
SELECT
  t.code,
  t.number_code,
  t.name,
  CASE
    WHEN t.number_code LIKE '1.%'   THEN 'ASSET'
    WHEN t.number_code LIKE '2.%'   THEN 'LIABILITY'
    WHEN t.number_code LIKE '3.%'   THEN 'EQUITY'
    WHEN t.number_code LIKE '4.1.%' THEN 'INCOME'
    WHEN t.number_code LIKE '4.2.%'
      OR t.number_code LIKE '4.3.%' THEN 'EXPENSE'
  END::account_type,
  t.number_code NOT LIKE '%.000'
FROM tmp_plan t
ORDER BY t.number_code;

-- c) El padre de cada una.
UPDATE accounts a
SET    parent_id = p.id
FROM   tmp_plan t
JOIN   accounts p ON p.number_code = t.parent_code
WHERE  a.number_code = t.number_code;


-- ---------------------------------------------------------------------
--  2. Cuentas financieras
--  Cada una apunta a su cuenta del plan. Las cajas de los cobradores
--  no van aca: se crean al dar de alta a cada cobrador.
--  Caja moneda extranjera queda afuera: el sistema trabaja en pesos.
-- ---------------------------------------------------------------------
INSERT INTO financial_accounts (name, account_type, account_id)
SELECT v.name, v.account_type::financial_account_type, a.id
FROM (VALUES
  ('Recaudaciones a depositar',      'CASH',      '1.1.1.01.001'),  -- la caja de secretaria
  ('Caja chica',                     'CASH',      '1.1.1.01.002'),
  ('Cheques en cartera',             'CHECKS',    '1.1.1.01.004'),
  ('Banco Provincia cta cte',        'BANK',      '1.1.1.02.001'),
  ('Banco Santander',                'BANK',      '1.1.1.02.002'),
  ('Mercado Pago',                   'WALLET',    '1.1.1.02.003'),
  ('Banco Provincia cta cte tienda', 'BANK',      '1.1.1.02.004'),
  ('Tarjetas a cobrar',              'TO_SETTLE', '1.1.3.02.001')   -- lo que la tarjeta todavia no acredito
) AS v (name, account_type, number_code)
JOIN accounts a ON a.number_code = v.number_code;


-- ---------------------------------------------------------------------
--  3. Medios de pago
--  financial_account_type limita a que tipo de cuenta puede ir cada
--  medio: un pago en efectivo solo puede entrar a una caja.
--  Todos arrancan SIN comision: los checks exigen un porcentaje cuando
--  has_fee es true, y ese porcentaje lo define el club. Las cuentas de
--  gasto ya existen (GASTOS TARJETAS, GASTOS DEBITO AUTOMATICO).
-- ---------------------------------------------------------------------
INSERT INTO payment_methods (code, name, financial_account_type) VALUES
  ('CASH',     'Efectivo',          'CASH'),
  ('TRANSFER', 'Transferencia',     'BANK'),
  ('CHECK',    'Cheque',            'CHECKS'),
  ('DEBIT',    'Débito automático', 'BANK'),
  ('CARD',     'Tarjeta',           'TO_SETTLE'),
  ('MP',       'Mercado Pago',      'WALLET');


-- ---------------------------------------------------------------------
--  4. Configuracion del club
--  La unica fila. Todo lo demas con sus valores por defecto: 10 dias de
--  gracia, vencimiento el 10, 60 dias para morosidad prolongada y los
--  tres talonarios en 0 (el primer recibo de cada serie sera el 1).
--  Si el club ya viene numerando, se actualizan los talonarios al
--  ultimo numero emitido antes de empezar a cobrar.
-- ---------------------------------------------------------------------
INSERT INTO club_settings (id, club_name) VALUES (1, 'Centro Blanco y Negro');
