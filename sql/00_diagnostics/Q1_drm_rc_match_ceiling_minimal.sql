/* ============================================================
   Q1 MINIMAL — DR ↔ RC MATCHING CEILING DIAGNOSIS (cheap sections only)
   ============================================================
   Trimmed version of Q1_drm_rc_match_ceiling.sql. Runs only the
   sections that are cheap AND sufficient to decide the REQ-hub
   go/no-go.

   Skipped from the full file:
     - E, F  (50-row eyeball samples — defer)
     - G     (P4 token overlap — run only if B shows RC unmatched
              has names but no other identifiers)
     - H     (city + name cross-join with NAME_SIM UDF — expensive,
              only worth it once we've decided to invest in tier-5)
     - K     (RC-side PITCHBOOK_ACQ_COMPANIES join — defer until
              sector-flag sizing is actually needed)

   Sections included:
     A.  Population sizes & current match rate
     B.  RC Quebec — identifier coverage (total + unmatched)
     C.  DR A+/A/B — identifier coverage (total + unmatched)
     D.  NEQ coverage + RC native-NEQ sanity check
     I.  Tier-4 NAME_SIM score distribution
     J.  Match rate by DR rating × NEQ presence  ← decisive

   Run with Run All in Snowsight. No tables are created or modified
   beyond session-scoped temp tables.

   Inputs: identical to the full Q1 file.

   Author: AI Agent (Quebec Tech Data & Analytics)
   Date:   2026-04-10
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;


/* ------------------------------------------------------------
   Shared temp tables (same as full Q1 file).
   ------------------------------------------------------------ */

CREATE OR REPLACE TEMPORARY TABLE _Q1_DR_STARTUPS AS
SELECT
    drm.DEALROOM_ID,
    drm.NAME                                AS DRM_NAME,
    UTIL.NORM_NAME(drm.NAME)                AS DRM_NAME_NORM,
    LEFT(UTIL.NORM_NAME(drm.NAME), 4)       AS DRM_P4,
    drm.WEBSITE_DOMAIN                      AS DRM_DOMAIN_RAW,
    ent.DOMAIN_NORM                         AS DRM_DOMAIN_NORM,
    ent.LINKEDIN_NORM                       AS DRM_LINKEDIN_NORM,
    drm.HQ_CITY                             AS DRM_CITY,
    LOWER(TRIM(drm.HQ_CITY))                AS DRM_CITY_NORM,
    drm.LAUNCH_YEAR                         AS DRM_LAUNCH_YEAR,
    cls.RATING_LETTER                       AS DRM_RATING,
    ind.TOP_INDUSTRY                        AS DRM_TOP_INDUSTRY,
    bridge.NEQ_FINAL                        AS DRM_NEQ,
    bridge.MATCH_SOURCE                     AS DRM_NEQ_SOURCE,
    IFF(m.RC_ID IS NOT NULL, TRUE, FALSE)   AS IS_MATCHED_TO_RC,
    m.MATCH_TIER                            AS DR_RC_MATCH_TIER,
    m.RC_ID                                 AS RC_COMPANY_ID
FROM DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm
JOIN DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
  ON drm.DEALROOM_ID = cls.DEALROOM_ID
 AND cls.RATING_LETTER IN ('A+', 'A', 'B')
LEFT JOIN DEV_QUEBECTECH.UTIL.T_ENTITIES ent
  ON ent.SRC = 'DEALROOM' AND ent.SRC_ID = drm.DEALROOM_ID::VARCHAR
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_INDUSTRY_SIGNALS_SILVER ind
  ON drm.DEALROOM_ID = ind.DEALROOM_ID
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_REGISTRY_BRIDGE_SILVER bridge
  ON drm.DEALROOM_ID = bridge.DEALROOM_ID
LEFT JOIN DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP m
  ON m.DRM_ID = drm.DEALROOM_ID::VARCHAR
WHERE drm.NAME IS NOT NULL;


CREATE OR REPLACE TEMPORARY TABLE _Q1_RC_QUEBEC AS
SELECT
    COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
             cm.PB_COMPANY_ID::VARCHAR)     AS RC_COMPANY_ID,
    cm.HARMONIC_COMPANY_ID,
    cm.PB_COMPANY_ID,
    cm.RECORD_TYPE,
    COALESCE(cm.H_COMPANY_NAME_NORM,
             cm.PB_COMPANY_NAME_NORM)       AS RC_NAME_NORM,
    COALESCE(cm.H_LEGAL_NAME_NORM,
             cm.PB_LEGAL_NAME_NORM)         AS RC_LEGAL_NAME_NORM,
    LEFT(COALESCE(cm.H_COMPANY_NAME_NORM,
                  cm.PB_COMPANY_NAME_NORM), 4) AS RC_P4,
    COALESCE(NULLIF(TRIM(LOWER(cm.PB_WEBSITE_DOMAIN)), ''),
             NULLIF(TRIM(LOWER(cm.H_WEBSITE_DOMAIN)), '')) AS RC_DOMAIN_NORM,
    COALESCE(NULLIF(TRIM(LOWER(cm.H_LINKEDIN_SLUG)), ''),
             NULLIF(TRIM(LOWER(cm.PB_LINKEDIN_SLUG)), '')) AS RC_LINKEDIN_NORM,
    cm.CRUNCHBASE_SLUG                      AS RC_CRUNCHBASE_SLUG,
    COALESCE(cm.H_CITY, cm.PB_HQ_CITY)      AS RC_CITY,
    LOWER(TRIM(COALESCE(cm.H_CITY, cm.PB_HQ_CITY))) AS RC_CITY_NORM,
    COALESCE(YEAR(cm.H_FOUNDING_DATE),
             cm.PB_YEAR_FOUNDED)            AS RC_FOUNDING_YEAR,
    IFF(m.DRM_ID IS NOT NULL, TRUE, FALSE)  AS IS_MATCHED_TO_DR,
    m.DRM_ID                                AS DEALROOM_ID
FROM DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER cm
LEFT JOIN DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP m
  ON m.RC_ID = COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
                        cm.PB_COMPANY_ID::VARCHAR)
WHERE LOWER(COALESCE(cm.H_STATE, cm.PB_HQ_STATE_PROVINCE, '')) IN
        ('quebec','québec','qc','que')
   OR LOWER(COALESCE(cm.H_COUNTRY, cm.PB_HQ_COUNTRY, '')) IN
        ('quebec','québec');


/* ============================================================
   SECTION A — Population sizes & current match rate
   ============================================================ */

SELECT 'DR A+/A/B startups'   AS POPULATION, COUNT(*) AS N FROM _Q1_DR_STARTUPS
UNION ALL
SELECT 'DR matched to RC',         COUNT(*) FROM _Q1_DR_STARTUPS WHERE IS_MATCHED_TO_RC
UNION ALL
SELECT 'DR unmatched',             COUNT(*) FROM _Q1_DR_STARTUPS WHERE NOT IS_MATCHED_TO_RC
UNION ALL
SELECT 'RC Quebec total',          COUNT(*) FROM _Q1_RC_QUEBEC
UNION ALL
SELECT 'RC matched to DR',         COUNT(*) FROM _Q1_RC_QUEBEC WHERE IS_MATCHED_TO_DR
UNION ALL
SELECT 'RC unmatched',             COUNT(*) FROM _Q1_RC_QUEBEC WHERE NOT IS_MATCHED_TO_DR;


/* ============================================================
   SECTION B — RC Quebec: identifier coverage
   ============================================================ */

SELECT
    COUNT(*)                                                        AS RC_TOTAL,
    COUNT_IF(RC_DOMAIN_NORM IS NOT NULL)                            AS HAS_DOMAIN,
    COUNT_IF(RC_LINKEDIN_NORM IS NOT NULL)                          AS HAS_LINKEDIN,
    COUNT_IF(RC_CRUNCHBASE_SLUG IS NOT NULL)                        AS HAS_CRUNCHBASE,
    COUNT_IF(RC_LEGAL_NAME_NORM IS NOT NULL)                        AS HAS_LEGAL_NAME,
    COUNT_IF(RC_NAME_NORM IS NOT NULL)                              AS HAS_NAME,
    COUNT_IF(RC_CITY_NORM IS NOT NULL)                              AS HAS_CITY,
    COUNT_IF(RC_FOUNDING_YEAR IS NOT NULL)                          AS HAS_FOUNDING_YEAR,
    COUNT_IF(RC_DOMAIN_NORM IS NULL
             AND RC_LINKEDIN_NORM IS NULL
             AND RC_CRUNCHBASE_SLUG IS NULL)                        AS NAME_ONLY,
    COUNT_IF(RC_DOMAIN_NORM IS NULL
             AND RC_LINKEDIN_NORM IS NULL
             AND RC_CRUNCHBASE_SLUG IS NULL
             AND RC_NAME_NORM IS NULL)                              AS NO_IDENTIFIERS
FROM _Q1_RC_QUEBEC;

SELECT
    COUNT(*)                                                        AS RC_UNMATCHED,
    COUNT_IF(RC_DOMAIN_NORM IS NOT NULL)                            AS HAS_DOMAIN,
    COUNT_IF(RC_LINKEDIN_NORM IS NOT NULL)                          AS HAS_LINKEDIN,
    COUNT_IF(RC_CRUNCHBASE_SLUG IS NOT NULL)                        AS HAS_CRUNCHBASE,
    COUNT_IF(RC_LEGAL_NAME_NORM IS NOT NULL)                        AS HAS_LEGAL_NAME,
    COUNT_IF(RC_DOMAIN_NORM IS NULL AND RC_LINKEDIN_NORM IS NULL
             AND RC_CRUNCHBASE_SLUG IS NULL)                        AS NAME_ONLY,
    COUNT_IF(RECORD_TYPE = 'HARMONIC_ONLY')                         AS RT_HARMONIC_ONLY,
    COUNT_IF(RECORD_TYPE = 'PB_ONLY')                               AS RT_PB_ONLY,
    COUNT_IF(RECORD_TYPE = 'BOTH')                                  AS RT_BOTH
FROM _Q1_RC_QUEBEC
WHERE NOT IS_MATCHED_TO_DR;


/* ============================================================
   SECTION C — DR A+/A/B: identifier coverage
   ============================================================ */

SELECT
    COUNT(*)                                                        AS DR_TOTAL,
    COUNT_IF(DRM_DOMAIN_NORM IS NOT NULL)                           AS HAS_DOMAIN,
    COUNT_IF(DRM_LINKEDIN_NORM IS NOT NULL)                         AS HAS_LINKEDIN,
    COUNT_IF(DRM_NEQ IS NOT NULL)                                   AS HAS_NEQ,
    COUNT_IF(DRM_CITY_NORM IS NOT NULL)                             AS HAS_CITY,
    COUNT_IF(DRM_LAUNCH_YEAR IS NOT NULL)                           AS HAS_LAUNCH_YEAR
FROM _Q1_DR_STARTUPS;

SELECT
    DRM_RATING                                                      AS RATING,
    COUNT(*)                                                        AS DR_UNMATCHED,
    COUNT_IF(DRM_DOMAIN_NORM IS NOT NULL)                           AS HAS_DOMAIN,
    COUNT_IF(DRM_LINKEDIN_NORM IS NOT NULL)                         AS HAS_LINKEDIN,
    COUNT_IF(DRM_NEQ IS NOT NULL)                                   AS HAS_NEQ
FROM _Q1_DR_STARTUPS
WHERE NOT IS_MATCHED_TO_RC
GROUP BY DRM_RATING
ORDER BY DRM_RATING;


/* ============================================================
   SECTION D — NEQ coverage + RC native-NEQ sanity check
   ============================================================ */

SELECT
    'DR A+/A/B' AS POP,
    COUNT(*) AS N,
    COUNT_IF(DRM_NEQ IS NOT NULL) AS WITH_NEQ,
    ROUND(COUNT_IF(DRM_NEQ IS NOT NULL) * 100.0 / COUNT(*), 1) AS PCT_NEQ,
    COUNT_IF(DRM_NEQ_SOURCE = 'number') AS NEQ_BY_NUMBER,
    COUNT_IF(DRM_NEQ_SOURCE = 'name')   AS NEQ_BY_NAME
FROM _Q1_DR_STARTUPS;

-- RC native NEQ sanity: expect ~0
SELECT COUNT(*) AS N_RC_WITH_NEQ_LIKE_FIELD
FROM DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER
WHERE REGEXP_LIKE(COALESCE(H_LEGAL_NAME_NORM, ''), '[0-9]{10}')
   OR REGEXP_LIKE(COALESCE(PB_LEGAL_NAME_NORM, ''), '[0-9]{10}');


/* ============================================================
   SECTION I — Tier-4 NAME_SIM score distribution
   ============================================================ */

SELECT
    CASE
        WHEN SCORE >= 0.95 THEN '0.95-1.00 (very strong)'
        WHEN SCORE >= 0.90 THEN '0.90-0.95 (strong)'
        WHEN SCORE >= 0.85 THEN '0.85-0.90 (borderline)'
        ELSE '< 0.85 (rejected)'
    END AS BUCKET,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
WHERE MATCH_TIER = 4
GROUP BY BUCKET
ORDER BY BUCKET DESC;


/* ============================================================
   SECTION J — Match rate by DR rating × NEQ presence  (decisive)
   ============================================================
   Interpretation:
     - HAS_NEQ matches RC at 60%+ AND NO_NEQ matches at <20%
         → REQ-hub is high-leverage, build the bridge.
     - Flat across HAS_NEQ / NO_NEQ
         → RC simply doesn't have these companies; accept the
           ceiling and stop investing in matching.
   ============================================================ */

SELECT
    DRM_RATING,
    IFF(DRM_NEQ IS NOT NULL, 'HAS_NEQ', 'NO_NEQ') AS NEQ_STATUS,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q1_DR_STARTUPS
GROUP BY DRM_RATING, NEQ_STATUS
ORDER BY DRM_RATING, NEQ_STATUS;


/* ============================================================
   END — Q1 MINIMAL
   If results are inconclusive, consult the full Q1 file for
   sections E (DR eyeball), F (RC eyeball), G (P4 overlap),
   H (name+city cross-join — expensive), K (sector counts).
   ============================================================ */
