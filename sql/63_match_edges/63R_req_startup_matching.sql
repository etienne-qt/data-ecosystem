/* ============================================================
   63R — REQ STARTUP MATCHING AGAINST ALL SOURCES
   ============================================================
   Matches REQ startup candidates against 3 data sources:

     1. Dealroom — via DRM_REGISTRY_BRIDGE_SILVER (NEQ already
        matched) + DRM_COMPANY_SILVER name fallback
     2. HubSpot  — via V_HS_CLEAN (NEQ exact → name fuzzy)
     3. RC (Réseau Capital) — via DEV_RESEAUCAPITAL.SILVER
        .COMPANY_MASTER (name matching only, no NEQ in RC)

   Uses GOLD.REQ_STARTUP_UNIVERSE (relaxed view) as the source
   to maximize coverage across all known startups.

   Blocking strategy for name matching:
     UTIL.NAME_KEY() generates a phonetic/token key to narrow
     the candidate space before computing NAME_SIM. This avoids
     a full cross-join on large tables.

   Input:
     - DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE (from step 51)
     - DEV_QUEBECTECH.SILVER.DRM_REGISTRY_BRIDGE_SILVER
     - DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER
     - DEV_QUEBECTECH.UTIL.V_HS_CLEAN
     - DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER

   Output:
     - DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_EDGES
     - DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_EDGES_DEDUP
     - DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY

   Changes from original (2026-04-01):
     Rewritten 2026-04-07 to use verified Snowflake tables.
     Dealroom matching uses existing DRM_REGISTRY_BRIDGE_SILVER
     (NEQ_FINAL) instead of re-matching from scratch.
     HubSpot matching uses V_HS_CLEAN (HS_NEQ_NORM, HS_NAME_NORM).
     RC matching uses DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER
     (Harmonic + PitchBook names, LinkedIn slugs).
     PitchBook and Harmonic are accessed through the RC
     COMPANY_MASTER Silver table (not as separate sources).
     Successor chain removed — ENTREPRISES_EN_FONCTION is
     active companies only.

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-07
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;


/* ============================================================
   STEP 1: BUILD MATCH EDGES
   One row per (REQ company, matched source, match method).
   All branches UNION ALL into a single transient table.
   ============================================================ */

CREATE OR REPLACE TRANSIENT TABLE DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_EDGES AS

/* -----------------------------------------------------------
   1A. Dealroom — NEQ via DRM_REGISTRY_BRIDGE_SILVER
   The bridge table already matches DEALROOM_ID ↔ NEQ_FINAL.
   This is the strongest signal — pre-computed NEQ resolution.
   ----------------------------------------------------------- */
SELECT
    req.NEQ_NORM                                             AS REQ_NEQ_NORM,
    'DEALROOM'                                               AS MATCHED_SRC,
    bridge.DEALROOM_ID::VARCHAR                              AS MATCHED_SRC_ID,
    'DIRECT_NEQ'                                             AS MATCH_TYPE,
    1.0::FLOAT                                               AS SCORE
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE req
JOIN DEV_QUEBECTECH.SILVER.DRM_REGISTRY_BRIDGE_SILVER bridge
  ON UTIL.NORM_NEQ(bridge.NEQ_FINAL::VARCHAR) = req.NEQ_NORM
WHERE bridge.NEQ_FINAL IS NOT NULL

UNION ALL

/* -----------------------------------------------------------
   1B. Dealroom — name match fallback (blocked by NAME_KEY)
   For REQ companies not matched by NEQ, try normalized name.
   Uses DRM_COMPANY_SILVER.NAME for company names.
   ----------------------------------------------------------- */
SELECT
    req.NEQ_NORM                                             AS REQ_NEQ_NORM,
    'DEALROOM'                                               AS MATCHED_SRC,
    drm.DEALROOM_ID::VARCHAR                                 AS MATCHED_SRC_ID,
    'NAME_SIM'                                               AS MATCH_TYPE,
    UTIL.NAME_SIM(req.COMPANY_NAME_NORM,
                  UTIL.NORM_NAME(drm.NAME))::FLOAT           AS SCORE
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE req
JOIN DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm
  ON UTIL.NAME_KEY(drm.NAME) = req.NAME_KEY
WHERE req.COMPANY_NAME_NORM IS NOT NULL
  AND drm.NAME IS NOT NULL
  AND UTIL.NAME_SIM(req.COMPANY_NAME_NORM,
                    UTIL.NORM_NAME(drm.NAME)) >= 0.85

UNION ALL

/* -----------------------------------------------------------
   1C. HubSpot — NEQ exact match via V_HS_CLEAN
   V_HS_CLEAN already has HS_NEQ_NORM pre-computed.
   ----------------------------------------------------------- */
SELECT
    req.NEQ_NORM                                             AS REQ_NEQ_NORM,
    'HUBSPOT'                                                AS MATCHED_SRC,
    hs.HS_COMPANY_ID::VARCHAR                                AS MATCHED_SRC_ID,
    'DIRECT_NEQ'                                             AS MATCH_TYPE,
    1.0::FLOAT                                               AS SCORE
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE req
JOIN DEV_QUEBECTECH.UTIL.V_HS_CLEAN hs
  ON hs.HS_NEQ_NORM IS NOT NULL
 AND hs.HS_NEQ_NORM = req.NEQ_NORM

UNION ALL

/* -----------------------------------------------------------
   1D. HubSpot — name fuzzy match (blocked by NAME_KEY)
   Compares req.COMPANY_NAME_NORM vs hs.HS_NAME_NORM.
   NAME_SIM threshold: 0.85.
   ----------------------------------------------------------- */
SELECT
    req.NEQ_NORM                                             AS REQ_NEQ_NORM,
    'HUBSPOT'                                                AS MATCHED_SRC,
    hs.HS_COMPANY_ID::VARCHAR                                AS MATCHED_SRC_ID,
    'NAME_SIM'                                               AS MATCH_TYPE,
    UTIL.NAME_SIM(req.COMPANY_NAME_NORM,
                  hs.HS_NAME_NORM)::FLOAT                    AS SCORE
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE req
JOIN DEV_QUEBECTECH.UTIL.V_HS_CLEAN hs
  ON UTIL.NAME_KEY(hs.HS_NAME_RAW) = req.NAME_KEY
WHERE req.COMPANY_NAME_NORM IS NOT NULL
  AND hs.HS_NAME_NORM IS NOT NULL
  AND UTIL.NAME_SIM(req.COMPANY_NAME_NORM,
                    hs.HS_NAME_NORM) >= 0.85

UNION ALL

/* -----------------------------------------------------------
   1E. Réseau Capital — name match via COMPANY_MASTER
   RC has no NEQ, so name is the only path. The COMPANY_MASTER
   Silver table merges Harmonic + PitchBook names.
   We try both H_COMPANY_NAME_NORM and PB_COMPANY_NAME_NORM.
   Blocked by first 4 chars of normalized name for performance.
   ----------------------------------------------------------- */
SELECT
    req.NEQ_NORM                                             AS REQ_NEQ_NORM,
    'RC'                                                     AS MATCHED_SRC,
    COALESCE(rc.HARMONIC_COMPANY_ID::VARCHAR,
             rc.PB_COMPANY_ID::VARCHAR)                      AS MATCHED_SRC_ID,
    'NAME_SIM'                                               AS MATCH_TYPE,
    GREATEST(
        COALESCE(UTIL.NAME_SIM(req.COMPANY_NAME_NORM,
                               rc.H_COMPANY_NAME_NORM), 0),
        COALESCE(UTIL.NAME_SIM(req.COMPANY_NAME_NORM,
                               rc.PB_COMPANY_NAME_NORM), 0)
    )::FLOAT                                                 AS SCORE
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE req
JOIN DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER rc
  ON (LEFT(rc.H_COMPANY_NAME_NORM, 4) = req.P4
      OR LEFT(rc.PB_COMPANY_NAME_NORM, 4) = req.P4)
WHERE req.COMPANY_NAME_NORM IS NOT NULL
  AND (rc.H_COMPANY_NAME_NORM IS NOT NULL
       OR rc.PB_COMPANY_NAME_NORM IS NOT NULL)
  AND GREATEST(
        COALESCE(UTIL.NAME_SIM(req.COMPANY_NAME_NORM,
                               rc.H_COMPANY_NAME_NORM), 0),
        COALESCE(UTIL.NAME_SIM(req.COMPANY_NAME_NORM,
                               rc.PB_COMPANY_NAME_NORM), 0)
      ) >= 0.85
;


/* ============================================================
   STEP 2: DEDUPLICATE — best match per (REQ company, source)
   Waterfall priority: DIRECT_NEQ > NAME_NORM > NAME_SIM
   Within same type, higher score wins.
   ============================================================ */

CREATE OR REPLACE TRANSIENT TABLE DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_EDGES_DEDUP AS
SELECT *
FROM DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_EDGES
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY REQ_NEQ_NORM, MATCHED_SRC
    ORDER BY
        CASE MATCH_TYPE
            WHEN 'DIRECT_NEQ' THEN 0
            WHEN 'NAME_NORM'  THEN 1
            WHEN 'NAME_SIM'   THEN 2
            ELSE 3
        END,
        SCORE DESC
) = 1;


/* ============================================================
   STEP 3: SUMMARY — one row per REQ candidate
   Pivots the deduped edges into per-source columns.
   Output aligned with step 70 discovery queue expectations.
   ============================================================ */

CREATE OR REPLACE TABLE DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY AS
SELECT
    req.NEQ_NORM,
    req.NEQ,
    req.COMPANY_NAME_RAW,
    req.COMPANY_NAME_NORM,
    req.HQ_CITY,
    req.INCORPORATION_YEAR,
    req.N_EMPLOYES,
    req.EMP_MIN,
    req.FORME_JURIDIQUE,
    req.PRODUCT_TIER,
    req.PRODUCT_SCORE,
    req.IS_TECH_SECTOR,
    req.MATCHED_SIGNALS,

    -- Relaxation flags
    req.FLAG_NON_SA,
    req.FLAG_PRE_2010,
    req.FLAG_NO_EMPLOYEES,

    -- Match booleans
    MAX(IFF(e.MATCHED_SRC = 'HUBSPOT',  TRUE, FALSE))       AS IS_IN_HS,
    MAX(IFF(e.MATCHED_SRC = 'DEALROOM', TRUE, FALSE))       AS IS_IN_DRM,
    MAX(IFF(e.MATCHED_SRC = 'RC',       TRUE, FALSE))       AS IS_IN_RC,

    -- Match methods (best per source, after dedup)
    MAX(IFF(e.MATCHED_SRC = 'HUBSPOT',  e.MATCH_TYPE, NULL)) AS MATCH_METHOD_HS,
    MAX(IFF(e.MATCHED_SRC = 'DEALROOM', e.MATCH_TYPE, NULL)) AS MATCH_METHOD_DRM,
    MAX(IFF(e.MATCHED_SRC = 'RC',       e.MATCH_TYPE, NULL)) AS MATCH_METHOD_RC,

    -- Source IDs
    MAX(IFF(e.MATCHED_SRC = 'HUBSPOT',  e.MATCHED_SRC_ID, NULL)) AS HS_COMPANY_ID,
    MAX(IFF(e.MATCHED_SRC = 'DEALROOM', e.MATCHED_SRC_ID, NULL)) AS DRM_COMPANY_ID,
    MAX(IFF(e.MATCHED_SRC = 'RC',       e.MATCHED_SRC_ID, NULL)) AS RC_COMPANY_ID,

    -- Match scores
    MAX(IFF(e.MATCHED_SRC = 'HUBSPOT',  e.SCORE, NULL))     AS MATCH_SCORE_HS,
    MAX(IFF(e.MATCHED_SRC = 'DEALROOM', e.SCORE, NULL))     AS MATCH_SCORE_DRM,
    MAX(IFF(e.MATCHED_SRC = 'RC',       e.SCORE, NULL))     AS MATCH_SCORE_RC,

    -- Aggregate
    COUNT(DISTINCT e.MATCHED_SRC)                            AS N_SOURCES_MATCHED,

    -- Priority score for queue ordering
    -- Higher employee count → higher priority; recent incorporation → small boost
    req.PRODUCT_SCORE
    + CASE
        WHEN req.EMP_MIN >= 500  THEN 10
        WHEN req.EMP_MIN >= 250  THEN 8
        WHEN req.EMP_MIN >= 100  THEN 6
        WHEN req.EMP_MIN >= 50   THEN 4
        WHEN req.EMP_MIN >= 26   THEN 3
        WHEN req.EMP_MIN >= 11   THEN 2
        WHEN req.EMP_MIN >= 6    THEN 1
        ELSE 0
      END
    + IFF(req.INCORPORATION_YEAR >= 2020, 1, 0)              AS PRIORITY_SCORE,

    CURRENT_TIMESTAMP()                                      AS MATCHED_AT

FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE req
LEFT JOIN DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_EDGES_DEDUP e
  ON req.NEQ_NORM = e.REQ_NEQ_NORM
GROUP BY
    req.NEQ_NORM, req.NEQ, req.COMPANY_NAME_RAW, req.COMPANY_NAME_NORM,
    req.HQ_CITY, req.INCORPORATION_YEAR, req.N_EMPLOYES, req.EMP_MIN,
    req.FORME_JURIDIQUE, req.PRODUCT_TIER, req.PRODUCT_SCORE,
    req.IS_TECH_SECTOR, req.MATCHED_SIGNALS,
    req.FLAG_NON_SA, req.FLAG_PRE_2010, req.FLAG_NO_EMPLOYEES
;

ALTER TABLE DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY
  CLUSTER BY (IS_IN_HS, IS_IN_DRM, PRODUCT_TIER, PRIORITY_SCORE);


/* ============================================================
   VALIDATION
   ============================================================ */

-- Overall match rates across all 3 sources
SELECT
    COUNT(*)                                  AS TOTAL_CANDIDATES,
    SUM(IFF(NOT IS_IN_HS AND NOT IS_IN_DRM AND NOT IS_IN_RC, 1, 0)) AS NET_NEW_ALL_SOURCES,
    SUM(IFF(IS_IN_HS,  1, 0))                 AS IN_HUBSPOT,
    SUM(IFF(IS_IN_DRM, 1, 0))                 AS IN_DEALROOM,
    SUM(IFF(IS_IN_RC,  1, 0))                 AS IN_RESEAU_CAPITAL,
    SUM(IFF(IS_IN_HS AND IS_IN_DRM, 1, 0))    AS IN_BOTH_HS_DRM,
    SUM(IFF(N_SOURCES_MATCHED = 0, 1, 0))     AS ZERO_SOURCES
FROM DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY;

-- Net-new by tier (IS_IN_HS=FALSE AND IS_IN_DRM=FALSE)
SELECT
    PRODUCT_TIER,
    COUNT(*)                                  AS TOTAL,
    SUM(IFF(NOT IS_IN_HS AND NOT IS_IN_DRM, 1, 0)) AS NET_NEW_HS_DRM,
    SUM(IFF(IS_IN_HS,  1, 0))                AS IN_HS,
    SUM(IFF(IS_IN_DRM, 1, 0))               AS IN_DRM
FROM DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY
GROUP BY PRODUCT_TIER
ORDER BY PRODUCT_TIER;

-- Match method breakdown
SELECT MATCHED_SRC, MATCH_TYPE, COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_EDGES_DEDUP
GROUP BY MATCHED_SRC, MATCH_TYPE
ORDER BY MATCHED_SRC, MATCH_TYPE;

-- Top 30 net-new by priority
SELECT
    NEQ, COMPANY_NAME_RAW, HQ_CITY,
    N_EMPLOYES, INCORPORATION_YEAR,
    PRODUCT_TIER, PRIORITY_SCORE, MATCHED_SIGNALS
FROM DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY
WHERE NOT IS_IN_HS AND NOT IS_IN_DRM
ORDER BY PRIORITY_SCORE DESC
LIMIT 30;
