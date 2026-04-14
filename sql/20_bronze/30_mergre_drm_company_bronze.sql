-- =============================================================================
-- File: 30_merge_drm_company_bronze.sql
-- Purpose:
--   Incrementally upsert (MERGE) Dealroom company data from:
--     DEV_QUEBECTECH.IMPORT.DRM_COMPANY_RAW  ->  DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE
--
-- What this script does:
--   1) Selects the newest row per Dealroom ID from IMPORT (based on LOADED_AT)
--   2) Applies minimal cleaning + typing using UTIL UDFs
--   3) MERGEs into BRONZE:
--        - update if new row is newer (LOADED_AT)
--        - insert if new ID
--
-- Assumptions:
--   - IMPORT may contain multiple rows per ID across loads/batches.
--   - LOADED_AT is reliable for "latest".
--
-- Notes on list parsing:
--   Dealroom exports list-like fields inconsistently.
--   We parse TAGS/INDUSTRIES/INVESTORS using a simple delimiter heuristic:
--     - if contains ';' -> split by ';'
--     - else if contains ',' -> split by ','
--     - else single-element array
-- =============================================================================

use database DEV_QUEBECTECH;

-- Explicit schemas make the script easier to read
use schema BRONZE;

merge into DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE t
using (
  with latest_per_id as (
    select
      r.*
    from DEV_QUEBECTECH.IMPORT.DRM_COMPANY_RAW r
    qualify row_number() over (
      partition by r.id
      order by r.loaded_at desc
    ) = 1
  ),
  cleaned as (
    select
      -- lineage
      load_batch_id,
      source_file_name,
      loaded_at,

      -- identifiers
      UTIL.NULLIF_BLANK(id) as dealroom_id,

      -- core identity
      UTIL.NULLIF_BLANK(name) as name,
      UTIL.NULLIF_BLANK(dealroom_url) as dealroom_url,
      UTIL.NULLIF_BLANK(website) as website,

      UTIL.NULLIF_BLANK(tagline) as tagline,
      UTIL.NULLIF_BLANK(long_description) as long_description,

      -- location
      UTIL.NULLIF_BLANK(address) as address,
      UTIL.NULLIF_BLANK(street) as street,
      UTIL.NULLIF_BLANK(street_number) as street_number,
      UTIL.NULLIF_BLANK(street_and_street_number) as street_full,
      UTIL.NULLIF_BLANK(zipcode) as zipcode,

      UTIL.NULLIF_BLANK(hq_region) as hq_region,
      UTIL.NULLIF_BLANK(hq_country) as hq_country,
      UTIL.NULLIF_BLANK(hq_state) as hq_state,
      UTIL.NULLIF_BLANK(hq_city) as hq_city,

      UTIL.TRY_TO_DOUBLE_CLEAN(latitude) as latitude,
      UTIL.TRY_TO_DOUBLE_CLEAN(longitude) as longitude,

      -- raw list-like fields
      UTIL.NULLIF_BLANK(tags) as tags_raw,
      UTIL.NULLIF_BLANK(industries) as industries_raw,
      UTIL.NULLIF_BLANK(sub_industries) as sub_industries_raw,
      UTIL.NULLIF_BLANK(investors_names) as investors_names_raw,

      -- parsed arrays with delimiter heuristic
      case
        when UTIL.NULLIF_BLANK(tags) is null then null
        when tags like '%;%' then to_variant(split(tags, ';'))
        when tags like '%,%' then to_variant(split(tags, ','))
        else to_variant(array_construct(trim(tags)))
      end as tags_arr,

      case
        when UTIL.NULLIF_BLANK(industries) is null then null
        when industries like '%;%' then to_variant(split(industries, ';'))
        when industries like '%,%' then to_variant(split(industries, ','))
        else to_variant(array_construct(trim(industries)))
      end as industries_arr,

      case
        when UTIL.NULLIF_BLANK(sub_industries) is null then null
        when sub_industries like '%;%' then to_variant(split(sub_industries, ';'))
        when sub_industries like '%,%' then to_variant(split(sub_industries, ','))
        else to_variant(array_construct(trim(sub_industries)))
      end as sub_industries_arr,

      case
        when UTIL.NULLIF_BLANK(investors_names) is null then null
        when investors_names like '%;%' then to_variant(split(investors_names, ';'))
        when investors_names like '%,%' then to_variant(split(investors_names, ','))
        else to_variant(array_construct(trim(investors_names)))
      end as investors_names_arr,

      -- funding
      UTIL.TRY_TO_NUMBER_CLEAN(total_funding_eur_m) as total_funding_eur_m,
      UTIL.TRY_TO_NUMBER_CLEAN(total_funding_usd_m) as total_funding_usd_m,

      UTIL.NULLIF_BLANK(last_round) as last_round,
      UTIL.TRY_TO_NUMBER_CLEAN(last_funding_amount) as last_funding_amount,

      UTIL.TRY_TO_DATE_ANY(last_funding_date) as last_funding_date,
      UTIL.TRY_TO_DATE_ANY(first_funding_date) as first_funding_date,

      try_to_number(UTIL.NULLIF_BLANK(seed_year)) as seed_year,

      -- launch / closing
      try_to_number(UTIL.NULLIF_BLANK(launch_year)) as launch_year,
      try_to_number(UTIL.NULLIF_BLANK(launch_month)) as launch_month,
      UTIL.TRY_TO_DATE_ANY(launch_date) as launch_date,

      try_to_number(UTIL.NULLIF_BLANK(closing_year)) as closing_year,
      try_to_number(UTIL.NULLIF_BLANK(closing_month)) as closing_month,
      UTIL.TRY_TO_DATE_ANY(closing_date) as closing_date,

      -- team/size
      UTIL.NULLIF_BLANK(employees_range) as employees_range,
      try_to_number(UTIL.NULLIF_BLANK(employees_latest_number)) as employees_latest_number,

      -- socials
      UTIL.NULLIF_BLANK(linkedin) as linkedin,
      UTIL.NULLIF_BLANK(twitter) as twitter,
      UTIL.NULLIF_BLANK(facebook) as facebook,
      UTIL.NULLIF_BLANK(crunchbase) as crunchbase,

      -- status & signals
      UTIL.NULLIF_BLANK(company_status) as company_status,
      UTIL.NULLIF_BLANK(dealroom_signal_rating) as dealroom_signal_rating,
      UTIL.TRY_TO_NUMBER_CLEAN(dealroom_signal_completeness) as dealroom_signal_completeness,
      UTIL.TRY_TO_NUMBER_CLEAN(dealroom_signal_team_strength) as dealroom_signal_team_strength,
      UTIL.TRY_TO_NUMBER_CLEAN(dealroom_signal_growth_rate) as dealroom_signal_growth_rate,
      UTIL.TRY_TO_NUMBER_CLEAN(dealroom_signal_timing) as dealroom_signal_timing,

      -- registry hints
      UTIL.NULLIF_BLANK(trade_register_number) as trade_register_number,
      UTIL.NULLIF_BLANK(trade_register_name) as trade_register_name,
      UTIL.NULLIF_BLANK(trade_register_url) as trade_register_url,

      -- debug notes (helps quickly diagnose why parsing yields nulls)
      object_construct(
        'tags_delim', iff(tags like '%;%', ';', iff(tags like '%,%', ',', null)),
        'industries_delim', iff(industries like '%;%', ';', iff(industries like '%,%', ',', null)),
        'investors_delim', iff(investors_names like '%;%', ';', iff(investors_names like '%,%', ',', null))
      ) as parse_notes
    from latest_per_id
    where UTIL.NULLIF_BLANK(id) is not null
  )
  select
    *,
    current_timestamp() as bronze_loaded_at
  from cleaned
) s
on t.dealroom_id = s.dealroom_id

when matched and s.loaded_at >= t.loaded_at then update set
  t.load_batch_id = s.load_batch_id,
  t.source_file_name = s.source_file_name,
  t.loaded_at = s.loaded_at,

  t.name = s.name,
  t.dealroom_url = s.dealroom_url,
  t.website = s.website,

  t.tagline = s.tagline,
  t.long_description = s.long_description,

  t.address = s.address,
  t.street = s.street,
  t.street_number = s.street_number,
  t.street_full = s.street_full,
  t.zipcode = s.zipcode,

  t.hq_region = s.hq_region,
  t.hq_country = s.hq_country,
  t.hq_state = s.hq_state,
  t.hq_city = s.hq_city,

  t.latitude = s.latitude,
  t.longitude = s.longitude,

  t.tags_raw = s.tags_raw,
  t.tags_arr = s.tags_arr,

  t.industries_raw = s.industries_raw,
  t.industries_arr = s.industries_arr,

  t.sub_industries_raw = s.sub_industries_raw,
  t.sub_industries_arr = s.sub_industries_arr,

  t.investors_names_raw = s.investors_names_raw,
  t.investors_names_arr = s.investors_names_arr,

  t.total_funding_eur_m = s.total_funding_eur_m,
  t.total_funding_usd_m = s.total_funding_usd_m,
  t.last_round = s.last_round,
  t.last_funding_amount = s.last_funding_amount,
  t.last_funding_date = s.last_funding_date,
  t.first_funding_date = s.first_funding_date,
  t.seed_year = s.seed_year,

  t.launch_year = s.launch_year,
  t.launch_month = s.launch_month,
  t.launch_date = s.launch_date,

  t.closing_year = s.closing_year,
  t.closing_month = s.closing_month,
  t.closing_date = s.closing_date,

  t.employees_range = s.employees_range,
  t.employees_latest_number = s.employees_latest_number,

  t.linkedin = s.linkedin,
  t.twitter = s.twitter,
  t.facebook = s.facebook,
  t.crunchbase = s.crunchbase,

  t.company_status = s.company_status,
  t.dealroom_signal_rating = s.dealroom_signal_rating,
  t.dealroom_signal_completeness = s.dealroom_signal_completeness,
  t.dealroom_signal_team_strength = s.dealroom_signal_team_strength,
  t.dealroom_signal_growth_rate = s.dealroom_signal_growth_rate,
  t.dealroom_signal_timing = s.dealroom_signal_timing,

  t.trade_register_number = s.trade_register_number,
  t.trade_register_name = s.trade_register_name,
  t.trade_register_url = s.trade_register_url,

  t.bronze_loaded_at = s.bronze_loaded_at,
  t.parse_notes = s.parse_notes

when not matched then insert (
  load_batch_id, source_file_name, loaded_at,
  dealroom_id,
  name, dealroom_url, website,
  tagline, long_description,
  address, street, street_number, street_full, zipcode,
  hq_region, hq_country, hq_state, hq_city,
  latitude, longitude,
  tags_raw, tags_arr,
  industries_raw, industries_arr,
  sub_industries_raw, sub_industries_arr,
  investors_names_raw, investors_names_arr,
  total_funding_eur_m, total_funding_usd_m,
  last_round, last_funding_amount, last_funding_date, first_funding_date, seed_year,
  launch_year, launch_month, launch_date,
  closing_year, closing_month, closing_date,
  employees_range, employees_latest_number,
  linkedin, twitter, facebook, crunchbase,
  company_status,
  dealroom_signal_rating, dealroom_signal_completeness, dealroom_signal_team_strength,
  dealroom_signal_growth_rate, dealroom_signal_timing,
  trade_register_number, trade_register_name, trade_register_url,
  bronze_loaded_at,
  parse_notes
) values (
  s.load_batch_id, s.source_file_name, s.loaded_at,
  s.dealroom_id,
  s.name, s.dealroom_url, s.website,
  s.tagline, s.long_description,
  s.address, s.street, s.street_number, s.street_full, s.zipcode,
  s.hq_region, s.hq_country, s.hq_state, s.hq_city,
  s.latitude, s.longitude,
  s.tags_raw, s.tags_arr,
  s.industries_raw, s.industries_arr,
  s.sub_industries_raw, s.sub_industries_arr,
  s.investors_names_raw, s.investors_names_arr,
  s.total_funding_eur_m, s.total_funding_usd_m,
  s.last_round, s.last_funding_amount, s.last_funding_date, s.first_funding_date, s.seed_year,
  s.launch_year, s.launch_month, s.launch_date,
  s.closing_year, s.closing_month, s.closing_date,
  s.employees_range, s.employees_latest_number,
  s.linkedin, s.twitter, s.facebook, s.crunchbase,
  s.company_status,
  s.dealroom_signal_rating, s.dealroom_signal_completeness, s.dealroom_signal_team_strength,
  s.dealroom_signal_growth_rate, s.dealroom_signal_timing,
  s.trade_register_number, s.trade_register_name, s.trade_register_url,
  s.bronze_loaded_at,
  s.parse_notes
);
