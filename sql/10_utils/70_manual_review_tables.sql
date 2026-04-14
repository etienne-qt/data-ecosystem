/* ============================================================
   70 -- MANUAL REVIEW INFRASTRUCTURE
   ============================================================
   Tables, views, and procedures supporting the human-in-the-loop
   review of (a) DR↔RC matches and (b) startup-vs-not-startup
   classification, including ambiguous-sector triage.

   Workflow (high level):

     1. Pipeline runs (63D, 80) flag ambiguous rows.
     2. Review queue VIEWS surface those rows by category.
     3. Operator EXPORTS each queue to CSV (Snowsight or COPY INTO).
     4. Operator triages in Google Sheets, marks DECISION column.
     5. Operator UPLOADS the marked CSV to an internal stage.
     6. MERGE proc upserts the new decisions into the canonical
        REF.MANUAL_REVIEW_DECISIONS table.
     7. Pipeline re-runs (63D, 80) consult REF.MANUAL_REVIEW_DECISIONS
        and apply the decisions.

   Decisions are append-only and timestamped — each row in the
   REF table is the latest decision per (entity, decision_type).

   Schemas:
     - REF      (canonical decisions, never overwritten)
     - UTIL     (review queue views, regenerated each run)
     - STAGE    (internal stage for uploaded CSVs)

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-09
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
CREATE SCHEMA IF NOT EXISTS REF;
CREATE SCHEMA IF NOT EXISTS UTIL;


/* ============================================================
   1. CANONICAL DECISIONS TABLE
   ============================================================
   One row per (DEALROOM_ID, RC_COMPANY_ID, DECISION_TYPE).
   The pair key supports both match decisions (both IDs set)
   and entity-level decisions (only one ID set).

   DECISION_TYPE:
     MATCH_CONFIRM     -- whitelist: force a DR↔RC pair to match
     MATCH_REJECT      -- blacklist: force a DR↔RC pair to NOT match
     STARTUP_CONFIRM   -- entity is a startup (DR-side or RC-side)
     STARTUP_REJECT    -- entity is NOT a startup
     SECTOR_REVIEWED   -- the ambiguous-sector flag has been adjudicated
                          (use DECISION_NOTE to record the call)

   DECISION_VALUE:
     'YES' | 'NO' | free-text for SECTOR_REVIEWED
   ============================================================ */

CREATE TABLE IF NOT EXISTS DEV_QUEBECTECH.REF.MANUAL_REVIEW_DECISIONS (
    -- Identity
    DEALROOM_ID         VARCHAR,
    RC_COMPANY_ID       VARCHAR,

    -- Decision
    DECISION_TYPE       VARCHAR NOT NULL,
    DECISION_VALUE      VARCHAR NOT NULL,
    DECISION_NOTE       VARCHAR,

    -- Provenance
    REVIEWED_BY         VARCHAR,
    REVIEWED_AT         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    REVIEW_BATCH        VARCHAR,        -- e.g. 'low_conf_matches_20260409'
    SOURCE_FILE         VARCHAR,        -- which uploaded CSV introduced this row

    -- Audit
    LOADED_AT           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Functional uniqueness: latest decision wins per (DR, RC, type).
-- Snowflake doesn't enforce, but we materialize a "current" view.
CREATE OR REPLACE VIEW DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT AS
SELECT *
FROM DEV_QUEBECTECH.REF.MANUAL_REVIEW_DECISIONS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY COALESCE(DEALROOM_ID, ''),
                 COALESCE(RC_COMPANY_ID, ''),
                 DECISION_TYPE
    ORDER BY REVIEWED_AT DESC, LOADED_AT DESC
) = 1;


/* ============================================================
   2. INTERNAL STAGE FOR UPLOADED CSVs
   ============================================================
   Operator uploads triaged review CSVs here via Snowsight or
   `snow stage copy`. Files are not deleted automatically — they
   serve as an audit trail.
   ============================================================ */

CREATE STAGE IF NOT EXISTS DEV_QUEBECTECH.REF.MANUAL_REVIEW_STAGE
    FILE_FORMAT = (TYPE = CSV
                   FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                   SKIP_HEADER = 1
                   NULL_IF = ('', 'NULL'));


/* ============================================================
   3. REVIEW QUEUE VIEWS
   ============================================================
   These are regenerated each pipeline run. They are what the
   operator EXPORTS for triage. Each view targets one decision
   class so the spreadsheet stays focused.
   ============================================================ */

/* -----------------------------------------------------------
   3a. Low-confidence DR↔RC matches (tier 4 NAME_SIM, score < 0.95)
       Operator confirms or rejects each pair.
   ----------------------------------------------------------- */
CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.V_REVIEW_QUEUE_MATCHES AS
SELECT
    e.DRM_ID                                      AS DEALROOM_ID,
    e.RC_ID                                       AS RC_COMPANY_ID,
    e.MATCH_TIER,
    e.MATCH_FIELD,
    ROUND(e.SCORE, 4)                             AS MATCH_SCORE,
    drm.NAME                                      AS DRM_NAME,
    drm.WEBSITE_DOMAIN                            AS DRM_DOMAIN,
    drm.HQ_CITY                                   AS DRM_CITY,
    cls.RATING_LETTER                             AS DRM_RATING,
    COALESCE(cm.H_COMPANY_NAME_NORM,
             cm.PB_COMPANY_NAME_NORM)             AS RC_NAME,
    COALESCE(cm.PB_WEBSITE_DOMAIN,
             cm.H_WEBSITE_DOMAIN)                 AS RC_DOMAIN,
    COALESCE(cm.H_CITY, cm.PB_HQ_CITY)            AS RC_CITY,
    -- Empty columns for the operator to fill in
    CAST(NULL AS VARCHAR)                         AS DECISION,   -- 'CONFIRM' or 'REJECT'
    CAST(NULL AS VARCHAR)                         AS NOTE,
    -- Skip rows already decided (this view is the QUEUE only)
    'low_conf_matches_' ||
        TO_VARCHAR(CURRENT_DATE(), 'YYYYMMDD')    AS REVIEW_BATCH
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP e
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm
  ON drm.DEALROOM_ID::VARCHAR = e.DRM_ID
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
  ON cls.DEALROOM_ID = drm.DEALROOM_ID
LEFT JOIN DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER cm
  ON COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR, cm.PB_COMPANY_ID::VARCHAR) = e.RC_ID
WHERE e.MATCH_TIER = 4
  AND e.SCORE < 0.95
  -- Exclude pairs we already decided
  AND NOT EXISTS (
      SELECT 1 FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT d
      WHERE d.DEALROOM_ID = e.DRM_ID
        AND d.RC_COMPANY_ID = e.RC_ID
        AND d.DECISION_TYPE IN ('MATCH_CONFIRM','MATCH_REJECT')
  );


/* -----------------------------------------------------------
   3b. Startup-status review queue
       DR-side rows where the rating disagrees with industry
       signals, plus RC-only rows in ambiguous sectors.
       This is where the QT whitelist gets built.
   ----------------------------------------------------------- */
CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.V_REVIEW_QUEUE_STARTUPS AS
-- DR-side: C-rated companies that match RC (candidates for C→B promotion)
SELECT
    drm.DEALROOM_ID::VARCHAR                      AS DEALROOM_ID,
    e.RC_ID                                       AS RC_COMPANY_ID,
    'C_PROMOTION_CANDIDATE'                       AS REVIEW_REASON,
    drm.NAME                                      AS ENTITY_NAME,
    drm.WEBSITE_DOMAIN                            AS DOMAIN,
    drm.HQ_CITY                                   AS CITY,
    'C'                                           AS CURRENT_RATING,
    ind.TOP_INDUSTRY                              AS INDUSTRY,
    CAST(NULL AS VARCHAR)                         AS DECISION,   -- 'YES' (is startup) or 'NO'
    CAST(NULL AS VARCHAR)                         AS NOTE,
    'startup_status_' ||
        TO_VARCHAR(CURRENT_DATE(), 'YYYYMMDD')    AS REVIEW_BATCH
FROM DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm
JOIN DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
  ON cls.DEALROOM_ID = drm.DEALROOM_ID
 AND cls.RATING_LETTER = 'C'
JOIN DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP e
  ON e.DRM_ID = drm.DEALROOM_ID::VARCHAR
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_INDUSTRY_SIGNALS_SILVER ind
  ON ind.DEALROOM_ID = drm.DEALROOM_ID
WHERE NOT EXISTS (
    SELECT 1 FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT d
    WHERE d.DEALROOM_ID = drm.DEALROOM_ID::VARCHAR
      AND d.DECISION_TYPE IN ('STARTUP_CONFIRM','STARTUP_REJECT')
)

UNION ALL

-- RC-only: rows in ambiguous sectors (gaming, pharma, biotech, services)
SELECT
    CAST(NULL AS VARCHAR)                         AS DEALROOM_ID,
    COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
             cm.PB_COMPANY_ID::VARCHAR)           AS RC_COMPANY_ID,
    'AMBIGUOUS_SECTOR'                            AS REVIEW_REASON,
    COALESCE(cm.H_COMPANY_NAME_NORM,
             cm.PB_COMPANY_NAME_NORM)             AS ENTITY_NAME,
    COALESCE(cm.PB_WEBSITE_DOMAIN,
             cm.H_WEBSITE_DOMAIN)                 AS DOMAIN,
    COALESCE(cm.H_CITY, cm.PB_HQ_CITY)            AS CITY,
    NULL                                          AS CURRENT_RATING,
    pb.INDUSTRY_SECTOR                            AS INDUSTRY,
    NULL                                          AS DECISION,
    NULL                                          AS NOTE,
    'startup_status_' ||
        TO_VARCHAR(CURRENT_DATE(), 'YYYYMMDD')    AS REVIEW_BATCH
FROM DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER cm
LEFT JOIN DEV_RESEAUCAPITAL.SILVER.PITCHBOOK_ACQ_COMPANIES pb
  ON cm.PB_COMPANY_ID = pb.PB_COMPANY_ID
WHERE (LOWER(COALESCE(cm.H_STATE, cm.PB_HQ_STATE_PROVINCE, '')) IN
        ('quebec','québec','qc','que'))
  AND LOWER(COALESCE(pb.INDUSTRY_SECTOR, '')) RLIKE
        '.*(gaming|game|pharma|biotech|drug|consult|service|agency).*'
  AND NOT EXISTS (
      SELECT 1 FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT d
      WHERE d.RC_COMPANY_ID = COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
                                        cm.PB_COMPANY_ID::VARCHAR)
        AND d.DECISION_TYPE IN ('STARTUP_CONFIRM','STARTUP_REJECT')
  );


/* ============================================================
   4. UPLOAD MERGE PROC
   ============================================================
   After uploading a triaged CSV to the stage, run this proc to
   merge it into REF.MANUAL_REVIEW_DECISIONS.

   Expected CSV columns (header row required):
     DEALROOM_ID, RC_COMPANY_ID, DECISION_TYPE, DECISION_VALUE,
     DECISION_NOTE, REVIEWED_BY, REVIEW_BATCH

   Usage:
     CALL DEV_QUEBECTECH.REF.MERGE_REVIEW_UPLOAD('manual_review_20260409.csv');
   ============================================================ */

CREATE OR REPLACE PROCEDURE DEV_QUEBECTECH.REF.MERGE_REVIEW_UPLOAD(filename VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    rows_loaded INTEGER;
    load_sql    VARCHAR;
BEGIN
    -- Stage already has FILE_FORMAT bound at creation time, so the
    -- SELECT below does not re-specify it. We must EXECUTE IMMEDIATE
    -- because Snowflake stage paths cannot be parameterized directly
    -- (no IDENTIFIER() on @stage/path). Filename is concatenated.
    load_sql := 'CREATE OR REPLACE TEMPORARY TABLE _REVIEW_UPLOAD AS ' ||
                'SELECT ' ||
                '    $1::VARCHAR AS DEALROOM_ID, ' ||
                '    $2::VARCHAR AS RC_COMPANY_ID, ' ||
                '    $3::VARCHAR AS DECISION_TYPE, ' ||
                '    $4::VARCHAR AS DECISION_VALUE, ' ||
                '    $5::VARCHAR AS DECISION_NOTE, ' ||
                '    $6::VARCHAR AS REVIEWED_BY, ' ||
                '    $7::VARCHAR AS REVIEW_BATCH ' ||
                'FROM @DEV_QUEBECTECH.REF.MANUAL_REVIEW_STAGE/' || :filename;
    EXECUTE IMMEDIATE :load_sql;

    -- Append-only insert (history preserved)
    INSERT INTO DEV_QUEBECTECH.REF.MANUAL_REVIEW_DECISIONS
        (DEALROOM_ID, RC_COMPANY_ID, DECISION_TYPE, DECISION_VALUE,
         DECISION_NOTE, REVIEWED_BY, REVIEW_BATCH, SOURCE_FILE)
    SELECT
        NULLIF(TRIM(DEALROOM_ID), ''),
        NULLIF(TRIM(RC_COMPANY_ID), ''),
        UPPER(TRIM(DECISION_TYPE)),
        UPPER(TRIM(DECISION_VALUE)),
        DECISION_NOTE,
        REVIEWED_BY,
        REVIEW_BATCH,
        :filename
    FROM _REVIEW_UPLOAD
    WHERE DECISION_TYPE IS NOT NULL
      AND DECISION_VALUE IS NOT NULL
      AND (DEALROOM_ID IS NOT NULL OR RC_COMPANY_ID IS NOT NULL);

    rows_loaded := SQLROWCOUNT;
    RETURN 'Loaded ' || rows_loaded || ' decisions from ' || :filename;
END;
$$;


/* ============================================================
   5. CONVENIENCE VIEWS FOR THE PIPELINE TO CONSULT
   ============================================================
   The 63D and 80 SQL files JOIN against these views to apply
   manual decisions without scanning the full history table.
   ============================================================ */

-- Confirmed matches (whitelist) — force these into the registry
CREATE OR REPLACE VIEW DEV_QUEBECTECH.REF.V_MATCH_WHITELIST AS
SELECT DEALROOM_ID, RC_COMPANY_ID, REVIEWED_BY, REVIEWED_AT
FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT
WHERE DECISION_TYPE = 'MATCH_CONFIRM'
  AND DECISION_VALUE = 'YES'
  AND DEALROOM_ID IS NOT NULL
  AND RC_COMPANY_ID IS NOT NULL;

-- Rejected matches (blacklist) — drop these even if 63D found them
CREATE OR REPLACE VIEW DEV_QUEBECTECH.REF.V_MATCH_BLACKLIST AS
SELECT DEALROOM_ID, RC_COMPANY_ID, REVIEWED_BY, REVIEWED_AT
FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT
WHERE DECISION_TYPE = 'MATCH_REJECT'
  AND DECISION_VALUE = 'YES'
  AND DEALROOM_ID IS NOT NULL
  AND RC_COMPANY_ID IS NOT NULL;

-- QT startup whitelist (confirmed startups)
CREATE OR REPLACE VIEW DEV_QUEBECTECH.REF.V_STARTUP_WHITELIST AS
SELECT DEALROOM_ID, RC_COMPANY_ID, DECISION_NOTE, REVIEWED_BY, REVIEWED_AT
FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT
WHERE DECISION_TYPE = 'STARTUP_CONFIRM'
  AND DECISION_VALUE = 'YES';

-- QT startup blacklist (confirmed NOT startups)
CREATE OR REPLACE VIEW DEV_QUEBECTECH.REF.V_STARTUP_BLACKLIST AS
SELECT DEALROOM_ID, RC_COMPANY_ID, DECISION_NOTE, REVIEWED_BY, REVIEWED_AT
FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT
WHERE DECISION_TYPE = 'STARTUP_REJECT'
  AND DECISION_VALUE = 'YES';
