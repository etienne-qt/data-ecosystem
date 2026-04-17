/* ============================================================
   PIPELINE ROW COUNTS — waypoints for docs/pipeline_overview.md
   ============================================================
   One cheap COUNT(*) per stage, grouped by source/kind where
   informative. Run All in Snowsight; drop the result CSVs back
   to refresh the waypoint table in the pipeline doc.

   All reads are COUNT-only. No tables created or modified.

   Author: AI Agent (Quebec Tech Data & Analytics)
   Date:   2026-04-13
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;


/* ------------------------------------------------------------
   STAGE 1 — BRONZE / RAW counts
   ------------------------------------------------------------ */
SELECT '1_bronze_drm' AS STAGE, COUNT(*) AS N
FROM DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER;   -- no separate bronze count; silver ≈ bronze row count

SELECT '1_bronze_req_canonical' AS STAGE, COUNT(*) AS N
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS;


/* ------------------------------------------------------------
   STAGE 2a — SILVER (Dealroom lane)
   ------------------------------------------------------------ */
SELECT
    '2a_drm_classification' AS STAGE,
    cls.RATING_LETTER,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
GROUP BY cls.RATING_LETTER
ORDER BY cls.RATING_LETTER;

SELECT '2a_drm_industry_signals' AS STAGE, COUNT(*) AS N
FROM DEV_QUEBECTECH.SILVER.DRM_INDUSTRY_SIGNALS_SILVER;

SELECT '2a_drm_geo_enrichment' AS STAGE, COUNT(*) AS N
FROM DEV_QUEBECTECH.SILVER.DRM_GEO_ENRICHMENT_SILVER;

SELECT '2a_drm_registry_bridge' AS STAGE,
    COUNT(*)                                         AS N_ROWS,
    COUNT_IF(NEQ_FINAL IS NOT NULL)                  AS WITH_NEQ
FROM DEV_QUEBECTECH.SILVER.DRM_REGISTRY_BRIDGE_SILVER;


/* ------------------------------------------------------------
   STAGE 2b — SILVER (Réseau Capital lane)
   ------------------------------------------------------------ */
SELECT
    '2b_company_master' AS STAGE,
    cm.RECORD_TYPE,
    COUNT(*) AS N
FROM DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER cm
WHERE LOWER(COALESCE(cm.H_STATE, cm.PB_HQ_STATE_PROVINCE, '')) IN
      ('quebec','québec','qc','que')
   OR LOWER(COALESCE(cm.H_COUNTRY, cm.PB_HQ_COUNTRY, '')) IN
      ('quebec','québec')
GROUP BY cm.RECORD_TYPE
ORDER BY cm.RECORD_TYPE;

SELECT '2b_pitchbook_acq' AS STAGE, COUNT(*) AS N
FROM DEV_RESEAUCAPITAL.SILVER.PITCHBOOK_ACQ_COMPANIES;


/* ------------------------------------------------------------
   STAGE 3 — CROSS-SOURCE STAGING
   ------------------------------------------------------------ */
SELECT
    '3_t_entities' AS STAGE,
    SRC,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_ENTITIES
GROUP BY SRC
ORDER BY SRC;


/* ------------------------------------------------------------
   STAGE 4 — MATCHING
   ------------------------------------------------------------ */
SELECT
    '4_drm_rc_match_edges' AS STAGE,
    MATCH_TIER,
    MATCH_FIELD,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
GROUP BY MATCH_TIER, MATCH_FIELD
ORDER BY MATCH_TIER, MATCH_FIELD;

SELECT
    '4_clusters_hs_drm' AS STAGE,
    SRC,
    COUNT(DISTINCT SRC_ID) AS N_ROWS,
    COUNT(DISTINCT CLUSTER_ID) AS N_CLUSTERS
FROM DEV_QUEBECTECH.UTIL.T_CLUSTERS_HS_DRM
GROUP BY SRC
ORDER BY SRC;


/* ------------------------------------------------------------
   STAGE 5 — MANUAL REVIEW
   ------------------------------------------------------------ */
SELECT
    '5_manual_review' AS STAGE,
    DECISION_TYPE,
    DECISION_VALUE,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT
GROUP BY DECISION_TYPE, DECISION_VALUE
ORDER BY DECISION_TYPE, DECISION_VALUE;


/* ------------------------------------------------------------
   STAGE 6 — GOLD (registry totals + cuts)
   ------------------------------------------------------------ */

-- Totals by entity type
SELECT
    '6_gold_entity_type' AS STAGE,
    ENTITY_TYPE,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
GROUP BY ENTITY_TYPE
ORDER BY ENTITY_TYPE;

-- Inclusion reason (why a row is in the registry)
SELECT
    '6_gold_inclusion_reason' AS STAGE,
    QT_INCLUSION_REASON,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
GROUP BY QT_INCLUSION_REASON
ORDER BY N DESC;

-- Source coverage matrix
SELECT
    '6_gold_source_coverage' AS STAGE,
    N_SOURCES,
    SUM(IFF(HAS_DEALROOM, 1, 0)) AS HAS_DR,
    SUM(IFF(HAS_HUBSPOT, 1, 0))  AS HAS_HS,
    SUM(IFF(HAS_RC, 1, 0))       AS HAS_RC,
    SUM(IFF(HAS_REQ, 1, 0))      AS HAS_REQ,
    COUNT(*)                     AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
GROUP BY N_SOURCES
ORDER BY N_SOURCES DESC;

-- Review queue depth (how many rows will go to triage on next build)
SELECT
    '6_gold_review_queue' AS STAGE,
    SUM(IFF(FLAG_NEEDS_REVIEW, 1, 0)) AS NEEDS_REVIEW,
    SUM(IFF(FLAG_SECTOR_ANY, 1, 0))   AS SECTOR_FLAGGED,
    SUM(IFF(FLAG_NON_TECH_NAME_HIT, 1, 0)) AS NON_TECH_NAME_HIT,
    COUNT(*)                          AS TOTAL
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY;


/* ============================================================
   END — pipeline_row_counts.sql
   ============================================================ */
