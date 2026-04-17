-- -----------------------------------------------------------------------------
-- SILVER.DRM_ACTIVITY_STATUS_SILVER_V2
-- Dealroom-only activity heuristic + website validity signal.
--
-- Inputs:
--   - SILVER.DRM_COMPANY_SILVER (Dealroom normalized fields)
--   - SILVER.DRM_WEBSITE_STATUS_SILVER (latest HTTP check)
--   - SILVER.DRM_MANUAL_OVERRIDES (override_type='activity')
--
-- Outputs:
--   - activity_status_final: active / inactive / unknown (after overrides)
--   - activity_status_computed: the computed status before overrides
--   - activity_score: numeric score for explainability
--   - activity_reason: compact explanation string
--   - activity_debug: VARIANT with component signals
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TABLE SILVER.DRM_ACTIVITY_STATUS_SILVER_V2 AS
WITH latest_activity_override AS (
    SELECT
        company_id,
        override_value      AS activity_override_value,
        override_reason     AS activity_override_reason,
        overridden_at       AS activity_overridden_at,
        overridden_by       AS activity_overridden_by
    FROM SILVER.DRM_MANUAL_OVERRIDES
    WHERE override_type = 'activity'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY overridden_at DESC) = 1
),

base AS (
    SELECT
        c.company_id,

        /* These columns must exist in DRM_COMPANY_SILVER (rename if yours differ) */
        c.company_status,
        c.closing_date,
        c.last_funding_date,

        c.website_url,
        c.website_domain,

        w.website_status,
        w.http_status           AS website_http_status,
        w.website_checked_at,
        w.website_reason,
        w.final_domain          AS website_final_domain,

        o.activity_override_value,
        o.activity_override_reason,
        o.activity_overridden_at,
        o.activity_overridden_by

    FROM SILVER.DRM_COMPANY_SILVER c
    LEFT JOIN SILVER.DRM_WEBSITE_STATUS_SILVER w
        ON c.company_id = w.company_id
    LEFT JOIN latest_activity_override o
        ON c.company_id = o.company_id
),

signals AS (
    SELECT
        b.*,

        /* Core signals */
        IFF(
            (b.closing_date IS NOT NULL)
            OR (LOWER(COALESCE(b.company_status,'')) IN ('closed','bankrupt','dissolved','inactive')),
            TRUE, FALSE
        ) AS sig_closed,

        IFF(
            b.last_funding_date IS NOT NULL
            AND b.last_funding_date >= DATEADD(month, -24, CURRENT_DATE()),
            TRUE, FALSE
        ) AS sig_recent_funding_24m,

        IFF(
            (b.website_url IS NOT NULL AND TRIM(b.website_url) <> '')
            OR (b.website_domain IS NOT NULL AND TRIM(b.website_domain) <> ''),
            TRUE, FALSE
        ) AS sig_has_website,

        IFF(b.website_status = 'valid',  TRUE, FALSE) AS sig_website_valid,
        IFF(b.website_status IN ('invalid','parked','error'), TRUE, FALSE) AS sig_website_bad

    FROM base b
),

scored AS (
    SELECT
        s.*,

        /* Simple additive scoring; clamp to 0..100 */
        LEAST(
            100,
            GREATEST(
                0,
                50
                + IFF(sig_recent_funding_24m, 20, 0)
                + IFF(sig_has_website,        10, 0)
                + IFF(sig_website_valid,      15, 0)
                - IFF(sig_website_bad,        25, 0)
                - IFF(sig_closed,             80, 0)
            )
        )::FLOAT AS activity_score
    FROM signals s
),

classified AS (
    SELECT
        sc.*,

        /* Computed (pre-override) status */
        CASE
            WHEN sig_closed THEN 'inactive'
            WHEN activity_score >= 60 THEN 'active'
            WHEN activity_score <= 35 THEN 'inactive'
            ELSE 'unknown'
        END AS activity_status_computed,

        ARRAY_TO_STRING(
            ARRAY_CONSTRUCT_COMPACT(
                IFF(sig_closed, 'closed_signal', NULL),
                IFF(sig_recent_funding_24m, 'recent_funding_24m', NULL),
                IFF(sig_website_valid, 'website_valid', NULL),
                IFF(sig_website_bad, 'website_invalid_or_parked_or_error', NULL),
                IFF(NOT sig_has_website, 'no_website', NULL),
                IFF(website_checked_at IS NULL, 'website_not_checked', NULL)
            ),
            '; '
        ) AS activity_reason_computed,

        TO_VARIANT(OBJECT_CONSTRUCT(
            'sig_closed', sig_closed,
            'sig_recent_funding_24m', sig_recent_funding_24m,
            'sig_has_website', sig_has_website,
            'sig_website_valid', sig_website_valid,
            'sig_website_bad', sig_website_bad,
            'website_status', website_status,
            'website_http_status', website_http_status,
            'website_final_domain', website_final_domain,
            'website_checked_at', website_checked_at
        )) AS activity_debug

    FROM scored sc
)

SELECT
    company_id,

    /* Final status (post-override) */
    COALESCE(activity_override_value, activity_status_computed) AS activity_status,

    /* Keep both for traceability */
    activity_status_computed,
    activity_score,

    CASE
        WHEN activity_override_value IS NOT NULL THEN
            'manual_override: ' || COALESCE(activity_override_reason, '(no reason provided)')
        ELSE
            activity_reason_computed
    END AS activity_reason,

    activity_debug,

    /* Override metadata (optional but very useful operationally) */
    activity_override_value,
    activity_override_reason,
    activity_overridden_at,
    activity_overridden_by

FROM classified;
