/* ============================================================
   63D -- DEALROOM <-> RESEAU CAPITAL MATCHING
   ============================================================
   Matches Dealroom Quebec startups against Reseau Capital's
   COMPANY_MASTER (merged Harmonic + PitchBook) using a tiered
   waterfall strategy that mirrors the local Python implementation
   (match_dealroom_rc_20260330.py):

     Tier 1: Website domain (exact)
     Tier 2: LinkedIn company slug (exact)
     Tier 3: Crunchbase organization slug (exact)
     Tier 4: Normalized company name (NAME_SIM >= 0.85)

   Each tier is 1:1 — once a DR or RC company is matched, it is
   excluded from subsequent tiers. This is enforced via the dedup
   step (best tier wins per pair).

   Input:
     - DEV_QUEBECTECH.UTIL.T_ENTITIES (Dealroom records, with DOMAIN_NORM and LINKEDIN_NORM)
     - DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER (for Crunchbase URL and company name)
     - DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE (for Crunchbase URL if not in Silver)
     - DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER (RC merged Harmonic + PitchBook)

   Output:
     - DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES
     - DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
     - DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_SUMMARY

   Comparison: local Python matched ~2,853 DR companies against RC.
   This SQL version should produce similar numbers. Differences may
   arise from: (a) Snowflake NORM functions vs Python normalizers,
   (b) NAME_SIM threshold vs exact normalized name match in Python.

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-08
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;


/* ============================================================
   STEP 0: PREPARE DEALROOM IDENTIFIERS
   Pull normalized domain, LinkedIn, Crunchbase, and name
   from existing Silver/Entity tables into a single temp table.
   ============================================================ */

CREATE OR REPLACE TEMPORARY TABLE _TMP_DRM_IDS AS
SELECT
    drm.DEALROOM_ID,
    drm.NAME                                                 AS DRM_NAME,
    UTIL.NORM_NAME(drm.NAME)                                 AS DRM_NAME_NORM,
    UTIL.NAME_KEY(drm.NAME)                                  AS DRM_NAME_KEY,
    LEFT(UTIL.NORM_NAME(drm.NAME), 4)                        AS DRM_P4,
    drm.WEBSITE_DOMAIN                                       AS DRM_DOMAIN_RAW,
    ent.DOMAIN_NORM                                          AS DRM_DOMAIN_NORM,
    ent.LINKEDIN_NORM                                        AS DRM_LINKEDIN_NORM,
    -- Crunchbase: extract slug from Bronze (Dealroom raw Crunchbase field)
    LOWER(TRIM(
        REGEXP_SUBSTR(brz.CRUNCHBASE, '/organization/([^/\\?]+)', 1, 1, 'e', 1)
    ))                                                       AS DRM_CRUNCHBASE_SLUG
FROM DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm
LEFT JOIN DEV_QUEBECTECH.UTIL.T_ENTITIES ent
  ON ent.SRC = 'DEALROOM'
 AND ent.SRC_ID = drm.DEALROOM_ID::VARCHAR
LEFT JOIN DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE brz
  ON drm.DEALROOM_ID = brz.DEALROOM_ID
 AND brz.CRUNCHBASE IS NOT NULL
 AND brz.CRUNCHBASE != ''
WHERE drm.NAME IS NOT NULL;


/* ============================================================
   STEP 0B: PREPARE RC IDENTIFIERS
   Coalesce Harmonic + PitchBook fields into single columns.
   ============================================================ */

CREATE OR REPLACE TEMPORARY TABLE _TMP_RC_IDS AS
SELECT
    COALESCE(HARMONIC_COMPANY_ID::VARCHAR,
             PB_COMPANY_ID::VARCHAR)                         AS RC_COMPANY_ID,
    HARMONIC_COMPANY_ID,
    PB_COMPANY_ID,
    RECORD_TYPE,
    -- Domain: prefer PB, fallback H (same as Python)
    COALESCE(
        NULLIF(TRIM(LOWER(PB_WEBSITE_DOMAIN)), ''),
        NULLIF(TRIM(LOWER(H_WEBSITE_DOMAIN)), '')
    )                                                        AS RC_DOMAIN_NORM,
    -- LinkedIn: prefer H, fallback PB (same as Python)
    COALESCE(
        NULLIF(TRIM(LOWER(H_LINKEDIN_SLUG)), ''),
        NULLIF(TRIM(LOWER(PB_LINKEDIN_SLUG)), '')
    )                                                        AS RC_LINKEDIN_NORM,
    -- Crunchbase: Harmonic only
    NULLIF(TRIM(LOWER(CRUNCHBASE_SLUG)), '')                 AS RC_CRUNCHBASE_SLUG,
    -- Names: both sources
    H_COMPANY_NAME_NORM,
    PB_COMPANY_NAME_NORM,
    H_LEGAL_NAME_NORM,
    PB_LEGAL_NAME_NORM,
    -- Blocking keys on Harmonic name (primary)
    LEFT(H_COMPANY_NAME_NORM, 4)                             AS RC_P4_H,
    LEFT(PB_COMPANY_NAME_NORM, 4)                            AS RC_P4_PB,
    -- Geography (for registry)
    H_CITY, H_STATE, H_COUNTRY,
    PB_HQ_CITY, PB_HQ_STATE_PROVINCE, PB_HQ_COUNTRY
FROM DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER
WHERE COALESCE(HARMONIC_COMPANY_ID, PB_COMPANY_ID) IS NOT NULL;


/* ============================================================
   STEP 1: BUILD MATCH EDGES (4-tier waterfall)
   ============================================================ */

CREATE OR REPLACE TRANSIENT TABLE DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES AS

/* -----------------------------------------------------------
   Tier 1: Website domain (exact match on normalized domain)
   ----------------------------------------------------------- */
SELECT
    drm.DEALROOM_ID::VARCHAR                                 AS DRM_ID,
    rc.RC_COMPANY_ID                                         AS RC_ID,
    1                                                        AS MATCH_TIER,
    'DOMAIN'                                                 AS MATCH_FIELD,
    1.0::FLOAT                                               AS SCORE
FROM _TMP_DRM_IDS drm
JOIN _TMP_RC_IDS rc
  ON drm.DRM_DOMAIN_NORM IS NOT NULL
 AND rc.RC_DOMAIN_NORM IS NOT NULL
 AND drm.DRM_DOMAIN_NORM = rc.RC_DOMAIN_NORM
 AND drm.DRM_DOMAIN_NORM NOT IN (
     -- Exclude generic domains that would cause false matches
     'facebook.com', 'linkedin.com', 'twitter.com', 'github.com',
     'google.com', 'apple.com', 'microsoft.com', 'amazon.com',
     'shopify.com', 'wix.com', 'squarespace.com', 'wordpress.com',
     'gmail.com', 'outlook.com', 'yahoo.com'
 )

UNION ALL

/* -----------------------------------------------------------
   Tier 2: LinkedIn company slug (exact)
   ----------------------------------------------------------- */
SELECT
    drm.DEALROOM_ID::VARCHAR                                 AS DRM_ID,
    rc.RC_COMPANY_ID                                         AS RC_ID,
    2                                                        AS MATCH_TIER,
    'LINKEDIN'                                               AS MATCH_FIELD,
    1.0::FLOAT                                               AS SCORE
FROM _TMP_DRM_IDS drm
JOIN _TMP_RC_IDS rc
  ON drm.DRM_LINKEDIN_NORM IS NOT NULL
 AND rc.RC_LINKEDIN_NORM IS NOT NULL
 AND drm.DRM_LINKEDIN_NORM = rc.RC_LINKEDIN_NORM

UNION ALL

/* -----------------------------------------------------------
   Tier 3: Crunchbase organization slug (exact)
   ----------------------------------------------------------- */
SELECT
    drm.DEALROOM_ID::VARCHAR                                 AS DRM_ID,
    rc.RC_COMPANY_ID                                         AS RC_ID,
    3                                                        AS MATCH_TIER,
    'CRUNCHBASE'                                             AS MATCH_FIELD,
    1.0::FLOAT                                               AS SCORE
FROM _TMP_DRM_IDS drm
JOIN _TMP_RC_IDS rc
  ON drm.DRM_CRUNCHBASE_SLUG IS NOT NULL
 AND rc.RC_CRUNCHBASE_SLUG IS NOT NULL
 AND drm.DRM_CRUNCHBASE_SLUG = rc.RC_CRUNCHBASE_SLUG

UNION ALL

/* -----------------------------------------------------------
   Tier 4: Normalized name (fuzzy, NAME_SIM >= 0.85)
   Tries Dealroom name against all 4 RC name variants.
   Blocked by P4 (first 4 chars) for performance.
   ----------------------------------------------------------- */
SELECT
    drm.DEALROOM_ID::VARCHAR                                 AS DRM_ID,
    rc.RC_COMPANY_ID                                         AS RC_ID,
    4                                                        AS MATCH_TIER,
    'NAME_SIM'                                               AS MATCH_FIELD,
    GREATEST(
        COALESCE(UTIL.NAME_SIM(drm.DRM_NAME_NORM, rc.H_COMPANY_NAME_NORM), 0),
        COALESCE(UTIL.NAME_SIM(drm.DRM_NAME_NORM, rc.PB_COMPANY_NAME_NORM), 0),
        COALESCE(UTIL.NAME_SIM(drm.DRM_NAME_NORM, rc.H_LEGAL_NAME_NORM), 0),
        COALESCE(UTIL.NAME_SIM(drm.DRM_NAME_NORM, rc.PB_LEGAL_NAME_NORM), 0)
    )::FLOAT                                                 AS SCORE
FROM _TMP_DRM_IDS drm
JOIN _TMP_RC_IDS rc
  ON (drm.DRM_P4 = rc.RC_P4_H OR drm.DRM_P4 = rc.RC_P4_PB)
WHERE drm.DRM_NAME_NORM IS NOT NULL
  AND (rc.H_COMPANY_NAME_NORM IS NOT NULL OR rc.PB_COMPANY_NAME_NORM IS NOT NULL)
  AND GREATEST(
        COALESCE(UTIL.NAME_SIM(drm.DRM_NAME_NORM, rc.H_COMPANY_NAME_NORM), 0),
        COALESCE(UTIL.NAME_SIM(drm.DRM_NAME_NORM, rc.PB_COMPANY_NAME_NORM), 0),
        COALESCE(UTIL.NAME_SIM(drm.DRM_NAME_NORM, rc.H_LEGAL_NAME_NORM), 0),
        COALESCE(UTIL.NAME_SIM(drm.DRM_NAME_NORM, rc.PB_LEGAL_NAME_NORM), 0)
      ) >= 0.85
;


/* ============================================================
   STEP 2: DEDUPLICATE
   Best match per (DR, RC) pair: lowest tier wins, then highest score.
   Then enforce 1:1: best match per DR company, best match per RC company.
   ============================================================ */

-- Best tier per (DRM, RC) pair
CREATE OR REPLACE TRANSIENT TABLE _TMP_DEDUP_PAIR AS
SELECT *
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY DRM_ID, RC_ID
    ORDER BY MATCH_TIER ASC, SCORE DESC
) = 1;

-- Best RC match per Dealroom company (1:1)
CREATE OR REPLACE TRANSIENT TABLE _TMP_DEDUP_DRM AS
SELECT *
FROM _TMP_DEDUP_PAIR
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY DRM_ID
    ORDER BY MATCH_TIER ASC, SCORE DESC
) = 1;

-- Final 1:1: best DR match per RC company
CREATE OR REPLACE TRANSIENT TABLE DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP AS
SELECT *
FROM _TMP_DEDUP_DRM
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY RC_ID
    ORDER BY MATCH_TIER ASC, SCORE DESC
) = 1;


/* ============================================================
   STEP 3: SUMMARY -- one row per Dealroom company
   Shows whether matched to RC, which tier, and RC identifiers.
   ============================================================ */

CREATE OR REPLACE TABLE DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_SUMMARY AS
SELECT
    drm.DEALROOM_ID,
    drm.DRM_NAME,
    drm.DRM_DOMAIN_NORM,
    drm.DRM_LINKEDIN_NORM,

    -- Match info
    IFF(e.RC_ID IS NOT NULL, TRUE, FALSE)                    AS IS_IN_RC,
    e.MATCH_TIER,
    e.MATCH_FIELD,
    e.SCORE                                                  AS MATCH_SCORE,

    -- RC identifiers
    e.RC_ID                                                  AS RC_COMPANY_ID,
    rc.HARMONIC_COMPANY_ID,
    rc.PB_COMPANY_ID,
    COALESCE(rc.H_COMPANY_NAME_NORM, rc.PB_COMPANY_NAME_NORM) AS RC_NAME_NORM,
    rc.RC_DOMAIN_NORM,
    rc.RC_LINKEDIN_NORM,
    COALESCE(rc.H_CITY, rc.PB_HQ_CITY)                      AS RC_CITY,
    COALESCE(rc.H_STATE, rc.PB_HQ_STATE_PROVINCE)           AS RC_STATE,
    COALESCE(rc.H_COUNTRY, rc.PB_HQ_COUNTRY)                AS RC_COUNTRY,

    CURRENT_TIMESTAMP()                                      AS MATCHED_AT

FROM _TMP_DRM_IDS drm
LEFT JOIN DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP e
  ON drm.DEALROOM_ID::VARCHAR = e.DRM_ID
LEFT JOIN _TMP_RC_IDS rc
  ON e.RC_ID = rc.RC_COMPANY_ID
;


/* ============================================================
   VALIDATION
   ============================================================ */

-- Overall match rate
SELECT
    COUNT(*)                                  AS TOTAL_DRM,
    SUM(IFF(IS_IN_RC, 1, 0))                 AS MATCHED_RC,
    SUM(IFF(NOT IS_IN_RC, 1, 0))             AS UNMATCHED,
    ROUND(SUM(IFF(IS_IN_RC, 1, 0)) * 100.0 / COUNT(*), 1) AS MATCH_RATE_PCT
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_SUMMARY;

-- Tier breakdown
SELECT
    MATCH_TIER,
    MATCH_FIELD,
    COUNT(*) AS N,
    ROUND(AVG(SCORE), 3) AS AVG_SCORE
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
GROUP BY MATCH_TIER, MATCH_FIELD
ORDER BY MATCH_TIER;

-- Compare with local Python results (expected: ~2,853 matched)
SELECT 'SQL_MATCH' AS SOURCE, COUNT(*) AS MATCHED
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
UNION ALL
SELECT 'PYTHON_EXPECTED', 2853;

-- Top 20 tier-4 name matches (spot-check quality)
SELECT
    s.DRM_NAME,
    s.RC_NAME_NORM,
    s.MATCH_SCORE,
    s.DRM_DOMAIN_NORM,
    s.RC_DOMAIN_NORM
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_SUMMARY s
WHERE s.MATCH_TIER = 4
ORDER BY s.MATCH_SCORE ASC
LIMIT 20;
