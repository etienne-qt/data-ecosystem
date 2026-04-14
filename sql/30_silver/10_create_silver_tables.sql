-- =============================================================================
-- File: 10_create_silver_tables.sql
-- Location: /snowflake/sql/30_silver/
-- Purpose:
--   Create SILVER tables for Dealroom enrichment + classification.
-- =============================================================================

use database DEV_QUEBECTECH;
use schema SILVER;

create or replace table DRM_COMPANY_SILVER (
  DEALROOM_ID string,
  LOADED_AT timestamp_tz,

  NAME string,
  DEALROOM_URL string,
  WEBSITE string,
  WEBSITE_DOMAIN string,

  TAGLINE string,
  LONG_DESCRIPTION string,

  INDUSTRIES_RAW string,
  SUB_INDUSTRIES_RAW string,
  TAGS_RAW string,
  ALL_TAGS_RAW string,
  TECHNOLOGIES_RAW string,

  EACH_INVESTOR_TYPE_RAW string,
  EACH_ROUND_TYPE_RAW string,
  INVESTORS_NAMES_RAW string,
  LEAD_INVESTORS_RAW string,

  HQ_COUNTRY string,
  HQ_STATE string,
  HQ_CITY string,
  LATITUDE double,
  LONGITUDE double,

  TOTAL_FUNDING_USD_M number(38,6),
  TOTAL_FUNDING_EUR_M number(38,6),
  LAST_FUNDING_DATE date,
  FIRST_FUNDING_DATE date,

  DEALROOM_SIGNAL_RATING_RAW string,
  DEALROOM_SIGNAL_RATING_NUM number(38,6),

  COMPANY_STATUS string,
  CLOSING_DATE date,

  EMPLOYEES_RANGE string,
  EMPLOYEES_LATEST_NUMBER number(38,0),

  TAGS_ARR variant,
  INDUSTRIES_ARR variant,
  SUB_INDUSTRIES_ARR variant,
  INVESTORS_NAMES_ARR variant,

  DEALROOM_SIGNAL_COMPLETENESS number(38,6),
  DEALROOM_SIGNAL_TEAM_STRENGTH number(38,6),
  DEALROOM_SIGNAL_GROWTH_RATE number(38,6),
  DEALROOM_SIGNAL_TIMING number(38,6),

  SILVER_LOADED_AT timestamp_tz
);

create or replace table DRM_STARTUP_SIGNALS_SILVER (
  DEALROOM_ID string,
  LOADED_AT timestamp_tz,

  ENGINE_VERSION string,
  RATING_LETTER string,
  RATING_REASON string,

  TECH_FLAG boolean,
  VC_FLAG boolean,
  ACCELERATOR_FLAG boolean,
  GOV_OR_NONPROFIT_FLAG boolean,
  SERVICE_PROVIDER_FLAG boolean,
  CONSUMER_ONLY_FLAG boolean,

  DEALROOM_SIGNAL_RATING_NUM number(38,6),
  TECH_STRENGTH number(38,0),

  ENGINE_OUTPUT variant,

  SILVER_LOADED_AT timestamp_tz
);

create or replace table DRM_STARTUP_CLASSIFICATION_SILVER (
  DEALROOM_ID string,
  LOADED_AT timestamp_tz,

  STARTUP_STATUS string,       -- startup | non_startup | uncertain
  STARTUP_SCORE number(38,6),  -- numeric mapping from letter
  CONFIDENCE_LEVEL string,     -- high | medium | low

  RATING_LETTER string,
  RATING_REASON string,

  CLASSIFICATION_REASON variant,

  IS_MANUAL_OVERRIDE boolean,
  OVERRIDE_REASON string,

  SILVER_LOADED_AT timestamp_tz
);

create or replace table DRM_ACTIVITY_STATUS_SILVER (
  DEALROOM_ID string,
  LOADED_AT timestamp_tz,

  ACTIVITY_STATUS string,      -- active | inactive | unknown
  ACTIVITY_SCORE number(38,6),
  ACTIVITY_REASON variant,

  IS_MANUAL_OVERRIDE boolean,
  OVERRIDE_REASON string,

  SILVER_LOADED_AT timestamp_tz
);

create or replace table DRM_REVIEW_QUEUE_SILVER (
  DEALROOM_ID string,
  REVIEW_TYPE string,
  PRIORITY number(38,0),
  REASONS variant,
  GENERATED_AT timestamp_tz default current_timestamp()
);

-- Manual overrides must persist (do NOT OR REPLACE)
create table if not exists DRM_MANUAL_OVERRIDES (
  DEALROOM_ID string,
  OVERRIDE_TYPE string,        -- 'startup' or 'activity'
  OVERRIDE_VALUE string,       -- startup: startup/non_startup/uncertain
                               -- activity: active/inactive/unknown
  OVERRIDE_REASON string,
  OVERRIDDEN_BY string,
  OVERRIDDEN_AT timestamp_tz default current_timestamp()
);


-- extending the table to carry required fields from Bronze

USE DATABASE DEV_QUEBECTECH;

ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS LAUNCH_DATE  DATE;
ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS LAUNCH_MONTH NUMBER(38,0);
ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS LAUNCH_YEAR  NUMBER(38,0);


USE DATABASE DEV_QUEBECTECH;

ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS LAUNCH_DATE  DATE;
ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS LAUNCH_MONTH NUMBER(38,0);
ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS LAUNCH_YEAR  NUMBER(38,0);

ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS VALUATION_USD NUMBER(38,6);
ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS HISTORICAL_VALUATIONS_VALUES_USD_M STRING;

-- Exit/IPO/acquired hints from raw (list-like)
ALTER TABLE SILVER.DRM_COMPANY_SILVER ADD COLUMN IF NOT EXISTS EACH_ROUND_TYPE_RAW STRING;


USE DATABASE DEV_QUEBECTECH;

CREATE TABLE IF NOT EXISTS SILVER.DRM_STARTUP_OVERRIDES (
  DEALROOM_ID         STRING            NOT NULL,
  DEALROOM_URL_INPUT  STRING,
  DEALROOM_URL_NORM   STRING,

  STARTUP_STATUS      STRING,           -- 'startup' | 'non-startup'
  RATING_LETTER       STRING,           -- 'A+' or 'D'
  RATING_REASON       STRING,           -- 'A+_manual_review' or 'manual_review'

  OVERRIDDEN_AT       TIMESTAMP_NTZ      DEFAULT CURRENT_TIMESTAMP(),
  OVERRIDDEN_BY       STRING,           -- e.g. user email or name
  OVERRIDE_REASON     STRING,           -- free text
  SOURCE              STRING,           -- e.g. 'manual_csv_upload'
  IS_ACTIVE           BOOLEAN           DEFAULT TRUE,

  LOADED_AT           TIMESTAMP_NTZ      DEFAULT CURRENT_TIMESTAMP()
);

-- Helpful clustering for latest override lookups
ALTER TABLE SILVER.DRM_STARTUP_OVERRIDES CLUSTER BY (DEALROOM_ID, OVERRIDDEN_AT);


CREATE OR REPLACE VIEW SILVER.DRM_COMPANY_URLS_VW AS
SELECT
  DEALROOM_ID,
  DEALROOM_URL,
  UTIL.NORMALIZE_DEALROOM_URL(DEALROOM_URL) AS DEALROOM_URL_NORM
FROM SILVER.DRM_COMPANY_SILVER;