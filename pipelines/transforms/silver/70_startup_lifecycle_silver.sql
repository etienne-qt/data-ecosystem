USE DATABASE DEV_QUEBECTECH;

CREATE OR REPLACE TABLE SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_V2 AS
WITH latest_startup_override AS (
    SELECT
        dealroom_id,
        override_value  AS startup_override_value,  -- expected values: 'startup'|'non_startup'|'uncertain'
        override_reason AS startup_override_reason,
        overridden_at   AS startup_overridden_at,
        overridden_by   AS startup_overridden_by
    FROM SILVER.DRM_MANUAL_OVERRIDES
    WHERE override_type = 'startup'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY dealroom_id ORDER BY overridden_at DESC) = 1
),

/* Turn the signals row into a VARIANT so we can safely extract fields
   even if your signals table column names differ slightly. */
signals_rows AS (
    SELECT TO_VARIANT(OBJECT_CONSTRUCT(*)) AS srow
    FROM SILVER.DRM_STARTUP_SIGNALS_SILVER
),

signals AS (
    SELECT *
    FROM (
        SELECT
            /* Best-effort ID extraction (handles DEALROOM_ID vs COMPANY_ID naming) */
            COALESCE(
                srow:"DEALROOM_ID"::STRING,
                srow:"dealroom_id"::STRING,
                srow:"COMPANY_ID"::STRING,
                srow:"company_id"::STRING,
                srow:"ID"::STRING,
                srow:"id"::STRING
            ) AS dealroom_id_raw,

            /* Best-effort rating extraction */
            COALESCE(
                srow:"RATING_LETTER"::STRING,
                srow:"rating_letter"::STRING,
                srow:"STARTUP_ENGINE_OUTPUT":"rating_letter"::STRING,
                srow:"startup_engine_output":"rating_letter"::STRING,
                srow:"ENGINE_OUTPUT":"rating_letter"::STRING,
                srow:"engine_output":"rating_letter"::STRING,
                srow:"OUTPUT":"rating_letter"::STRING,
                srow:"output":"rating_letter"::STRING
            ) AS rating_letter,

            /* Best-effort reason extraction */
            COALESCE(
                srow:"RATING_REASON"::STRING,
                srow:"rating_reason"::STRING,
                srow:"STARTUP_ENGINE_OUTPUT":"reason"::STRING,
                srow:"startup_engine_output":"reason"::STRING,
                srow:"ENGINE_OUTPUT":"reason"::STRING,
                srow:"engine_output":"reason"::STRING,
                srow:"OUTPUT":"reason"::STRING,
                srow:"output":"reason"::STRING
            ) AS rating_reason,

            /* Keep full signals row for debugging */
            srow AS signals_row
        FROM signals_rows
    )
    WHERE dealroom_id_raw IS NOT NULL
),

base AS (
    SELECT
        c.dealroom_id,
        c.loaded_at,

        s.rating_letter,
        s.rating_reason,
        s.signals_row,

        o.startup_override_value,
        o.startup_override_reason,
        o.startup_overridden_at,
        o.startup_overridden_by

    FROM SILVER.DRM_COMPANY_SILVER c
    LEFT JOIN signals s
      ON TRIM(LOWER(c.dealroom_id)) = TRIM(LOWER(s.dealroom_id_raw))
    LEFT JOIN latest_startup_override o
      ON c.dealroom_id = o.dealroom_id
),

computed AS (
    SELECT
        b.*,

        /* Map rating -> computed status */
        CASE
            WHEN b.rating_letter IN ('A+','A','B') THEN 'startup'
            WHEN b.rating_letter = 'C' THEN 'uncertain'
            WHEN b.rating_letter = 'D' THEN 'non_startup'
            ELSE 'unknown'
        END AS startup_status_computed,

        /* Confidence based on your rules */
        CASE
            WHEN b.rating_letter IN ('A+','D') THEN 'High'
            WHEN b.rating_letter IN ('A','B') THEN 'Medium'
            WHEN b.rating_letter = 'C' THEN 'Low'
            ELSE 'Unknown'
        END AS confidence_level_computed,

        /* Score */
        UTIL.RATING_LETTER_TO_SCORE(b.rating_letter)::NUMBER(38,6) AS startup_score_computed

    FROM base b
)

SELECT
    dealroom_id,
    loaded_at,

    /* Final status after override */
    COALESCE(startup_override_value, startup_status_computed) AS startup_status,

    /* Final score (still derived from rating; override changes status not letter) */
    startup_score_computed AS startup_score,

    /* Confidence (still derived from letter) */
    confidence_level_computed AS confidence_level,

    rating_letter,
    rating_reason,

    TO_VARIANT(OBJECT_CONSTRUCT(
        'startup_status_computed', startup_status_computed,
        'confidence_level_computed', confidence_level_computed,
        'startup_score_computed', startup_score_computed,
        'startup_override_value', startup_override_value,
        'signals_row', signals_row
    )) AS classification_reason,

    IFF(startup_override_value IS NOT NULL, TRUE, FALSE) AS is_manual_override,
    startup_override_reason AS override_reason,

    CURRENT_TIMESTAMP() AS silver_loaded_at

FROM computed;









-- -----------------------------------------------------------------------------
-- SILVER.DRM_STARTUP_LIFECYCLE_SILVER
-- Determines whether a (potential) startup is:
--   - active startup (eligible)
--   - mature startup (exit / 1000+ employees / 1B+ valuation)
--   - closed startup
--   - founded before 1990
--   - founded between 1990-2010
--
-- This table does NOT replace your startup classifier.
-- It complements it with lifecycle / "ex-startup" detection.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TABLE SILVER.DRM_STARTUP_LIFECYCLE_SILVER AS
WITH latest_lifecycle_override AS (
    SELECT
        dealroom_id,
        override_value      AS lifecycle_override_value,
        override_reason     AS lifecycle_override_reason,
        overridden_at       AS lifecycle_overridden_at,
        overridden_by       AS lifecycle_overridden_by
    FROM SILVER.DRM_MANUAL_OVERRIDES
    WHERE override_type = 'lifecycle'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY dealroom_id ORDER BY overridden_at DESC) = 1
),

base AS (
    SELECT
        c.dealroom_id,

        /* Startup engine outcome */
        cls.startup_status,          -- 'startup' | 'non_startup' | 'uncertain'
        cls.rating_letter,           -- A+ | A | B | C | D
        cls.confidence_level,

        /* Activity outcome (use V2 if you adopt it) */
        act.activity_status,         -- active | inactive | unknown

        /* Fields needed for maturity + age (rename if yours differ) */
        c.launch_year,               -- founding year / launch year
        c.company_status,            -- used for exit/IPO/acquisition hints
        c.valuation_usd,             -- numeric USD valuation if available
        c.employees_range,           -- e.g., '11-50', '1001-5000', '10000+'
        c.EMPLOYEES_LATEST_NUMBER,                -- numeric estimate if available

    

        o.lifecycle_override_value,
        o.lifecycle_override_reason,
        o.lifecycle_overridden_at,
        o.lifecycle_overridden_by

    FROM SILVER.DRM_COMPANY_SILVER c
    LEFT JOIN SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
        ON c.dealroom_id = cls.dealroom_id
    LEFT JOIN SILVER.DRM_ACTIVITY_STATUS_SILVER_V2 act
        ON c.dealroom_id = act.dealroom_id
    LEFT JOIN latest_lifecycle_override o
        ON c.dealroom_id = o.dealroom_id
),

emp AS (
    SELECT
        b.*,
        UTIL.PARSE_EMPLOYEES_RANGE_DEALROOM_V1(b.employees_range, b.EMPLOYEES_LATEST_NUMBER::FLOAT) AS employees_parsed
    FROM base b
),

signals AS (
    SELECT
        e.*,

        /* Age flags */
        IFF(e.launch_year IS NOT NULL AND e.launch_year < 1990, TRUE, FALSE) AS sig_pre_1990,
        IFF(e.launch_year IS NOT NULL AND e.launch_year >= 1990 AND e.launch_year < 2010, TRUE, FALSE) AS sig_1990_2010,

        /* Maturity flags */
        IFF(COALESCE(e.valuation_usd, 0) >= 1000000000, TRUE, FALSE) AS sig_mature_1b_valuation,
        COALESCE(e.employees_parsed:employees_ge_1000::BOOLEAN, FALSE) AS sig_mature_1000_employees,

        IFF(
            /* status-based exit hints */
            LOWER(COALESCE(e.company_status,'')) IN ('acquired','ipo','public')
            OR LOWER(COALESCE(e.company_status,'')) LIKE '%acqui%'
            OR LOWER(COALESCE(e.company_status,'')) LIKE '%ipo%',
            TRUE, FALSE
        ) AS sig_mature_exit,

        /* Closed flag comes from your activity layer */
        IFF(e.activity_status = 'inactive', TRUE, FALSE) AS sig_closed

    FROM emp e
),

lifecycle AS (
    SELECT
        s.*,

        /* Combine maturity flags */
        IFF(sig_mature_exit OR sig_mature_1000_employees OR sig_mature_1b_valuation, TRUE, FALSE) AS sig_mature_any,

        /* Detail string for maturity */
        ARRAY_TO_STRING(
            ARRAY_CONSTRUCT_COMPACT(
                IFF(sig_mature_exit, 'mature_exit', NULL),
                IFF(sig_mature_1000_employees, 'mature_1000_employees', NULL),
                IFF(sig_mature_1b_valuation, 'mature_1b_valuation', NULL)
            ),
            ','
        ) AS maturity_detail
    FROM signals s
)

SELECT
    dealroom_id,
    startup_status,
    rating_letter,
    confidence_level,
    activity_status,

    launch_year,
    company_status,
    valuation_usd,
    employees_range,
    EMPLOYEES_LATEST_NUMBER,
    employees_parsed,

    sig_pre_1990,
    sig_1990_2010,
    sig_mature_exit,
    sig_mature_1000_employees,
    sig_mature_1b_valuation,
    sig_mature_any,
    sig_closed,
    maturity_detail,

    /* ---------------------------
       Lifecycle bucket (computed)
       --------------------------- */
    CASE
        WHEN startup_status IS NULL THEN 'unknown'
        WHEN startup_status = 'non_startup' THEN 'not_startup'

        /* Mature takes precedence over "closed" and age filters */
        WHEN sig_mature_any THEN 'mature_startup'
        WHEN sig_closed THEN 'closed_startup'

        WHEN sig_pre_1990 THEN 'founded_before_1990'
        WHEN sig_1990_2010 THEN 'founded_1990_2010'

        /* Eligible: startup or uncertain + active/unknown activity + founded >= 2010 */
        WHEN startup_status IN ('startup','uncertain')
             AND activity_status IN ('active','unknown')
             AND (launch_year IS NULL OR launch_year >= 2010)
        THEN 'active_startup'

        ELSE 'unknown'
    END AS lifecycle_bucket_computed,

    /* Helpful, human-readable reason */
    ARRAY_TO_STRING(
        ARRAY_CONSTRUCT_COMPACT(
            IFF(sig_mature_any, 'mature:' || maturity_detail, NULL),
            IFF(sig_closed, 'closed:activity_inactive', NULL),
            IFF(sig_pre_1990, 'age:pre_1990', NULL),
            IFF(sig_1990_2010, 'age:1990_2010', NULL),
            IFF(launch_year IS NULL, 'age:unknown', NULL)
        ),
        '; '
    ) AS lifecycle_reason_computed,

    /* Apply manual lifecycle override if present */
    COALESCE(lifecycle_override_value, lifecycle_bucket_computed) AS lifecycle_bucket,

    CASE
        WHEN lifecycle_override_value IS NOT NULL THEN
            'manual_override: ' || COALESCE(lifecycle_override_reason, '(no reason provided)')
        ELSE lifecycle_reason_computed
    END AS lifecycle_reason,

    /* Ex-startup flag: anything not eligible */
    IFF(
        COALESCE(lifecycle_override_value, lifecycle_bucket_computed) = 'active_startup',
        FALSE,
        TRUE
    ) AS is_ex_startup,

    IFF(
        COALESCE(lifecycle_override_value, lifecycle_bucket_computed) = 'active_startup'
        AND startup_status = 'startup',
        TRUE,
        FALSE
    ) AS is_current_active_startup,

    lifecycle_override_value,
    lifecycle_override_reason,
    lifecycle_overridden_at,
    lifecycle_overridden_by

FROM lifecycle;
