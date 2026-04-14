/* ============================================================
   70 — DISCOVERY QUEUE (Final Output)
   ============================================================
   Creates three actionable Gold-layer output tables from the
   match summary produced by step 63R:

   1. GOLD.REQ_NET_NEW_STARTUPS
      Truly net-new companies: not in HubSpot, not in Dealroom.
      Sourced from strict candidates (REQ_STARTUP_CANDIDATES).
      Sorted by PRODUCT_TIER then PRIORITY_SCORE desc.

   2. GOLD.REQ_DISCOVERY_HUBSPOT_STAGING
      Net-new HIGH-tier companies formatted for HubSpot import
      review. Includes all fields needed for a new company record.
      IMPORTANT: HubSpot import — do NOT overwrite existing
      non-null fields. This table is for review only; final
      import must be approved by a human operator.

   3. GOLD.REQ_ENRICHMENT_OPPORTUNITIES
      Companies already in HubSpot or Dealroom but missing a
      NEQ link (backfill opportunity). Provides enrichment
      action flags per source.

   Prerequisites: Steps 31, 51, 63R must have run.
   (Step 32 is dropped — no successor chain needed.)

   Input:
     - DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY (from 63R)
     - DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES (from 51)

   Output:
     - DEV_QUEBECTECH.GOLD.REQ_NET_NEW_STARTUPS
     - DEV_QUEBECTECH.GOLD.REQ_DISCOVERY_HUBSPOT_STAGING
     - DEV_QUEBECTECH.GOLD.REQ_ENRICHMENT_OPPORTUNITIES

   Changes from original (2026-04-01):
     Rewritten 2026-04-07 to match verified Snowflake schema.
     Source table is now UTIL.T_REQ_STARTUP_MATCH_SUMMARY (from 63R).
     Sorting in REQ_NET_NEW_STARTUPS uses PRODUCT_TIER then
     N_EMPLOYES DESC (EMP_MIN) rather than PRIORITY_SCORE only.
     EMPLOYEE_BRACKET code references replaced with N_EMPLOYES text.
     Successor chain columns removed (Step 32 dropped).
     HQ_CITY column included throughout.
     MATCHED_SIGNALS used as AGENT_PRODUCT_SIGNALS in HubSpot staging.
     Enrichment table now targets IS_IN_HS=TRUE OR IS_IN_DRM=TRUE
     (no PitchBook / Harmonic in scope).

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-07
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;

CREATE SCHEMA IF NOT EXISTS DEV_QUEBECTECH.GOLD;


/* ============================================================
   1. NET-NEW STARTUPS
   ============================================================
   Companies that:
     - Pass strict filters (Société par actions, 2010+, has employees)
     - Have no match in HubSpot AND no match in Dealroom
   Sorted by PRODUCT_TIER (HIGH first), then N_EMPLOYES (largest first).
   ============================================================ */
CREATE OR REPLACE TABLE DEV_QUEBECTECH.GOLD.REQ_NET_NEW_STARTUPS AS
SELECT
    s.NEQ_NORM,
    s.NEQ,
    s.COMPANY_NAME_RAW,
    s.COMPANY_NAME_NORM,
    s.HQ_CITY,
    s.INCORPORATION_YEAR,
    s.N_EMPLOYES,
    s.EMP_MIN,
    s.FORME_JURIDIQUE,
    s.PRODUCT_TIER,
    s.PRODUCT_SCORE,
    s.PRIORITY_SCORE,
    s.IS_TECH_SECTOR,
    s.MATCHED_SIGNALS,
    s.IS_IN_RC,
    s.RC_COMPANY_ID,
    s.MATCH_METHOD_RC,
    'net_new'                                                AS DISCOVERY_TYPE,
    s.MATCHED_AT                                             AS DISCOVERED_AT
FROM DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY s
-- Only strict-view candidates (CIE, 2010+, has employees)
WHERE s.NEQ_NORM IN (
    SELECT NEQ_NORM FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES
)
-- Not found in either HubSpot or Dealroom
AND s.IS_IN_HS  = FALSE
AND s.IS_IN_DRM = FALSE
ORDER BY
    CASE s.PRODUCT_TIER
        WHEN 'HIGH'   THEN 0
        WHEN 'MEDIUM' THEN 1
        WHEN 'LOW'    THEN 2
        ELSE 3
    END,
    s.EMP_MIN DESC NULLS LAST,
    s.PRIORITY_SCORE DESC
;

ALTER TABLE DEV_QUEBECTECH.GOLD.REQ_NET_NEW_STARTUPS
  CLUSTER BY (PRODUCT_TIER, PRIORITY_SCORE);


/* ============================================================
   2. HUBSPOT STAGING
   ============================================================
   Net-new companies at HIGH tier, formatted for HubSpot
   import review. All columns map to HubSpot company properties.

   IMPORTANT: HubSpot import — do NOT overwrite existing
   non-null fields. This staging table is for human review
   before any import action. Fields prefixed AGENT_ write
   only to agent_ custom properties in HubSpot.
   ============================================================ */
CREATE OR REPLACE TABLE DEV_QUEBECTECH.GOLD.REQ_DISCOVERY_HUBSPOT_STAGING AS
SELECT
    NEQ_NORM,
    NEQ,
    COMPANY_NAME_RAW                                         AS HS_NAME,
    HQ_CITY                                                  AS HS_CITY,
    INCORPORATION_YEAR,
    N_EMPLOYES,
    EMP_MIN,
    PRODUCT_TIER,
    PRODUCT_SCORE,
    PRIORITY_SCORE,
    -- agent_ prefixed fields for HubSpot custom properties
    'req_discovery'                                          AS AGENT_SOURCE,
    CURRENT_DATE()                                           AS AGENT_DISCOVERY_DATE,
    PRODUCT_SCORE                                            AS AGENT_PRODUCT_SCORE,
    MATCHED_SIGNALS                                          AS AGENT_PRODUCT_SIGNALS,
    NEQ                                                      AS AGENT_REQ_NEQ,
    IS_TECH_SECTOR                                           AS AGENT_IS_TECH_SECTOR,
    DISCOVERED_AT
FROM DEV_QUEBECTECH.GOLD.REQ_NET_NEW_STARTUPS
WHERE PRODUCT_TIER = 'HIGH'
ORDER BY PRIORITY_SCORE DESC
;


/* ============================================================
   3. ENRICHMENT OPPORTUNITIES
   ============================================================
   Companies already in HubSpot or Dealroom that are missing
   a REQ NEQ link. These are candidates for backfill enrichment
   — adding the NEQ to the existing record rather than creating
   a new one. Match was made by name similarity.
   ============================================================ */
CREATE OR REPLACE TABLE DEV_QUEBECTECH.GOLD.REQ_ENRICHMENT_OPPORTUNITIES AS
SELECT
    s.NEQ_NORM,
    s.NEQ,
    s.COMPANY_NAME_RAW,
    s.COMPANY_NAME_NORM,
    s.HQ_CITY,
    s.INCORPORATION_YEAR,
    s.N_EMPLOYES,
    s.EMP_MIN,
    s.FORME_JURIDIQUE,
    s.PRODUCT_TIER,
    s.PRODUCT_SCORE,
    s.MATCHED_SIGNALS,

    -- Relaxation flags (why is this in the relaxed universe?)
    s.FLAG_NON_SA,
    s.FLAG_PRE_2010,
    s.FLAG_NO_EMPLOYEES,

    -- Match details per source
    s.IS_IN_HS,
    s.HS_COMPANY_ID,
    s.MATCH_METHOD_HS,
    s.MATCH_SCORE_HS,

    s.IS_IN_DRM,
    s.DRM_COMPANY_ID,
    s.MATCH_METHOD_DRM,
    s.MATCH_SCORE_DRM,

    s.IS_IN_RC,
    s.RC_COMPANY_ID,
    s.MATCH_METHOD_RC,
    s.MATCH_SCORE_RC,

    s.N_SOURCES_MATCHED,

    -- Enrichment actions
    -- NEQ backfill: matched by name (not by direct NEQ lookup)
    IFF(s.IS_IN_HS  AND s.MATCH_METHOD_HS  IN ('NAME_SIM', 'NAME_NORM'),
        'BACKFILL_NEQ_TO_HUBSPOT',  NULL)                   AS ACTION_HS,
    IFF(s.IS_IN_DRM AND s.MATCH_METHOD_DRM IN ('NAME_SIM', 'NAME_NORM'),
        'BACKFILL_NEQ_TO_DEALROOM', NULL)                   AS ACTION_DRM,
    IFF(s.IS_IN_RC,
        'LINK_RC_TO_REQ',           NULL)                   AS ACTION_RC,

    s.MATCHED_AT

FROM DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY s
-- Already known in at least one source
WHERE (s.IS_IN_HS = TRUE OR s.IS_IN_DRM = TRUE)
ORDER BY s.N_SOURCES_MATCHED DESC, s.PRIORITY_SCORE DESC
;


/* ============================================================
   DASHBOARD — Grand totals and sanity checks
   ============================================================ */

SELECT '=== REQ STARTUP DISCOVERY — FINAL RESULTS ===' AS HEADER;

-- Grand totals
SELECT
    (SELECT COUNT(*) FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES)
        AS STRICT_CANDIDATES,
    (SELECT COUNT(*) FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE)
        AS RELAXED_UNIVERSE,
    (SELECT COUNT(*) FROM DEV_QUEBECTECH.GOLD.REQ_NET_NEW_STARTUPS)
        AS NET_NEW,
    (SELECT COUNT(*) FROM DEV_QUEBECTECH.GOLD.REQ_DISCOVERY_HUBSPOT_STAGING)
        AS HUBSPOT_STAGING,
    (SELECT COUNT(*) FROM DEV_QUEBECTECH.GOLD.REQ_ENRICHMENT_OPPORTUNITIES)
        AS ENRICHMENT_OPP;

-- Net-new breakdown by tier and employee band
SELECT
    PRODUCT_TIER,
    COUNT(*)                                                 AS N,
    SUM(IFF(EMP_MIN >= 6,  1, 0))                           AS EMP_6PLUS,
    SUM(IFF(EMP_MIN >= 26, 1, 0))                           AS EMP_26PLUS,
    SUM(IFF(IS_IN_RC, 1, 0))                                AS ALSO_IN_RC
FROM DEV_QUEBECTECH.GOLD.REQ_NET_NEW_STARTUPS
GROUP BY PRODUCT_TIER
ORDER BY
    CASE PRODUCT_TIER WHEN 'HIGH' THEN 0 WHEN 'MEDIUM' THEN 1 ELSE 2 END;

-- Enrichment opportunities by action type
SELECT
    SUM(IFF(ACTION_HS  IS NOT NULL, 1, 0))                  AS CAN_BACKFILL_HS,
    SUM(IFF(ACTION_DRM IS NOT NULL, 1, 0))                  AS CAN_BACKFILL_DRM,
    SUM(IFF(ACTION_RC  IS NOT NULL, 1, 0))                  AS CAN_LINK_RC,
    COUNT(*)                                                 AS TOTAL_ENRICHMENT_OPP
FROM DEV_QUEBECTECH.GOLD.REQ_ENRICHMENT_OPPORTUNITIES;

-- Top 20 HubSpot staging queue
SELECT
    NEQ,
    HS_NAME,
    HS_CITY,
    N_EMPLOYES,
    INCORPORATION_YEAR,
    PRODUCT_TIER,
    PRIORITY_SCORE,
    AGENT_PRODUCT_SIGNALS
FROM DEV_QUEBECTECH.GOLD.REQ_DISCOVERY_HUBSPOT_STAGING
ORDER BY PRIORITY_SCORE DESC
LIMIT 20;

-- Top 10 enrichment backfill candidates (HS)
SELECT
    NEQ,
    COMPANY_NAME_RAW,
    HS_COMPANY_ID,
    MATCH_METHOD_HS,
    MATCH_SCORE_HS,
    ACTION_HS,
    N_EMPLOYES,
    PRODUCT_TIER
FROM DEV_QUEBECTECH.GOLD.REQ_ENRICHMENT_OPPORTUNITIES
WHERE ACTION_HS IS NOT NULL
ORDER BY MATCH_SCORE_HS DESC
LIMIT 10;
