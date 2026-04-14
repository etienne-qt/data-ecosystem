-- =============================================================================
-- File: 20_create_drm_company_bronze.sql
-- Purpose:
--   Creates the BRONZE table for Dealroom companies.
--   BRONZE is:
--     - typed
--     - lightly cleaned
--     - query-friendly
--   It is NOT:
--     - deduped across sources
--     - harmonized with HubSpot/Réseau Capital/etc.
--     - business-logic "correct"
--
-- Design choice:
--   This table holds the CURRENT STATE per Dealroom company_id,
--   updated by MERGE (see 30_merge_drm_company_bronze.sql).
-- =============================================================================

use database DEV_QUEBECTECH;
use schema BRONZE;

create or replace table DRM_COMPANY_BRONZE (
  -- Lineage / provenance
  LOAD_BATCH_ID            string,
  SOURCE_FILE_NAME         string,
  LOADED_AT                timestamp_tz,

  -- Primary identifier from Dealroom export
  DEALROOM_ID              string,

  -- Core identity fields
  NAME                     string,
  DEALROOM_URL             string,
  WEBSITE                  string,

  TAGLINE                  string,
  LONG_DESCRIPTION         string,

  -- Location fields (keep textual fields + typed lat/long)
  ADDRESS                  string,
  STREET                   string,
  STREET_NUMBER            string,
  STREET_FULL              string,
  ZIPCODE                  string,

  HQ_REGION                string,
  HQ_COUNTRY               string,
  HQ_STATE                 string,
  HQ_CITY                  string,

  LATITUDE                 double,
  LONGITUDE                double,

  -- Raw list-like fields and parsed arrays (where helpful)
  TAGS_RAW                 string,
  TAGS_ARR                 variant,

  INDUSTRIES_RAW           string,
  INDUSTRIES_ARR           variant,

  SUB_INDUSTRIES_RAW       string,
  SUB_INDUSTRIES_ARR       variant,

  INVESTORS_NAMES_RAW      string,
  INVESTORS_NAMES_ARR      variant,

  -- Funding fields
  TOTAL_FUNDING_EUR_M      number(38,6),
  TOTAL_FUNDING_USD_M      number(38,6),
  LAST_ROUND               string,
  LAST_FUNDING_AMOUNT      number(38,6),
  LAST_FUNDING_DATE        date,
  FIRST_FUNDING_DATE       date,
  SEED_YEAR                number(38,0),

  -- Launch / closing
  LAUNCH_YEAR              number(38,0),
  LAUNCH_MONTH             number(38,0),
  LAUNCH_DATE              date,

  CLOSING_YEAR             number(38,0),
  CLOSING_MONTH            number(38,0),
  CLOSING_DATE             date,

  -- Team/size
  EMPLOYEES_RANGE          string,
  EMPLOYEES_LATEST_NUMBER  number(38,0),

  -- Social links
  LINKEDIN                 string,
  TWITTER                  string,
  FACEBOOK                 string,
  CRUNCHBASE               string,

  -- Status & Dealroom signals (typed where possible)
  COMPANY_STATUS           string,
  DEALROOM_SIGNAL_RATING   string,
  DEALROOM_SIGNAL_COMPLETENESS   number(38,6),
  DEALROOM_SIGNAL_TEAM_STRENGTH  number(38,6),
  DEALROOM_SIGNAL_GROWTH_RATE    number(38,6),
  DEALROOM_SIGNAL_TIMING         number(38,6),

  -- Registry hints
  TRADE_REGISTER_NUMBER    string,
  TRADE_REGISTER_NAME      string,
  TRADE_REGISTER_URL       string,

  -- Operational metadata
  BRONZE_LOADED_AT         timestamp_tz,

  -- Convenience: track whether parsed arrays succeeded (helps debugging)
  PARSE_NOTES              variant
);

