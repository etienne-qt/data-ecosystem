/* ============================================================
   Q6 — MANUAL REVIEW AUDIT
   ============================================================
   Audits the manual blacklist and whitelist in
   REF.V_STARTUP_BLACKLIST / REF.V_STARTUP_WHITELIST against the
   automated signals already joined onto GOLD.STARTUP_REGISTRY.
   The goal is to surface:

     (a) Blacklist entries that SHOULD probably be startups
         (strong Dealroom rating, real funding, RC VC match, or
         a blacklist note mentioning a non-valid reason such as
         "old / closed / acquired" — those states do NOT disqualify
         a company from counting as a startup).

     (b) Whitelist entries with no supporting automated signals
         (no Dealroom rating, no funding, no RC match, and optionally
         a non-tech name hit).

   Per Étienne's directive (2026-04-21):
     - Old, mature, closed, acquired, or dissolved companies are
       still counted as startups. A blacklist reason based on those
       states is an invalid exclusion.
     - Any blacklist entry that could plausibly be a startup should
       be promoted to the FOR_REVIEW queue so a human re-triages it.
     - Any whitelist entry with no supporting automated signals
       should be flagged for re-review.

   This script does NOT write. It produces result grids to save as
   CSV and hand to the manual review operator. The operator adds
   new STARTUP_CONFIRM / STARTUP_REJECT decisions via the existing
   upload path (REF.MERGE_REVIEW_UPLOAD); because decisions are
   append-only, the newest row overrides the previous call in
   V_MANUAL_REVIEW_CURRENT.

   Upstream dependency: GOLD.STARTUP_REGISTRY must be freshly built
   via pipelines/transforms/registry/80_consolidated_startup_registry.sql
   so IS_STARTUP_WHITELISTED / IS_STARTUP_BLACKLISTED / DRM_RATING_RAW
   / DRM_FUNDING_USD_M / HAS_RC_MATCH_* / DRM_COMPANY_STATUS are current.

   Signal reference (all columns already in GOLD.STARTUP_REGISTRY):
     - DRM_RATING_RAW           'A+' | 'A' | 'B' | 'C' | 'D' | NULL
     - DRM_FUNDING_USD_M        numeric, millions USD, Dealroom
     - CANONICAL_FOUNDING_YEAR  COALESCE(DRM, RC)
     - DRM_COMPANY_STATUS       'operational' | 'acquired' | 'closed' | 'low-activity'
     - RC_BUSINESS_STATUS       free-text, RC side
     - FLAG_NON_TECH_NAME_HIT   boolean
     - ENTITY_TYPE              'MATCHED' | 'QT_ONLY' | 'RC_ONLY'
     - WHITELIST_NOTE / BLACKLIST_NOTE / RC_WHITELIST_NOTE / RC_BLACKLIST_NOTE

   Author: AI Agent (Quebec Tech Data & Analytics)
   Date:   2026-04-21
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;


/* ============================================================
   SECTION 0 — PRECONDITION: registry is fresh and populated
   ============================================================ */

SELECT
    'GOLD.STARTUP_REGISTRY'                   AS tbl,
    COUNT(*)                                  AS n_rows,
    SUM(IFF(IS_STARTUP_WHITELISTED, 1, 0))    AS n_whitelisted,
    SUM(IFF(IS_STARTUP_BLACKLISTED, 1, 0))    AS n_blacklisted,
    MAX(REGISTRY_BUILT_AT)                    AS last_build
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY;


/* ============================================================
   SECTION 1 — BLACKLIST AUDIT: HEADLINE COUNTS BY CONFLICT TYPE
   ============================================================
   A single company can hit multiple conflict flags; counts are
   NOT mutually exclusive.
   ============================================================ */

WITH bl AS (
    SELECT
        REGISTRY_KEY,
        CANONICAL_NAME,
        ENTITY_TYPE,
        DRM_RATING_RAW,
        DRM_FUNDING_USD_M,
        DRM_COMPANY_STATUS,
        RC_BUSINESS_STATUS,
        CANONICAL_FOUNDING_YEAR,
        FLAG_NON_TECH_NAME_HIT,
        COALESCE(BLACKLIST_NOTE, RC_BLACKLIST_NOTE) AS BL_NOTE,
        -- Signal flags
        IFF(DRM_RATING_RAW IN ('A+','A','B'), TRUE, FALSE)        AS SIG_STRONG_RATING,
        IFF(COALESCE(DRM_FUNDING_USD_M, 0) >= 1, TRUE, FALSE)     AS SIG_FUNDING_1M,
        IFF(ENTITY_TYPE IN ('MATCHED','RC_ONLY'), TRUE, FALSE)    AS SIG_RC_MATCH,
        IFF(DRM_COMPANY_STATUS IN ('acquired','closed','low-activity')
            OR LOWER(COALESCE(RC_BUSINESS_STATUS,'')) RLIKE '.*(acquir|closed|dissolv|inactive|defunct).*',
            TRUE, FALSE)                                          AS STATE_MATURE_OR_CLOSED,
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              RLIKE '.*(old|mature|closed|acquir|dissolv|inactive|defunct|stopped|ceased).*',
            TRUE, FALSE)                                          AS NOTE_INVALID_REASON
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE IS_STARTUP_BLACKLISTED
)
SELECT
    'TOTAL_BLACKLISTED'                              AS flag,
    COUNT(*)                                         AS n
FROM bl
UNION ALL
SELECT 'BLACKLIST_STRONG_RATING_CONFLICT',
       COUNT(*) FROM bl WHERE SIG_STRONG_RATING
UNION ALL
SELECT 'BLACKLIST_FUNDING_CONFLICT',
       COUNT(*) FROM bl WHERE SIG_FUNDING_1M
UNION ALL
SELECT 'BLACKLIST_RC_MATCH_CONFLICT',
       COUNT(*) FROM bl WHERE SIG_RC_MATCH
UNION ALL
SELECT 'BLACKLIST_INVALID_REASON_NOTE (old/closed/acquired/dissolved — not a disqualifier)',
       COUNT(*) FROM bl WHERE NOTE_INVALID_REASON
UNION ALL
SELECT 'BLACKLIST_MATURE_OR_CLOSED_WITH_PAST_STARTUP_SIGNALS',
       COUNT(*) FROM bl WHERE STATE_MATURE_OR_CLOSED AND (SIG_STRONG_RATING OR SIG_FUNDING_1M OR SIG_RC_MATCH)
UNION ALL
SELECT 'BLACKLIST_ANY_CONFLICT (union of above)',
       COUNT(*) FROM bl
       WHERE SIG_STRONG_RATING OR SIG_FUNDING_1M OR SIG_RC_MATCH OR NOTE_INVALID_REASON
ORDER BY n DESC;


/* ============================================================
   SECTION 2 — BLACKLIST CONFLICTS: DETAIL LIST
   ============================================================
   Every blacklisted entry with at least one of:
     - Dealroom rating A+/A/B
     - Funding ≥ $1M USD
     - Matched in RC (has VC/PE deal data from Harmonic/PitchBook)
     - Blacklist note mentions an invalid reason (old/closed/etc.)

   Ordered by conflict severity so reviewers attack the worst first.
   Save as CSV; this is the first re-review batch.
   ============================================================ */

WITH bl AS (
    SELECT
        REGISTRY_KEY,
        CANONICAL_NAME,
        CANONICAL_WEBSITE_DOMAIN,
        CANONICAL_FOUNDING_YEAR,
        ENTITY_TYPE,
        DRM_RATING_RAW,
        DRM_FUNDING_USD_M,
        DRM_COMPANY_STATUS,
        RC_BUSINESS_STATUS,
        DRM_TOP_INDUSTRY,
        COALESCE(DEALROOM_ID, '')                AS DEALROOM_ID,
        COALESCE(RC_COMPANY_ID, '')              AS RC_COMPANY_ID,
        COALESCE(BLACKLIST_NOTE,
                 RC_BLACKLIST_NOTE)              AS BL_NOTE,
        IFF(DRM_RATING_RAW IN ('A+','A','B'), TRUE, FALSE)                               AS SIG_STRONG_RATING,
        IFF(COALESCE(DRM_FUNDING_USD_M, 0) >= 1, TRUE, FALSE)                            AS SIG_FUNDING_1M,
        IFF(ENTITY_TYPE IN ('MATCHED','RC_ONLY'), TRUE, FALSE)                           AS SIG_RC_MATCH,
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              RLIKE '.*(old|mature|closed|acquir|dissolv|inactive|defunct|stopped|ceased).*',
            TRUE, FALSE)                                                                 AS NOTE_INVALID_REASON
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE IS_STARTUP_BLACKLISTED
)
SELECT
    -- Priority 1 = strong rating; 2 = funding or RC match; 3 = invalid-reason note only.
    CASE
        WHEN SIG_STRONG_RATING                                        THEN 1
        WHEN SIG_FUNDING_1M OR SIG_RC_MATCH                           THEN 2
        WHEN NOTE_INVALID_REASON                                      THEN 3
        ELSE 4
    END                                                               AS conflict_priority,
    -- Short label for the reviewer spreadsheet.
    ARRAY_TO_STRING(ARRAY_COMPACT(ARRAY_CONSTRUCT(
        IFF(SIG_STRONG_RATING, 'STRONG_RATING(' || DRM_RATING_RAW || ')', NULL),
        IFF(SIG_FUNDING_1M, 'FUNDING($' || TO_VARCHAR(ROUND(DRM_FUNDING_USD_M,1)) || 'M)', NULL),
        IFF(SIG_RC_MATCH, 'RC_MATCH', NULL),
        IFF(NOTE_INVALID_REASON, 'INVALID_REASON_NOTE', NULL)
    )), ' · ')                                                        AS conflict_flags,
    REGISTRY_KEY,
    CANONICAL_NAME,
    CANONICAL_WEBSITE_DOMAIN,
    CANONICAL_FOUNDING_YEAR,
    ENTITY_TYPE,
    DRM_RATING_RAW,
    DRM_FUNDING_USD_M,
    DRM_COMPANY_STATUS,
    RC_BUSINESS_STATUS,
    DRM_TOP_INDUSTRY,
    DEALROOM_ID,
    RC_COMPANY_ID,
    BL_NOTE,
    -- Proposed action for the operator spreadsheet.
    'PROMOTE_TO_FOR_REVIEW'                                           AS proposed_action,
    'RECLASSIFY_BLACKLIST_' ||
        CASE
            WHEN SIG_STRONG_RATING       THEN 'STRONG_RATING'
            WHEN SIG_FUNDING_1M          THEN 'FUNDING'
            WHEN SIG_RC_MATCH            THEN 'RC_MATCH'
            WHEN NOTE_INVALID_REASON     THEN 'INVALID_REASON'
            ELSE 'OTHER'
        END                                                           AS proposed_review_label
FROM bl
WHERE SIG_STRONG_RATING
   OR SIG_FUNDING_1M
   OR SIG_RC_MATCH
   OR NOTE_INVALID_REASON
ORDER BY conflict_priority, DRM_FUNDING_USD_M DESC NULLS LAST, DRM_RATING_RAW;


/* ============================================================
   SECTION 3 — WHITELIST AUDIT: HEADLINE COUNTS BY SIGNAL GAP
   ============================================================ */

WITH wl AS (
    SELECT
        REGISTRY_KEY,
        DRM_RATING_RAW,
        DRM_FUNDING_USD_M,
        ENTITY_TYPE,
        FLAG_NON_TECH_NAME_HIT,
        CANONICAL_FOUNDING_YEAR,
        IFF(DRM_RATING_RAW IS NULL OR DRM_RATING_RAW NOT IN ('A+','A','B'), TRUE, FALSE) AS GAP_NO_STRONG_RATING,
        IFF(COALESCE(DRM_FUNDING_USD_M, 0) < 0.5, TRUE, FALSE)                           AS GAP_NO_MEANINGFUL_FUNDING,
        IFF(ENTITY_TYPE = 'QT_ONLY', TRUE, FALSE)                                        AS GAP_NO_RC_MATCH,
        IFF(CANONICAL_FOUNDING_YEAR < 1990 OR CANONICAL_FOUNDING_YEAR IS NULL, TRUE, FALSE) AS GAP_OLD_OR_UNKNOWN_YEAR
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE IS_STARTUP_WHITELISTED
)
SELECT
    'TOTAL_WHITELISTED'                              AS flag,
    COUNT(*)                                         AS n
FROM wl
UNION ALL
SELECT 'WHITELIST_NO_STRONG_RATING',
       COUNT(*) FROM wl WHERE GAP_NO_STRONG_RATING
UNION ALL
SELECT 'WHITELIST_NO_MEANINGFUL_FUNDING',
       COUNT(*) FROM wl WHERE GAP_NO_MEANINGFUL_FUNDING
UNION ALL
SELECT 'WHITELIST_NO_RC_MATCH',
       COUNT(*) FROM wl WHERE GAP_NO_RC_MATCH
UNION ALL
SELECT 'WHITELIST_NON_TECH_NAME',
       COUNT(*) FROM wl WHERE FLAG_NON_TECH_NAME_HIT
UNION ALL
SELECT 'WHITELIST_ALL_SIGNALS_MISSING (no rating AND no funding AND no RC match)',
       COUNT(*) FROM wl WHERE GAP_NO_STRONG_RATING AND GAP_NO_MEANINGFUL_FUNDING AND GAP_NO_RC_MATCH
ORDER BY n DESC;


/* ============================================================
   SECTION 4 — WHITELIST WITH NO SUPPORTING SIGNALS: DETAIL
   ============================================================
   Whitelist entries where ALL of the following are true:
     - No strong Dealroom rating
     - No meaningful funding
     - No RC match

   Optionally also: FLAG_NON_TECH_NAME_HIT (name looks non-tech).

   These are the weakest whitelist calls — most likely to be
   "I wasn't sure, so I said yes" decisions that deserve a second look.
   ============================================================ */

WITH wl AS (
    SELECT
        REGISTRY_KEY,
        CANONICAL_NAME,
        CANONICAL_WEBSITE_DOMAIN,
        CANONICAL_FOUNDING_YEAR,
        ENTITY_TYPE,
        DRM_RATING_RAW,
        DRM_FUNDING_USD_M,
        DRM_COMPANY_STATUS,
        DRM_TOP_INDUSTRY,
        FLAG_NON_TECH_NAME_HIT,
        COALESCE(DEALROOM_ID, '')                AS DEALROOM_ID,
        COALESCE(RC_COMPANY_ID, '')              AS RC_COMPANY_ID,
        COALESCE(WHITELIST_NOTE,
                 RC_WHITELIST_NOTE)              AS WL_NOTE,
        IFF(DRM_RATING_RAW IS NULL OR DRM_RATING_RAW NOT IN ('A+','A','B'), TRUE, FALSE) AS GAP_NO_STRONG_RATING,
        IFF(COALESCE(DRM_FUNDING_USD_M, 0) < 0.5, TRUE, FALSE)                           AS GAP_NO_MEANINGFUL_FUNDING,
        IFF(ENTITY_TYPE = 'QT_ONLY', TRUE, FALSE)                                        AS GAP_NO_RC_MATCH
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE IS_STARTUP_WHITELISTED
)
SELECT
    CASE
        WHEN GAP_NO_STRONG_RATING AND GAP_NO_MEANINGFUL_FUNDING AND GAP_NO_RC_MATCH
             AND FLAG_NON_TECH_NAME_HIT                                     THEN 1  -- worst
        WHEN GAP_NO_STRONG_RATING AND GAP_NO_MEANINGFUL_FUNDING AND GAP_NO_RC_MATCH THEN 2
        WHEN FLAG_NON_TECH_NAME_HIT                                         THEN 3
        ELSE 4
    END                                                                    AS signal_gap_priority,
    ARRAY_TO_STRING(ARRAY_COMPACT(ARRAY_CONSTRUCT(
        IFF(GAP_NO_STRONG_RATING, 'NO_STRONG_RATING', NULL),
        IFF(GAP_NO_MEANINGFUL_FUNDING, 'NO_MEANINGFUL_FUNDING', NULL),
        IFF(GAP_NO_RC_MATCH, 'NO_RC_MATCH', NULL),
        IFF(FLAG_NON_TECH_NAME_HIT, 'NON_TECH_NAME_HIT', NULL)
    )), ' · ')                                                             AS signal_gaps,
    REGISTRY_KEY,
    CANONICAL_NAME,
    CANONICAL_WEBSITE_DOMAIN,
    CANONICAL_FOUNDING_YEAR,
    ENTITY_TYPE,
    DRM_RATING_RAW,
    DRM_FUNDING_USD_M,
    DRM_COMPANY_STATUS,
    DRM_TOP_INDUSTRY,
    DEALROOM_ID,
    RC_COMPANY_ID,
    WL_NOTE,
    'PROMOTE_TO_FOR_REVIEW'                                                AS proposed_action,
    'RECLASSIFY_WHITELIST_NO_SUPPORTING_SIGNALS'                           AS proposed_review_label
FROM wl
WHERE (GAP_NO_STRONG_RATING AND GAP_NO_MEANINGFUL_FUNDING AND GAP_NO_RC_MATCH)
   OR FLAG_NON_TECH_NAME_HIT
ORDER BY signal_gap_priority, DRM_FUNDING_USD_M ASC NULLS FIRST, CANONICAL_NAME;


/* ============================================================
   SECTION 5 — OLD / MATURE / CLOSED BLACKLIST ENTRIES
   ============================================================
   Per the directive: an old, mature, or closed startup is STILL
   a startup. We want to surface every blacklist entry whose state
   or note suggests it was disqualified for that reason.

   Separate from section 2 so it's visible even when there's no
   other signal — the "reason invalid per policy" alone justifies
   a re-review.
   ============================================================ */

SELECT
    REGISTRY_KEY,
    CANONICAL_NAME,
    CANONICAL_WEBSITE_DOMAIN,
    CANONICAL_FOUNDING_YEAR,
    ENTITY_TYPE,
    DRM_RATING_RAW,
    DRM_FUNDING_USD_M,
    DRM_COMPANY_STATUS,
    RC_BUSINESS_STATUS,
    DRM_TOP_INDUSTRY,
    COALESCE(DEALROOM_ID, '')                AS DEALROOM_ID,
    COALESCE(RC_COMPANY_ID, '')              AS RC_COMPANY_ID,
    COALESCE(BLACKLIST_NOTE, RC_BLACKLIST_NOTE) AS BL_NOTE,
    -- Which invalid-reason tokens appeared?
    ARRAY_TO_STRING(ARRAY_COMPACT(ARRAY_CONSTRUCT(
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              LIKE '%old%', 'old', NULL),
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              LIKE '%mature%', 'mature', NULL),
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              LIKE '%closed%', 'closed', NULL),
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              LIKE '%acquir%', 'acquired', NULL),
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              LIKE '%dissolv%', 'dissolved', NULL),
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              LIKE '%inactive%', 'inactive', NULL),
        IFF(DRM_COMPANY_STATUS IN ('acquired','closed','low-activity'), 'state=' || DRM_COMPANY_STATUS, NULL)
    )), ', ')                                                               AS invalid_reason_tokens,
    'PROMOTE_TO_FOR_REVIEW'                                                 AS proposed_action,
    'RECLASSIFY_BLACKLIST_MATURITY_OR_STATE_NOT_A_DISQUALIFIER'             AS proposed_review_label
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE IS_STARTUP_BLACKLISTED
  AND (
    LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
      RLIKE '.*(old|mature|closed|acquir|dissolv|inactive|defunct|stopped|ceased).*'
    OR DRM_COMPANY_STATUS IN ('acquired','closed','low-activity')
  )
ORDER BY CANONICAL_FOUNDING_YEAR NULLS LAST, DRM_FUNDING_USD_M DESC NULLS LAST;


/* ============================================================
   SECTION 6 — UNIFIED RE-REVIEW QUEUE (TOP 200)
   ============================================================
   Merges sections 2, 4, and 5 into one priority-sorted queue.
   This is the CSV to export and hand to the reviewer:

     1. Export as re_review_queue_YYYYMMDD.csv
     2. Operator adds a DECISION column in Google Sheets
        (YES = is startup / NO = not a startup) and fills DECISION_NOTE
     3. Upload via REF.MERGE_REVIEW_UPLOAD — new row overrides the old
        decision via V_MANUAL_REVIEW_CURRENT
     4. Rerun pipelines/transforms/registry/80_... to apply decisions

   Priorities (lower = more urgent):
     1. Blacklist with STRONG_RATING (A+/A/B)
     2. Whitelist missing all signals AND non-tech name (worst false positive)
     3. Blacklist with FUNDING or RC_MATCH conflict
     4. Blacklist with INVALID_REASON_NOTE (old/closed/etc.)
     5. Whitelist missing all 3 signal types
     6. Whitelist non-tech name (signal present)
   ============================================================ */

WITH blk AS (
    SELECT
        REGISTRY_KEY, CANONICAL_NAME, CANONICAL_WEBSITE_DOMAIN,
        CANONICAL_FOUNDING_YEAR, ENTITY_TYPE, DRM_RATING_RAW,
        DRM_FUNDING_USD_M, DRM_COMPANY_STATUS, DRM_TOP_INDUSTRY,
        COALESCE(DEALROOM_ID, '')      AS DEALROOM_ID,
        COALESCE(RC_COMPANY_ID, '')    AS RC_COMPANY_ID,
        COALESCE(BLACKLIST_NOTE, RC_BLACKLIST_NOTE) AS CURRENT_NOTE,
        'BLACKLIST'                    AS CURRENT_LIST,
        IFF(DRM_RATING_RAW IN ('A+','A','B'), TRUE, FALSE)                               AS b_strong_rating,
        IFF(COALESCE(DRM_FUNDING_USD_M, 0) >= 1, TRUE, FALSE)                            AS b_funding,
        IFF(ENTITY_TYPE IN ('MATCHED','RC_ONLY'), TRUE, FALSE)                           AS b_rc_match,
        IFF(LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
              RLIKE '.*(old|mature|closed|acquir|dissolv|inactive|defunct|stopped|ceased).*',
            TRUE, FALSE)                                                                 AS b_invalid_note,
        FALSE AS w_non_tech,
        FALSE AS w_all_missing
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE IS_STARTUP_BLACKLISTED
),
wht AS (
    SELECT
        REGISTRY_KEY, CANONICAL_NAME, CANONICAL_WEBSITE_DOMAIN,
        CANONICAL_FOUNDING_YEAR, ENTITY_TYPE, DRM_RATING_RAW,
        DRM_FUNDING_USD_M, DRM_COMPANY_STATUS, DRM_TOP_INDUSTRY,
        COALESCE(DEALROOM_ID, '')      AS DEALROOM_ID,
        COALESCE(RC_COMPANY_ID, '')    AS RC_COMPANY_ID,
        COALESCE(WHITELIST_NOTE, RC_WHITELIST_NOTE) AS CURRENT_NOTE,
        'WHITELIST'                    AS CURRENT_LIST,
        FALSE AS b_strong_rating,
        FALSE AS b_funding,
        FALSE AS b_rc_match,
        FALSE AS b_invalid_note,
        COALESCE(FLAG_NON_TECH_NAME_HIT, FALSE)                                          AS w_non_tech,
        (IFF(DRM_RATING_RAW IS NULL OR DRM_RATING_RAW NOT IN ('A+','A','B'), TRUE, FALSE)
         AND IFF(COALESCE(DRM_FUNDING_USD_M, 0) < 0.5, TRUE, FALSE)
         AND IFF(ENTITY_TYPE = 'QT_ONLY', TRUE, FALSE))                                  AS w_all_missing
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE IS_STARTUP_WHITELISTED
),
unioned AS (
    SELECT * FROM blk
    WHERE b_strong_rating OR b_funding OR b_rc_match OR b_invalid_note
    UNION ALL
    SELECT * FROM wht
    WHERE w_all_missing OR w_non_tech
)
SELECT
    CASE
        WHEN CURRENT_LIST = 'BLACKLIST' AND b_strong_rating                THEN 1
        WHEN CURRENT_LIST = 'WHITELIST' AND w_all_missing AND w_non_tech   THEN 2
        WHEN CURRENT_LIST = 'BLACKLIST' AND (b_funding OR b_rc_match)      THEN 3
        WHEN CURRENT_LIST = 'BLACKLIST' AND b_invalid_note                 THEN 4
        WHEN CURRENT_LIST = 'WHITELIST' AND w_all_missing                  THEN 5
        WHEN CURRENT_LIST = 'WHITELIST' AND w_non_tech                     THEN 6
        ELSE 9
    END                                                                   AS priority,
    CURRENT_LIST,
    -- Concise label for spreadsheet triage
    CASE
        WHEN CURRENT_LIST = 'BLACKLIST' AND b_strong_rating                THEN 'BL_STRONG_RATING'
        WHEN CURRENT_LIST = 'BLACKLIST' AND b_funding                      THEN 'BL_FUNDING'
        WHEN CURRENT_LIST = 'BLACKLIST' AND b_rc_match                     THEN 'BL_RC_MATCH'
        WHEN CURRENT_LIST = 'BLACKLIST' AND b_invalid_note                 THEN 'BL_INVALID_REASON'
        WHEN CURRENT_LIST = 'WHITELIST' AND w_all_missing AND w_non_tech   THEN 'WL_NO_SIGNALS_AND_NON_TECH'
        WHEN CURRENT_LIST = 'WHITELIST' AND w_all_missing                  THEN 'WL_NO_SIGNALS'
        WHEN CURRENT_LIST = 'WHITELIST' AND w_non_tech                     THEN 'WL_NON_TECH_NAME'
        ELSE 'OTHER'
    END                                                                   AS conflict_label,
    REGISTRY_KEY,
    CANONICAL_NAME,
    CANONICAL_WEBSITE_DOMAIN,
    CANONICAL_FOUNDING_YEAR,
    ENTITY_TYPE,
    DRM_RATING_RAW,
    DRM_FUNDING_USD_M,
    DRM_COMPANY_STATUS,
    DRM_TOP_INDUSTRY,
    DEALROOM_ID,
    RC_COMPANY_ID,
    CURRENT_NOTE,
    -- Columns for the operator spreadsheet to fill in:
    CAST(NULL AS VARCHAR)                                                 AS NEW_DECISION_VALUE,   -- 'YES' or 'NO'
    CAST(NULL AS VARCHAR)                                                 AS NEW_DECISION_NOTE,
    'manual_review_audit_' ||
        TO_VARCHAR(CURRENT_DATE(), 'YYYYMMDD')                            AS REVIEW_BATCH
FROM unioned
ORDER BY priority, CANONICAL_FOUNDING_YEAR NULLS LAST, CANONICAL_NAME
LIMIT 200;


/* ============================================================
   SECTION 7 — SIDE-BY-SIDE TOTALS AFTER PROPOSED RECLASSIFICATION
   ============================================================
   A what-if estimate of registry impact if every item surfaced
   above were moved from {whitelist, blacklist} to FOR_REVIEW.
   ============================================================ */

WITH current_counts AS (
    SELECT
        SUM(IFF(IS_STARTUP_WHITELISTED, 1, 0)) AS curr_wl,
        SUM(IFF(IS_STARTUP_BLACKLISTED, 1, 0)) AS curr_bl,
        COUNT(*) AS curr_total
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
),
bl_flagged AS (
    SELECT COUNT(*) AS n
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE IS_STARTUP_BLACKLISTED
      AND (
          DRM_RATING_RAW IN ('A+','A','B')
          OR COALESCE(DRM_FUNDING_USD_M, 0) >= 1
          OR ENTITY_TYPE IN ('MATCHED','RC_ONLY')
          OR LOWER(COALESCE(BLACKLIST_NOTE,'') || ' ' || COALESCE(RC_BLACKLIST_NOTE,''))
             RLIKE '.*(old|mature|closed|acquir|dissolv|inactive|defunct|stopped|ceased).*'
      )
),
wl_flagged AS (
    SELECT COUNT(*) AS n
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE IS_STARTUP_WHITELISTED
      AND (
          (IFF(DRM_RATING_RAW IS NULL OR DRM_RATING_RAW NOT IN ('A+','A','B'), TRUE, FALSE)
           AND IFF(COALESCE(DRM_FUNDING_USD_M, 0) < 0.5, TRUE, FALSE)
           AND IFF(ENTITY_TYPE = 'QT_ONLY', TRUE, FALSE))
          OR COALESCE(FLAG_NON_TECH_NAME_HIT, FALSE)
      )
)
SELECT
    c.curr_wl                                           AS current_whitelist,
    c.curr_bl                                           AS current_blacklist,
    w.n                                                 AS whitelist_to_review,
    b.n                                                 AS blacklist_to_review,
    c.curr_wl - w.n                                     AS whitelist_after,
    c.curr_bl - b.n                                     AS blacklist_after,
    w.n + b.n                                           AS review_queue_size,
    ROUND(100.0 * (w.n + b.n) / (c.curr_wl + c.curr_bl), 1)
                                                        AS pct_of_decisions_flagged
FROM current_counts c, bl_flagged b, wl_flagged w;


/* ============================================================
   END — expected grids:
   0  precondition                    1 row
   1  blacklist counts by conflict    ~7 rows
   2  blacklist conflict detail       variable (priority-sorted)
   3  whitelist counts by gap         ~6 rows
   4  whitelist no-support detail     variable
   5  old/mature/closed blacklisted   variable
   6  unified re-review queue         ≤ 200 rows
   7  what-if totals                  1 row
   ============================================================ */
