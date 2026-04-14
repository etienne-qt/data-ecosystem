/* ============================================================
   80 -- CONSOLIDATED STARTUP REGISTRY
   ============================================================
   Full outer join of Quebec Tech's startup universe (Dealroom-
   anchored) and Réseau Capital's Quebec company universe.

   Three entity types in the output:
     MATCHED    — in both QT and RC (deduplicated, enriched from both)
     QT_ONLY    — in QT universe but not matched to RC
     RC_ONLY    — in RC Quebec but not matched to any QT startup

   Conflicts between sources are flagged, not resolved.
   No source data is overwritten.

   Patch history:
     2026-04-10 — C→B promotion, whitelist/blacklist application,
                  ambiguous-sector flags, RATING_LETTER_EFFECTIVE,
                  QT_INCLUSION_REASON, non-tech name-keyword flag
                  (Q2-informed). REF schema is now a hard precondition.
     2026-04-08 — initial build.

   Prerequisites (must have run):
     - 63D: DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
     - 70_manual_review_tables.sql (creates REF schema + views) ← NEW
     - DEV_QUEBECTECH.UTIL.T_CLUSTERS_HS_DRM
     - DEV_QUEBECTECH.SILVER.DRM_REGISTRY_BRIDGE_SILVER
     - DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER
     - DEV_RESEAUCAPITAL.SILVER.PITCHBOOK_ACQ_COMPANIES (enrichment)

   Output:
     - DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-10
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;

CREATE SCHEMA IF NOT EXISTS DEV_QUEBECTECH.GOLD;


/* ============================================================
   PREFLIGHT: REF schema must exist (from 70_manual_review_tables.sql)
   Fails fast with a clear error if misordered.
   ============================================================ */
SELECT
    COUNT(*) AS REF_WHITELIST_COUNT
FROM DEV_QUEBECTECH.REF.V_STARTUP_WHITELIST;

-- Diagnostic: classification rating of each whitelisted DR row.
-- If any show DRM_RATING = 'D' or NULL, they'll be invisible to
-- the A+/A/B/C filter in _QT_CANDIDATES and the whitelist won't
-- flow through. Investigate if that happens.
SELECT
    wl.DEALROOM_ID,
    wl.RC_COMPANY_ID,
    cls.RATING_LETTER AS DRM_RATING,
    drm.NAME          AS DRM_NAME
FROM DEV_QUEBECTECH.REF.V_MATCH_WHITELIST wl
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm
  ON drm.DEALROOM_ID::VARCHAR = wl.DEALROOM_ID
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
  ON cls.DEALROOM_ID = drm.DEALROOM_ID
ORDER BY cls.RATING_LETTER NULLS LAST;


/* ============================================================
   PART A1: QT CANDIDATES (pre-effective-rating)
   Widened to include A+/A/B AND C. C rows are kept at this stage
   so downstream logic can promote them to B when matched to RC.
   Also attaches whitelist/blacklist signals and sector flags.
   ============================================================ */

CREATE OR REPLACE TEMPORARY TABLE _QT_CANDIDATES AS
SELECT
    -- Dealroom core
    drm.DEALROOM_ID,
    drm.NAME                                                 AS DRM_NAME,
    drm.WEBSITE_DOMAIN                                       AS DRM_DOMAIN,
    drm.TAGLINE                                              AS DRM_TAGLINE,
    drm.HQ_CITY                                              AS DRM_CITY,
    drm.HQ_STATE                                             AS DRM_STATE,
    drm.HQ_COUNTRY                                           AS DRM_COUNTRY,
    drm.LAUNCH_YEAR                                          AS DRM_LAUNCH_YEAR,
    drm.EMPLOYEES_LATEST_NUMBER                              AS DRM_EMPLOYEES,
    drm.TOTAL_FUNDING_USD_M                                  AS DRM_FUNDING_USD_M,
    drm.COMPANY_STATUS                                       AS DRM_COMPANY_STATUS,
    drm.INDUSTRIES_RAW                                       AS DRM_INDUSTRIES,

    -- Classification (raw, before effective-rating logic)
    cls.RATING_LETTER                                        AS DRM_RATING_RAW,
    cls.STARTUP_STATUS                                       AS DRM_STARTUP_STATUS,

    -- Geography
    geo.REGION_ADMIN                                         AS DRM_REGION,
    geo.AGGLOMERATION                                        AS DRM_AGGLOMERATION,

    -- Industry
    ind.TOP_INDUSTRY                                         AS DRM_TOP_INDUSTRY,

    -- HubSpot link (via clusters)
    hs_link.HS_COMPANY_ID,
    hs.HS_NAME_RAW                                           AS HS_NAME,
    hs.HS_DOMAIN_NORM                                        AS HS_DOMAIN,
    hs.HS_NEQ_NORM                                           AS HS_NEQ,

    -- REQ link (via bridge)
    bridge.NEQ_FINAL                                         AS REQ_NEQ,
    bridge.MATCH_SOURCE                                      AS REQ_MATCH_SOURCE,

    -- ================================================================
    -- MATCH PRESENCE (for C-promotion logic)
    -- ================================================================
    IFF(mb.RC_ID IS NOT NULL, TRUE, FALSE)                   AS HAS_RC_MATCH_AT_CANDIDATE_STAGE,

    -- ================================================================
    -- MANUAL REVIEW SIGNALS (from REF schema)
    -- ================================================================
    IFF(wl.DEALROOM_ID IS NOT NULL, TRUE, FALSE)             AS IS_STARTUP_WHITELISTED,
    IFF(bl.DEALROOM_ID IS NOT NULL, TRUE, FALSE)             AS IS_STARTUP_BLACKLISTED,
    wl.DECISION_NOTE                                         AS WHITELIST_NOTE,
    bl.DECISION_NOTE                                         AS BLACKLIST_NOTE,

    -- ================================================================
    -- AMBIGUOUS-SECTOR FLAGS (flags, not exclusions)
    -- Keywords inline for now; TODO: extract to REF.AMBIGUOUS_SECTOR_KEYWORDS.
    -- ================================================================
    IFF(LOWER(COALESCE(ind.TOP_INDUSTRY, '') || ' ' ||
              COALESCE(drm.INDUSTRIES_RAW, '')) RLIKE
        '.*(gaming|game|esports|casino).*',
        TRUE, FALSE)                                         AS FLAG_SECTOR_GAMING,

    IFF(LOWER(COALESCE(ind.TOP_INDUSTRY, '') || ' ' ||
              COALESCE(drm.INDUSTRIES_RAW, '')) RLIKE
        '.*(pharma|pharmaceutical|drug|biotech|life science|biolog).*',
        TRUE, FALSE)                                         AS FLAG_SECTOR_PHARMA_BIOTECH,

    IFF(LOWER(COALESCE(ind.TOP_INDUSTRY, '') || ' ' ||
              COALESCE(drm.INDUSTRIES_RAW, '')) RLIKE
        '.*(consult|agency|service).*',
        TRUE, FALSE)                                         AS FLAG_SECTOR_SERVICES,

    -- ================================================================
    -- NON-TECH NAME KEYWORD HIT (Q2-informed, 2026-04-10)
    -- Scans DR company name for patterns common in non-tech shops
    -- mislabeled as "ICT / Enterprise Software" in Dealroom.
    -- Flag only; never auto-excludes.
    -- ================================================================
    IFF(LOWER(drm.NAME) RLIKE
        '.*(consulting|consultant|\\bservices\\b|agency|' ||
        'r[ée]novation|\\br[ée]no\\b|construction|d[ée]m[ée]nagement|' ||
        'immobilier|transport|enseigne|cabinet|conseil).*',
        TRUE, FALSE)                                         AS FLAG_NON_TECH_NAME_HIT

FROM DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm

-- Classification: widened to include C (for promotion logic)
JOIN DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
  ON drm.DEALROOM_ID = cls.DEALROOM_ID
 AND cls.RATING_LETTER IN ('A+', 'A', 'B', 'C')

-- 63D match presence (for C-promotion + downstream).
-- LEFT JOIN against the UNIONed match source so that manually
-- whitelisted pairs also flip HAS_RC_MATCH_AT_CANDIDATE_STAGE,
-- which lets C-rated DR rows get promoted to B via a whitelist
-- decision even if 63D missed them.
LEFT JOIN (
    SELECT DRM_ID, RC_ID
    FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
    UNION
    SELECT DEALROOM_ID AS DRM_ID, RC_COMPANY_ID AS RC_ID
    FROM DEV_QUEBECTECH.REF.V_MATCH_WHITELIST
    WHERE DEALROOM_ID IS NOT NULL AND RC_COMPANY_ID IS NOT NULL
) mb
  ON mb.DRM_ID = drm.DEALROOM_ID::VARCHAR

-- Geography
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_GEO_ENRICHMENT_SILVER geo
  ON drm.DEALROOM_ID = geo.DEALROOM_ID

-- Industry
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_INDUSTRY_SIGNALS_SILVER ind
  ON drm.DEALROOM_ID = ind.DEALROOM_ID

-- HubSpot link via clusters
LEFT JOIN (
    SELECT
        drm_c.SRC_ID AS DEALROOM_ID,
        hs_c.SRC_ID  AS HS_COMPANY_ID
    FROM DEV_QUEBECTECH.UTIL.T_CLUSTERS_HS_DRM drm_c
    JOIN DEV_QUEBECTECH.UTIL.T_CLUSTERS_HS_DRM hs_c
      ON drm_c.CLUSTER_ID = hs_c.CLUSTER_ID
     AND hs_c.SRC = 'HUBSPOT'
    WHERE drm_c.SRC = 'DEALROOM'
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY drm_c.SRC_ID ORDER BY hs_c.SRC_ID
    ) = 1
) hs_link ON drm.DEALROOM_ID::VARCHAR = hs_link.DEALROOM_ID

-- HubSpot data
LEFT JOIN DEV_QUEBECTECH.UTIL.V_HS_CLEAN hs
  ON hs_link.HS_COMPANY_ID = hs.HS_COMPANY_ID::VARCHAR

-- REQ link via bridge
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_REGISTRY_BRIDGE_SILVER bridge
  ON drm.DEALROOM_ID = bridge.DEALROOM_ID
 AND bridge.NEQ_FINAL IS NOT NULL

-- Manual review decisions (DR-side)
LEFT JOIN DEV_QUEBECTECH.REF.V_STARTUP_WHITELIST wl
  ON wl.DEALROOM_ID = drm.DEALROOM_ID::VARCHAR
LEFT JOIN DEV_QUEBECTECH.REF.V_STARTUP_BLACKLIST bl
  ON bl.DEALROOM_ID = drm.DEALROOM_ID::VARCHAR
;


/* ============================================================
   PART A2: QT UNIVERSE (apply effective-rating + inclusion filter)
   Effective rating logic:
     - Blacklisted          → dropped (EFFECTIVE = NULL)
     - Raw in ('A+','A','B')→ keep, effective = raw
     - Raw = 'C' + matched  → promoted, effective = 'B'
     - Whitelisted (any raw)→ keep, effective = 'B' (default promo)
     - Otherwise            → dropped
   Inclusion reason captures the provenance for auditing.
   ============================================================ */

CREATE OR REPLACE TEMPORARY TABLE _QT_UNIVERSE AS
SELECT *
FROM (
    SELECT
        c.*,

        -- Effective rating after promotion/whitelist/blacklist
        CASE
            WHEN c.IS_STARTUP_BLACKLISTED                     THEN NULL
            WHEN c.DRM_RATING_RAW IN ('A+', 'A', 'B')         THEN c.DRM_RATING_RAW
            WHEN c.DRM_RATING_RAW = 'C'
                 AND c.HAS_RC_MATCH_AT_CANDIDATE_STAGE        THEN 'B'
            WHEN c.IS_STARTUP_WHITELISTED                     THEN 'B'
            ELSE NULL
        END                                                  AS RATING_LETTER_EFFECTIVE,

        -- Why this row is in the QT universe
        CASE
            WHEN c.IS_STARTUP_BLACKLISTED                     THEN 'BLACKLISTED'
            WHEN c.DRM_RATING_RAW = 'A+'                      THEN 'CLS_APLUS'
            WHEN c.DRM_RATING_RAW = 'A'                       THEN 'CLS_A'
            WHEN c.DRM_RATING_RAW = 'B'                       THEN 'CLS_B'
            WHEN c.DRM_RATING_RAW = 'C'
                 AND c.HAS_RC_MATCH_AT_CANDIDATE_STAGE        THEN 'C_PROMOTED_RC_MATCH'
            WHEN c.IS_STARTUP_WHITELISTED                     THEN 'MANUAL_WHITELIST'
            ELSE 'EXCLUDED'
        END                                                  AS QT_INCLUSION_REASON
    FROM _QT_CANDIDATES c
) x
WHERE x.RATING_LETTER_EFFECTIVE IS NOT NULL
;


/* ============================================================
   PART B: RC QUEBEC UNIVERSE
   All RC companies with Quebec geography.
   Enriched with PitchBook acquisition data where available.
   ============================================================ */

CREATE OR REPLACE TEMPORARY TABLE _RC_UNIVERSE AS
SELECT
    COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
             cm.PB_COMPANY_ID::VARCHAR)                      AS RC_COMPANY_ID,
    cm.HARMONIC_COMPANY_ID                                   AS RC_HARMONIC_ID,
    cm.PB_COMPANY_ID                                         AS RC_PB_ID,
    cm.RECORD_TYPE                                           AS RC_RECORD_TYPE,

    -- Names (coalesced)
    COALESCE(cm.H_COMPANY_NAME_NORM,
             cm.PB_COMPANY_NAME_NORM)                        AS RC_NAME,
    COALESCE(cm.H_LEGAL_NAME_NORM,
             cm.PB_LEGAL_NAME_NORM)                          AS RC_LEGAL_NAME,

    -- Identifiers
    COALESCE(NULLIF(TRIM(LOWER(cm.H_WEBSITE_DOMAIN)), ''),
             NULLIF(TRIM(LOWER(cm.PB_WEBSITE_DOMAIN)), '')) AS RC_DOMAIN,
    COALESCE(NULLIF(TRIM(LOWER(cm.H_LINKEDIN_SLUG)), ''),
             NULLIF(TRIM(LOWER(cm.PB_LINKEDIN_SLUG)), '')) AS RC_LINKEDIN,
    cm.CRUNCHBASE_SLUG                                       AS RC_CRUNCHBASE,

    -- Geography (coalesced)
    COALESCE(cm.H_CITY, cm.PB_HQ_CITY)                      AS RC_CITY,
    COALESCE(cm.H_STATE, cm.PB_HQ_STATE_PROVINCE)           AS RC_STATE,
    COALESCE(cm.H_COUNTRY, cm.PB_HQ_COUNTRY)                AS RC_COUNTRY,

    -- Founding
    COALESCE(YEAR(cm.H_FOUNDING_DATE),
             cm.PB_YEAR_FOUNDED)                             AS RC_FOUNDING_YEAR,

    -- PitchBook enrichment (join when PB_COMPANY_ID available)
    pb.HEADCOUNT                                             AS RC_HEADCOUNT,
    pb.TOTAL_RAISED_CAD                                      AS RC_TOTAL_RAISED_CAD,
    pb.REVENUE_CAD                                           AS RC_REVENUE_CAD,
    pb.FINANCING_STATUS                                      AS RC_FINANCING_STATUS,
    pb.BUSINESS_STATUS                                       AS RC_BUSINESS_STATUS,
    pb.INDUSTRY_SECTOR                                       AS RC_INDUSTRY_SECTOR,
    pb.BROADER_SECTOR                                        AS RC_BROADER_SECTOR,
    pb.LAST_FINANCING_DATE                                   AS RC_LAST_FINANCING_DATE,
    pb.LAST_FINANCING_SIZE_CAD                               AS RC_LAST_FINANCING_CAD,
    pb.LAST_FINANCING_DEAL_TYPE                              AS RC_LAST_FINANCING_TYPE,

    -- ================================================================
    -- MANUAL REVIEW SIGNALS (RC-side)
    -- ================================================================
    IFF(wl.RC_COMPANY_ID IS NOT NULL, TRUE, FALSE)           AS RC_IS_STARTUP_WHITELISTED,
    IFF(bl.RC_COMPANY_ID IS NOT NULL, TRUE, FALSE)           AS RC_IS_STARTUP_BLACKLISTED,
    wl.DECISION_NOTE                                         AS RC_WHITELIST_NOTE,
    bl.DECISION_NOTE                                         AS RC_BLACKLIST_NOTE,

    -- ================================================================
    -- AMBIGUOUS-SECTOR FLAGS (RC-side, from PB_INDUSTRY_SECTOR)
    -- ================================================================
    IFF(LOWER(COALESCE(pb.INDUSTRY_SECTOR, '')) RLIKE
        '.*(gaming|game|esports|casino).*',
        TRUE, FALSE)                                         AS RC_FLAG_SECTOR_GAMING,
    IFF(LOWER(COALESCE(pb.INDUSTRY_SECTOR, '')) RLIKE
        '.*(pharma|pharmaceutical|drug|biotech|life science|biolog).*',
        TRUE, FALSE)                                         AS RC_FLAG_SECTOR_PHARMA_BIOTECH,
    IFF(LOWER(COALESCE(pb.INDUSTRY_SECTOR, '')) RLIKE
        '.*(consult|agency|service).*',
        TRUE, FALSE)                                         AS RC_FLAG_SECTOR_SERVICES

FROM DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER cm
LEFT JOIN DEV_RESEAUCAPITAL.SILVER.PITCHBOOK_ACQ_COMPANIES pb
  ON cm.PB_COMPANY_ID = pb.PB_COMPANY_ID

-- Manual review decisions (RC-side)
LEFT JOIN DEV_QUEBECTECH.REF.V_STARTUP_WHITELIST wl
  ON wl.RC_COMPANY_ID = COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
                                  cm.PB_COMPANY_ID::VARCHAR)
LEFT JOIN DEV_QUEBECTECH.REF.V_STARTUP_BLACKLIST bl
  ON bl.RC_COMPANY_ID = COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
                                  cm.PB_COMPANY_ID::VARCHAR)

-- Filter to Quebec
WHERE LOWER(COALESCE(cm.H_STATE, cm.PB_HQ_STATE_PROVINCE, '')) IN (
    'quebec', 'québec', 'qc', 'que'
)
   OR LOWER(COALESCE(cm.H_COUNTRY, cm.PB_HQ_COUNTRY, '')) IN (
    'quebec', 'québec'
)
;


/* ============================================================
   PART C: FULL OUTER JOIN VIA 63D MATCH
   Three categories: MATCHED, QT_ONLY, RC_ONLY
   ============================================================ */

CREATE OR REPLACE TABLE DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY AS

WITH match_bridge_raw AS (
    -- 63D deduped match: DEALROOM_ID <-> RC_COMPANY_ID
    SELECT
        DRM_ID       AS DEALROOM_ID,
        RC_ID        AS RC_COMPANY_ID,
        MATCH_TIER,
        MATCH_FIELD,
        SCORE        AS MATCH_SCORE
    FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP

    UNION ALL

    -- Manual match whitelist: pairs confirmed in REF that the
    -- 63D matcher missed. Synthetic tier 0 / score 1.0 so they
    -- win the QUALIFY below if they ever conflict with 63D.
    -- (Q4 2026-04-14 seeded 8 domain near-misses here.)
    SELECT
        DEALROOM_ID,
        RC_COMPANY_ID,
        0                    AS MATCH_TIER,
        'MANUAL_WHITELIST'   AS MATCH_FIELD,
        1.0                  AS MATCH_SCORE
    FROM DEV_QUEBECTECH.REF.V_MATCH_WHITELIST
    WHERE DEALROOM_ID IS NOT NULL
      AND RC_COMPANY_ID IS NOT NULL
),
match_bridge AS (
    -- One match per DR side; whitelist (tier 0) beats 63D tiers 1-4
    SELECT * FROM match_bridge_raw
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY DEALROOM_ID
        ORDER BY MATCH_TIER ASC, MATCH_SCORE DESC NULLS LAST
    ) = 1
)

SELECT
    -- Registry key
    COALESCE(qt.DEALROOM_ID::VARCHAR, 'RC_' || rc.RC_COMPANY_ID) AS REGISTRY_ID,

    -- Entity type
    CASE
        WHEN qt.DEALROOM_ID IS NOT NULL AND rc.RC_COMPANY_ID IS NOT NULL THEN 'MATCHED'
        WHEN qt.DEALROOM_ID IS NOT NULL THEN 'QT_ONLY'
        ELSE 'RC_ONLY'
    END                                                      AS ENTITY_TYPE,

    -- ================================================================
    -- CANONICAL FIELDS (QT preferred when matched, RC fallback)
    -- ================================================================
    COALESCE(qt.DRM_NAME, rc.RC_NAME)                        AS CANONICAL_NAME,
    COALESCE(qt.DRM_CITY, rc.RC_CITY)                        AS CANONICAL_CITY,
    COALESCE(qt.DRM_LAUNCH_YEAR, rc.RC_FOUNDING_YEAR)        AS CANONICAL_FOUNDING_YEAR,
    COALESCE(qt.DRM_DOMAIN, rc.RC_DOMAIN)                    AS CANONICAL_DOMAIN,
    COALESCE(qt.DRM_TOP_INDUSTRY, rc.RC_BROADER_SECTOR)      AS CANONICAL_SECTOR,

    -- ================================================================
    -- QT / DEALROOM FIELDS
    -- ================================================================
    qt.DEALROOM_ID,
    qt.DRM_NAME,
    qt.DRM_DOMAIN,
    qt.DRM_TAGLINE,
    qt.DRM_CITY,
    qt.DRM_STATE,
    qt.DRM_COUNTRY,
    qt.DRM_LAUNCH_YEAR,
    qt.DRM_EMPLOYEES,
    qt.DRM_FUNDING_USD_M,
    qt.DRM_COMPANY_STATUS,
    qt.DRM_INDUSTRIES,
    qt.DRM_RATING_RAW,
    qt.RATING_LETTER_EFFECTIVE,
    qt.QT_INCLUSION_REASON,
    qt.DRM_STARTUP_STATUS,
    qt.DRM_REGION,
    qt.DRM_AGGLOMERATION,
    qt.DRM_TOP_INDUSTRY,

    -- ================================================================
    -- HUBSPOT FIELDS (via QT clusters)
    -- ================================================================
    qt.HS_COMPANY_ID,
    qt.HS_NAME,
    qt.HS_DOMAIN,
    qt.HS_NEQ,

    -- ================================================================
    -- REQ FIELDS (via DRM registry bridge)
    -- ================================================================
    qt.REQ_NEQ,
    qt.REQ_MATCH_SOURCE,

    -- ================================================================
    -- RC / RESEAU CAPITAL FIELDS
    -- ================================================================
    rc.RC_COMPANY_ID,
    rc.RC_HARMONIC_ID,
    rc.RC_PB_ID,
    rc.RC_RECORD_TYPE,
    rc.RC_NAME,
    rc.RC_LEGAL_NAME,
    rc.RC_DOMAIN,
    rc.RC_LINKEDIN,
    rc.RC_CRUNCHBASE,
    rc.RC_CITY,
    rc.RC_STATE,
    rc.RC_FOUNDING_YEAR,
    rc.RC_HEADCOUNT,
    rc.RC_TOTAL_RAISED_CAD,
    rc.RC_REVENUE_CAD,
    rc.RC_FINANCING_STATUS,
    rc.RC_BUSINESS_STATUS,
    rc.RC_INDUSTRY_SECTOR,
    rc.RC_BROADER_SECTOR,
    rc.RC_LAST_FINANCING_DATE,
    rc.RC_LAST_FINANCING_CAD,
    rc.RC_LAST_FINANCING_TYPE,

    -- ================================================================
    -- MATCH METADATA
    -- Null out when the RC side isn't resolved in _RC_UNIVERSE
    -- (e.g. match edge points to a non-Quebec RC row, or RC side
    -- was blacklisted). Prevents orphan tier/score on QT_ONLY rows.
    -- ================================================================
    IFF(rc.RC_COMPANY_ID IS NOT NULL, mb.MATCH_TIER,  NULL)  AS DR_RC_MATCH_TIER,
    IFF(rc.RC_COMPANY_ID IS NOT NULL, mb.MATCH_FIELD, NULL)  AS DR_RC_MATCH_FIELD,
    IFF(rc.RC_COMPANY_ID IS NOT NULL, mb.MATCH_SCORE, NULL)  AS DR_RC_MATCH_SCORE,

    -- ================================================================
    -- COVERAGE FLAGS
    -- ================================================================
    IFF(qt.DEALROOM_ID IS NOT NULL, TRUE, FALSE)             AS HAS_DEALROOM,
    IFF(qt.HS_COMPANY_ID IS NOT NULL, TRUE, FALSE)           AS HAS_HUBSPOT,
    IFF(rc.RC_COMPANY_ID IS NOT NULL, TRUE, FALSE)           AS HAS_RC,
    IFF(qt.REQ_NEQ IS NOT NULL, TRUE, FALSE)                 AS HAS_REQ,
    IFF(qt.DEALROOM_ID IS NOT NULL, 1, 0)
    + IFF(qt.HS_COMPANY_ID IS NOT NULL, 1, 0)
    + IFF(rc.RC_COMPANY_ID IS NOT NULL, 1, 0)
    + IFF(qt.REQ_NEQ IS NOT NULL, 1, 0)                     AS N_SOURCES,

    -- ================================================================
    -- CONFLICT / EXCEPTION FLAGS
    -- ================================================================

    -- Name conflict: QT and RC names diverge significantly
    IFF(qt.DRM_NAME IS NOT NULL AND rc.RC_NAME IS NOT NULL
        AND UTIL.NAME_SIM(UTIL.NORM_NAME(qt.DRM_NAME), rc.RC_NAME) < 0.75,
        TRUE, FALSE)                                         AS FLAG_NAME_CONFLICT_QT_RC,

    -- Domain conflict: both have domains but they differ
    IFF(qt.DRM_DOMAIN IS NOT NULL AND rc.RC_DOMAIN IS NOT NULL
        AND qt.DRM_DOMAIN != rc.RC_DOMAIN,
        TRUE, FALSE)                                         AS FLAG_DOMAIN_CONFLICT_QT_RC,

    -- City conflict: matched but different cities.
    -- Uses UTIL.NORMALIZE_TEXT_FOR_MATCHING so Montréal == Montreal,
    -- Québec == Quebec, St-Jean == St Jean, etc.
    IFF(qt.DRM_CITY IS NOT NULL AND rc.RC_CITY IS NOT NULL
        AND UTIL.NORMALIZE_TEXT_FOR_MATCHING(qt.DRM_CITY)
            != UTIL.NORMALIZE_TEXT_FOR_MATCHING(rc.RC_CITY),
        TRUE, FALSE)                                         AS FLAG_CITY_CONFLICT_QT_RC,

    -- Founding year conflict: > 2 year gap
    IFF(qt.DRM_LAUNCH_YEAR IS NOT NULL AND rc.RC_FOUNDING_YEAR IS NOT NULL
        AND ABS(qt.DRM_LAUNCH_YEAR - rc.RC_FOUNDING_YEAR) > 2,
        TRUE, FALSE)                                         AS FLAG_YEAR_CONFLICT_QT_RC,

    -- Employee conflict: large discrepancy (>5x)
    IFF(qt.DRM_EMPLOYEES IS NOT NULL AND qt.DRM_EMPLOYEES > 0
        AND rc.RC_HEADCOUNT IS NOT NULL AND rc.RC_HEADCOUNT > 0
        AND GREATEST(qt.DRM_EMPLOYEES, rc.RC_HEADCOUNT)
            / LEAST(qt.DRM_EMPLOYEES, rc.RC_HEADCOUNT) > 5,
        TRUE, FALSE)                                         AS FLAG_EMPLOYEE_CONFLICT_QT_RC,

    -- Low-confidence name match (tier 4 with score < 0.90).
    -- Only fires when the RC side is actually resolved — otherwise
    -- the match metadata is orphan and the flag is meaningless.
    IFF(rc.RC_COMPANY_ID IS NOT NULL
        AND mb.MATCH_TIER = 4 AND mb.MATCH_SCORE < 0.90,
        TRUE, FALSE)                                         AS FLAG_LOW_CONFIDENCE_MATCH,

    -- HS/DR name conflict
    IFF(qt.DRM_NAME IS NOT NULL AND qt.HS_NAME IS NOT NULL
        AND UTIL.NAME_SIM(UTIL.NORM_NAME(qt.DRM_NAME),
                          UTIL.NORM_NAME(qt.HS_NAME)) < 0.80,
        TRUE, FALSE)                                         AS FLAG_NAME_CONFLICT_QT_HS,

    -- ================================================================
    -- MANUAL REVIEW + SECTOR FLAGS (new 2026-04-10)
    -- ================================================================

    -- Review state (from REF schema, DR-side or RC-side)
    COALESCE(qt.IS_STARTUP_WHITELISTED, rc.RC_IS_STARTUP_WHITELISTED, FALSE)
                                                             AS IS_STARTUP_WHITELISTED,
    COALESCE(qt.IS_STARTUP_BLACKLISTED, rc.RC_IS_STARTUP_BLACKLISTED, FALSE)
                                                             AS IS_STARTUP_BLACKLISTED,

    -- Sector flags — DR takes priority for MATCHED/QT_ONLY rows;
    -- union with RC for MATCHED (either source can trigger the flag)
    COALESCE(qt.FLAG_SECTOR_GAMING, FALSE)
        OR COALESCE(rc.RC_FLAG_SECTOR_GAMING, FALSE)         AS FLAG_SECTOR_GAMING,
    COALESCE(qt.FLAG_SECTOR_PHARMA_BIOTECH, FALSE)
        OR COALESCE(rc.RC_FLAG_SECTOR_PHARMA_BIOTECH, FALSE) AS FLAG_SECTOR_PHARMA_BIOTECH,
    COALESCE(qt.FLAG_SECTOR_SERVICES, FALSE)
        OR COALESCE(rc.RC_FLAG_SECTOR_SERVICES, FALSE)       AS FLAG_SECTOR_SERVICES,

    -- Any ambiguous-sector flag raised
    (COALESCE(qt.FLAG_SECTOR_GAMING, FALSE)
     OR COALESCE(qt.FLAG_SECTOR_PHARMA_BIOTECH, FALSE)
     OR COALESCE(qt.FLAG_SECTOR_SERVICES, FALSE)
     OR COALESCE(rc.RC_FLAG_SECTOR_GAMING, FALSE)
     OR COALESCE(rc.RC_FLAG_SECTOR_PHARMA_BIOTECH, FALSE)
     OR COALESCE(rc.RC_FLAG_SECTOR_SERVICES, FALSE))         AS FLAG_SECTOR_ANY,

    -- Non-tech name keyword hit (DR-side, Q2-informed)
    COALESCE(qt.FLAG_NON_TECH_NAME_HIT, FALSE)               AS FLAG_NON_TECH_NAME_HIT,

    -- Any flag raised (rolled up for the review queue)
    IFF(
        (qt.DRM_NAME IS NOT NULL AND rc.RC_NAME IS NOT NULL
         AND UTIL.NAME_SIM(UTIL.NORM_NAME(qt.DRM_NAME), rc.RC_NAME) < 0.75)
        OR (qt.DRM_DOMAIN IS NOT NULL AND rc.RC_DOMAIN IS NOT NULL
            AND qt.DRM_DOMAIN != rc.RC_DOMAIN)
        OR (rc.RC_COMPANY_ID IS NOT NULL
            AND mb.MATCH_TIER = 4 AND mb.MATCH_SCORE < 0.90)
        OR (qt.DRM_LAUNCH_YEAR IS NOT NULL AND rc.RC_FOUNDING_YEAR IS NOT NULL
            AND ABS(qt.DRM_LAUNCH_YEAR - rc.RC_FOUNDING_YEAR) > 2)
        OR (qt.DRM_EMPLOYEES IS NOT NULL AND qt.DRM_EMPLOYEES > 0
            AND rc.RC_HEADCOUNT IS NOT NULL AND rc.RC_HEADCOUNT > 0
            AND GREATEST(qt.DRM_EMPLOYEES, rc.RC_HEADCOUNT)
                / LEAST(qt.DRM_EMPLOYEES, rc.RC_HEADCOUNT) > 5)
        OR COALESCE(qt.FLAG_NON_TECH_NAME_HIT, FALSE)
        OR COALESCE(qt.FLAG_SECTOR_GAMING, FALSE)
        OR COALESCE(qt.FLAG_SECTOR_PHARMA_BIOTECH, FALSE)
        OR COALESCE(qt.FLAG_SECTOR_SERVICES, FALSE)
        OR COALESCE(rc.RC_FLAG_SECTOR_GAMING, FALSE)
        OR COALESCE(rc.RC_FLAG_SECTOR_PHARMA_BIOTECH, FALSE)
        OR COALESCE(rc.RC_FLAG_SECTOR_SERVICES, FALSE),
        TRUE, FALSE)                                         AS FLAG_NEEDS_REVIEW,

    CURRENT_TIMESTAMP()                                      AS REGISTRY_BUILT_AT

-- ================================================================
-- FULL OUTER JOIN: QT left-joined to RC via 63D match bridge,
-- then UNION with RC-only (unmatched) companies.
-- ================================================================
FROM _QT_UNIVERSE qt
LEFT JOIN match_bridge mb
  ON qt.DEALROOM_ID::VARCHAR = mb.DEALROOM_ID
-- When the RC side of a match is blacklisted, dissolve the match:
-- the DR row falls through to QT_ONLY and the RC row is dropped
-- entirely (via the UNION's WHERE NOT blacklisted below).
LEFT JOIN _RC_UNIVERSE rc
  ON mb.RC_COMPANY_ID = rc.RC_COMPANY_ID
 AND NOT COALESCE(rc.RC_IS_STARTUP_BLACKLISTED, FALSE)

UNION ALL

-- RC-ONLY: Quebec RC companies not matched to any QT startup.
-- Blacklisted RC rows are excluded in the WHERE clause.
SELECT
    'RC_' || rc.RC_COMPANY_ID                                AS REGISTRY_ID,
    'RC_ONLY'                                                AS ENTITY_TYPE,

    -- Canonical
    rc.RC_NAME,
    rc.RC_CITY,
    rc.RC_FOUNDING_YEAR,
    rc.RC_DOMAIN,
    rc.RC_BROADER_SECTOR,

    -- QT fields: all NULL (19 columns)
    -- DEALROOM_ID, DRM_NAME, DRM_DOMAIN, DRM_TAGLINE, DRM_CITY, DRM_STATE,
    -- DRM_COUNTRY, DRM_LAUNCH_YEAR, DRM_EMPLOYEES, DRM_FUNDING_USD_M,
    -- DRM_COMPANY_STATUS, DRM_INDUSTRIES, DRM_RATING_RAW,
    -- RATING_LETTER_EFFECTIVE, QT_INCLUSION_REASON, DRM_STARTUP_STATUS,
    -- DRM_REGION, DRM_AGGLOMERATION, DRM_TOP_INDUSTRY
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL,
    CAST(NULL AS VARCHAR),                  -- RATING_LETTER_EFFECTIVE
    'RC_ONLY'::VARCHAR,                     -- QT_INCLUSION_REASON
    NULL, NULL, NULL, NULL,

    -- HS fields: all NULL
    NULL, NULL, NULL, NULL,
    -- REQ fields: all NULL
    NULL, NULL,

    -- RC fields
    rc.RC_COMPANY_ID,
    rc.RC_HARMONIC_ID,
    rc.RC_PB_ID,
    rc.RC_RECORD_TYPE,
    rc.RC_NAME,
    rc.RC_LEGAL_NAME,
    rc.RC_DOMAIN,
    rc.RC_LINKEDIN,
    rc.RC_CRUNCHBASE,
    rc.RC_CITY,
    rc.RC_STATE,
    rc.RC_FOUNDING_YEAR,
    rc.RC_HEADCOUNT,
    rc.RC_TOTAL_RAISED_CAD,
    rc.RC_REVENUE_CAD,
    rc.RC_FINANCING_STATUS,
    rc.RC_BUSINESS_STATUS,
    rc.RC_INDUSTRY_SECTOR,
    rc.RC_BROADER_SECTOR,
    rc.RC_LAST_FINANCING_DATE,
    rc.RC_LAST_FINANCING_CAD,
    rc.RC_LAST_FINANCING_TYPE,

    -- Match metadata: NULL for unmatched
    NULL, NULL, NULL,

    -- Coverage flags (HAS_DEALROOM, HAS_HUBSPOT, HAS_RC, HAS_REQ, N_SOURCES)
    FALSE, FALSE, TRUE, FALSE,
    1,

    -- Conflict flags: all FALSE for RC-only
    FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,

    -- Review state (RC-side)
    COALESCE(rc.RC_IS_STARTUP_WHITELISTED, FALSE),
    COALESCE(rc.RC_IS_STARTUP_BLACKLISTED, FALSE),

    -- Sector flags (RC-side)
    COALESCE(rc.RC_FLAG_SECTOR_GAMING, FALSE),
    COALESCE(rc.RC_FLAG_SECTOR_PHARMA_BIOTECH, FALSE),
    COALESCE(rc.RC_FLAG_SECTOR_SERVICES, FALSE),
    (COALESCE(rc.RC_FLAG_SECTOR_GAMING, FALSE)
     OR COALESCE(rc.RC_FLAG_SECTOR_PHARMA_BIOTECH, FALSE)
     OR COALESCE(rc.RC_FLAG_SECTOR_SERVICES, FALSE)),

    -- Non-tech name keyword hit: N/A for RC (no DR name)
    FALSE,

    -- FLAG_NEEDS_REVIEW: any sector flag raises it
    (COALESCE(rc.RC_FLAG_SECTOR_GAMING, FALSE)
     OR COALESCE(rc.RC_FLAG_SECTOR_PHARMA_BIOTECH, FALSE)
     OR COALESCE(rc.RC_FLAG_SECTOR_SERVICES, FALSE)),

    CURRENT_TIMESTAMP()

FROM _RC_UNIVERSE rc
WHERE rc.RC_COMPANY_ID NOT IN (
    -- Exclude RC rows matched either by 63D OR the manual whitelist.
    -- Without the UNION here, whitelisted RC rows would appear
    -- twice in the final registry (once as MATCHED, once as RC_ONLY).
    SELECT RC_ID FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
    UNION
    SELECT RC_COMPANY_ID FROM DEV_QUEBECTECH.REF.V_MATCH_WHITELIST
    WHERE DEALROOM_ID IS NOT NULL AND RC_COMPANY_ID IS NOT NULL
)
  AND NOT COALESCE(rc.RC_IS_STARTUP_BLACKLISTED, FALSE)
;

ALTER TABLE DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
  CLUSTER BY (ENTITY_TYPE, N_SOURCES, CANONICAL_CITY);


/* ============================================================
   VALIDATION
   ============================================================ */

-- Grand totals by entity type
SELECT
    ENTITY_TYPE,
    COUNT(*)                                                 AS N,
    SUM(IFF(HAS_DEALROOM, 1, 0))                             AS W_DRM,
    SUM(IFF(HAS_HUBSPOT, 1, 0))                              AS W_HS,
    SUM(IFF(HAS_RC, 1, 0))                                   AS W_RC,
    SUM(IFF(HAS_REQ, 1, 0))                                  AS W_REQ
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
GROUP BY ENTITY_TYPE
ORDER BY ENTITY_TYPE;

-- Source coverage matrix
SELECT
    N_SOURCES,
    ENTITY_TYPE,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
GROUP BY N_SOURCES, ENTITY_TYPE
ORDER BY N_SOURCES DESC, ENTITY_TYPE;

-- Dealroom RAW rating distribution (QT-anchored only)
SELECT
    DRM_RATING_RAW,
    COUNT(*) AS N,
    SUM(IFF(HAS_RC, 1, 0)) AS ALSO_IN_RC,
    SUM(IFF(HAS_REQ, 1, 0)) AS ALSO_HAS_NEQ,
    SUM(IFF(HAS_HUBSPOT, 1, 0)) AS ALSO_IN_HS
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE HAS_DEALROOM
GROUP BY DRM_RATING_RAW
ORDER BY DRM_RATING_RAW;

-- Effective rating (after C→B promotion and whitelist)
SELECT
    RATING_LETTER_EFFECTIVE,
    COUNT(*) AS N,
    SUM(IFF(HAS_RC, 1, 0)) AS ALSO_IN_RC
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE HAS_DEALROOM
GROUP BY RATING_LETTER_EFFECTIVE
ORDER BY RATING_LETTER_EFFECTIVE;

-- Inclusion reason breakdown (QT side)
SELECT
    QT_INCLUSION_REASON,
    COUNT(*) AS N,
    SUM(IFF(HAS_RC, 1, 0)) AS ALSO_IN_RC
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE ENTITY_TYPE IN ('MATCHED', 'QT_ONLY')
GROUP BY QT_INCLUSION_REASON
ORDER BY N DESC;

-- C-promotion impact: how many C rows are now in the registry as B
SELECT
    'C_PROMOTED' AS BUCKET, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE QT_INCLUSION_REASON = 'C_PROMOTED_RC_MATCH';

-- Sector flag counts
SELECT
    'GAMING'            AS SECTOR, SUM(IFF(FLAG_SECTOR_GAMING, 1, 0))           AS N FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
UNION ALL
SELECT 'PHARMA_BIOTECH', SUM(IFF(FLAG_SECTOR_PHARMA_BIOTECH, 1, 0)) FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
UNION ALL
SELECT 'SERVICES',       SUM(IFF(FLAG_SECTOR_SERVICES, 1, 0))       FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
UNION ALL
SELECT 'ANY_SECTOR',     SUM(IFF(FLAG_SECTOR_ANY, 1, 0))            FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
UNION ALL
SELECT 'NON_TECH_NAME',  SUM(IFF(FLAG_NON_TECH_NAME_HIT, 1, 0))     FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY;

-- Manual review state counts
SELECT
    SUM(IFF(IS_STARTUP_WHITELISTED, 1, 0)) AS N_WHITELISTED,
    SUM(IFF(IS_STARTUP_BLACKLISTED, 1, 0)) AS N_BLACKLISTED
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY;

-- RC-only: sector breakdown
SELECT
    RC_BROADER_SECTOR,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE ENTITY_TYPE = 'RC_ONLY'
  AND RC_BROADER_SECTOR IS NOT NULL
GROUP BY RC_BROADER_SECTOR
ORDER BY N DESC
LIMIT 20;

-- Conflict / exception summary
SELECT
    SUM(IFF(FLAG_NEEDS_REVIEW, 1, 0))                       AS TOTAL_NEEDS_REVIEW,
    SUM(IFF(FLAG_NAME_CONFLICT_QT_RC, 1, 0))                AS NAME_CONFLICTS,
    SUM(IFF(FLAG_DOMAIN_CONFLICT_QT_RC, 1, 0))              AS DOMAIN_CONFLICTS,
    SUM(IFF(FLAG_CITY_CONFLICT_QT_RC, 1, 0))                AS CITY_CONFLICTS,
    SUM(IFF(FLAG_YEAR_CONFLICT_QT_RC, 1, 0))                AS YEAR_CONFLICTS,
    SUM(IFF(FLAG_EMPLOYEE_CONFLICT_QT_RC, 1, 0))            AS EMPLOYEE_CONFLICTS,
    SUM(IFF(FLAG_LOW_CONFIDENCE_MATCH, 1, 0))                AS LOW_CONFIDENCE_MATCHES,
    SUM(IFF(FLAG_NAME_CONFLICT_QT_HS, 1, 0))                AS HS_NAME_CONFLICTS,
    COUNT(*)                                                 AS TOTAL_MATCHED
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE ENTITY_TYPE = 'MATCHED';

-- Top 20 flagged records for review
SELECT
    REGISTRY_ID,
    CANONICAL_NAME,
    DRM_NAME,
    RC_NAME,
    DRM_DOMAIN,
    RC_DOMAIN,
    DR_RC_MATCH_TIER,
    DR_RC_MATCH_SCORE,
    FLAG_NAME_CONFLICT_QT_RC,
    FLAG_DOMAIN_CONFLICT_QT_RC,
    FLAG_LOW_CONFIDENCE_MATCH
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE FLAG_NEEDS_REVIEW
ORDER BY DR_RC_MATCH_SCORE ASC NULLS LAST
LIMIT 20;

-- Compare with previous STARTUP_MASTER
SELECT
    'STARTUP_MASTER (old)' AS SOURCE, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_MASTER
UNION ALL
SELECT 'REGISTRY — total', COUNT(*)
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
UNION ALL
SELECT 'REGISTRY — MATCHED', COUNT(*)
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY WHERE ENTITY_TYPE = 'MATCHED'
UNION ALL
SELECT 'REGISTRY — QT_ONLY', COUNT(*)
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY WHERE ENTITY_TYPE = 'QT_ONLY'
UNION ALL
SELECT 'REGISTRY — RC_ONLY', COUNT(*)
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY WHERE ENTITY_TYPE = 'RC_ONLY';
