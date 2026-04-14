/* ============================================================
   UNIFIED ENTITY TABLE — All 5 Sources
   ============================================================
   Combines HUBSPOT, DEALROOM, REGISTRY, PITCHBOOK, HARMONIC
   into a single T_ENTITIES table with blocking keys.

   PB and HAR stubs return zero rows until Phase 2 activation.
   ============================================================ */

CREATE OR REPLACE TRANSIENT TABLE DEV_QUEBECTECH.UTIL.T_ENTITIES AS

-- HUBSPOT
SELECT
  'HUBSPOT'                                        AS SRC,
  TO_VARCHAR(HS_COMPANY_ID)                        AS SRC_ID,
  HS_NAME_RAW                                      AS NAME_RAW,
  HS_NAME_NORM                                     AS NAME_NORM,
  COALESCE(HS_DOMAIN_NORM, HS_DOMAIN_FROM_WEBSITE) AS DOMAIN_NORM,
  COALESCE(HS_LINKEDIN_ID_NORM, HS_LINKEDIN_NORM)  AS LINKEDIN_NORM,
  HS_NEQ_NORM                                      AS NEQ_NORM,
  SPLIT_PART(HS_NAME_NORM, ' ', 1)                 AS TOK1,
  LEFT(HS_NAME_NORM, 4)                            AS P4
FROM DEV_QUEBECTECH.UTIL.V_HS_CLEAN
WHERE HS_NAME_NORM IS NOT NULL

UNION ALL

-- DEALROOM
SELECT
  'DEALROOM'                                       AS SRC,
  DRM_ID                                           AS SRC_ID,
  DRM_NAME_RAW                                     AS NAME_RAW,
  DRM_NAME_NORM                                    AS NAME_NORM,
  DRM_DOMAIN_NORM                                  AS DOMAIN_NORM,
  DRM_LINKEDIN_NORM                                AS LINKEDIN_NORM,
  DRM_NEQ_NORM                                     AS NEQ_NORM,
  SPLIT_PART(DRM_NAME_NORM, ' ', 1)                AS TOK1,
  LEFT(DRM_NAME_NORM, 4)                           AS P4
FROM DEV_QUEBECTECH.UTIL.V_DRM_LATEST
WHERE DRM_NAME_NORM IS NOT NULL

UNION ALL

-- REGISTRY
SELECT
  'REGISTRY'                                       AS SRC,
  REG_NEQ_NORM                                     AS SRC_ID,
  REG_NAME_RAW                                     AS NAME_RAW,
  REG_NAME_NORM                                    AS NAME_NORM,
  NULL                                             AS DOMAIN_NORM,
  NULL                                             AS LINKEDIN_NORM,
  REG_NEQ_NORM                                     AS NEQ_NORM,
  SPLIT_PART(REG_NAME_NORM, ' ', 1)                AS TOK1,
  LEFT(REG_NAME_NORM, 4)                           AS P4
FROM (
  WITH n AS (
    SELECT
      NEQ,
      NOM_ASSUJ,
      DAT_INIT_NOM_ASSUJ,
      DAT_FIN_NOM_ASSUJ,
      ROW_NUMBER() OVER (
        PARTITION BY NEQ
        ORDER BY
          IFF(DAT_FIN_NOM_ASSUJ IS NULL, 0, 1),
          DAT_INIT_NOM_ASSUJ DESC
      ) AS RN
    FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS
  )
  SELECT
    DEV_QUEBECTECH.UTIL.NORM_NEQ(NEQ)              AS REG_NEQ_NORM,
    NOM_ASSUJ                                       AS REG_NAME_RAW,
    DEV_QUEBECTECH.UTIL.NORM_NAME(NOM_ASSUJ)        AS REG_NAME_NORM
  FROM n
  WHERE RN = 1
    AND DEV_QUEBECTECH.UTIL.NORM_NEQ(NEQ) IS NOT NULL
) r
WHERE REG_NAME_NORM IS NOT NULL

UNION ALL

-- PITCHBOOK (stub — returns zero rows until Phase 2)
SELECT
  'PITCHBOOK'                                      AS SRC,
  PB_ID                                            AS SRC_ID,
  PB_NAME_RAW                                      AS NAME_RAW,
  PB_NAME_NORM                                     AS NAME_NORM,
  PB_DOMAIN_NORM                                   AS DOMAIN_NORM,
  PB_LINKEDIN_NORM                                 AS LINKEDIN_NORM,
  PB_NEQ_NORM                                      AS NEQ_NORM,
  SPLIT_PART(PB_NAME_NORM, ' ', 1)                 AS TOK1,
  LEFT(PB_NAME_NORM, 4)                            AS P4
FROM DEV_QUEBECTECH.UTIL.V_PB_CLEAN
WHERE PB_NAME_NORM IS NOT NULL

UNION ALL

-- HARMONIC (stub — returns zero rows until Phase 2)
SELECT
  'HARMONIC'                                       AS SRC,
  HAR_ID                                           AS SRC_ID,
  HAR_NAME_RAW                                     AS NAME_RAW,
  HAR_NAME_NORM                                    AS NAME_NORM,
  HAR_DOMAIN_NORM                                  AS DOMAIN_NORM,
  HAR_LINKEDIN_NORM                                AS LINKEDIN_NORM,
  HAR_NEQ_NORM                                     AS NEQ_NORM,
  SPLIT_PART(HAR_NAME_NORM, ' ', 1)                AS TOK1,
  LEFT(HAR_NAME_NORM, 4)                           AS P4
FROM DEV_QUEBECTECH.UTIL.V_HAR_CLEAN
WHERE HAR_NAME_NORM IS NOT NULL
;

ALTER TABLE DEV_QUEBECTECH.UTIL.T_ENTITIES
  CLUSTER BY (SRC, NEQ_NORM, DOMAIN_NORM, LINKEDIN_NORM, P4, TOK1);

/* ----------------------------------------------------------
   Backward-compat alias: keeps push-list SQL (67/68) working
   ---------------------------------------------------------- */
CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.T_ENTITIES_HS_DRM AS
SELECT *
FROM DEV_QUEBECTECH.UTIL.T_ENTITIES
WHERE SRC IN ('HUBSPOT', 'DEALROOM');
