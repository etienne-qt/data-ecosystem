-- -----------------------------------------------------------------------------
-- SILVER.DRM_WEBSITE_STATUS_SILVER
-- One row per company: the most recent website check result.
-- -----------------------------------------------------------------------------

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA SILVER;

CREATE OR REPLACE TABLE SILVER.DRM_WEBSITE_STATUS_SILVER AS
WITH latest AS (
    SELECT
        company_id,
        checked_at,
        input_url,
        input_domain,
        final_url,
        final_domain,
        http_status,
        error_type,
        error_message,
        response_time_ms,
        num_redirects,
        is_https,
        is_valid,
        is_parked,
        parked_reason,
        content_sha256,
        raw_result,
        ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY checked_at DESC) AS rn
    FROM BRONZE.DRM_WEBSITE_CHECKS_BRONZE
)
SELECT
    company_id,

    checked_at       AS website_checked_at,
    input_url,
    input_domain,
    final_url,
    final_domain,
    http_status,
    error_type,
    error_message,
    response_time_ms,
    num_redirects,
    is_https,
    is_valid,
    is_parked,
    parked_reason,
    content_sha256,

    /* Normalized status bucket used in activity scoring */
    CASE
        WHEN input_url IS NULL OR TRIM(input_url) = '' THEN 'no_website'
        WHEN is_parked THEN 'parked'
        WHEN is_valid THEN 'valid'
        WHEN error_type IS NOT NULL THEN 'error'
        WHEN http_status IS NULL THEN 'unknown'
        WHEN http_status >= 400 THEN 'invalid'
        ELSE 'unknown'
    END AS website_status,

    /* Human-readable reason */
    COALESCE(
        parked_reason,
        error_type,
        error_message,
        'ok'
    ) AS website_reason,

    /* Full debuggable payload */
    raw_result AS website_debug

FROM latest
WHERE rn = 1;
