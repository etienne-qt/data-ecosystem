-- -----------------------------------------------------------------------------
-- BRONZE.DRM_WEBSITE_CHECKS_BRONZE
-- Append-only table storing raw HTTP checks for company websites.
--
-- This is NOT Dealroom data; it is a derived operational dataset used to
-- strengthen activity classification in SILVER.
-- -----------------------------------------------------------------------------
USE DATABASE DEV_QUEBECTECH;
USE SCHEMA BRONZE;

CREATE OR REPLACE TABLE BRONZE.DRM_WEBSITE_CHECKS_BRONZE (
    company_id           STRING        NOT NULL,

    checked_at           TIMESTAMP_NTZ  NOT NULL,
    input_url            STRING,
    input_domain         STRING,

    final_url            STRING,
    final_domain         STRING,

    http_status          NUMBER(38,0),
    error_type           STRING,
    error_message        STRING,

    response_time_ms     NUMBER(38,0),
    num_redirects        NUMBER(38,0),

    is_https             BOOLEAN,
    is_valid             BOOLEAN,
    is_parked            BOOLEAN,
    parked_reason        STRING,

    content_sha256       STRING,
    raw_result           VARIANT,

    inserted_at          TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE BRONZE.DRM_WEBSITE_CHECKS_BRONZE IS
'Append-only history of website HTTP checks (valid/invalid/parked/error) used to strengthen activity heuristics.';
