-- =============================================================================
-- File: 30_merge_startup_signals_silver.sql
-- Location: /snowflake/sql/30_silver/
-- Purpose:
--   Run the embedded startup engine and persist letter rating + component flags.
-- =============================================================================

use database DEV_QUEBECTECH;

merge into DEV_QUEBECTECH.SILVER.DRM_STARTUP_SIGNALS_SILVER t
using (
  select
    c.dealroom_id,
    c.loaded_at,
    'dealroom_v5_js_udf' as engine_version,

    UTIL.STARTUP_CLASSIFY_DEALROOM_V5(
      c.website,
      c.name,
      c.tagline,
      c.long_description,
      c.industries_raw,
      c.sub_industries_raw,
      c.tags_raw,
      c.all_tags_raw,
      c.technologies_raw,
      c.each_investor_type_raw,
      c.each_round_type_raw,
      c.investors_names_raw,
      c.lead_investors_raw,
      c.total_funding_usd_m,
      c.total_funding_eur_m,
      c.dealroom_signal_rating_raw
    ) as engine_output,

    current_timestamp() as silver_loaded_at
  from DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER c
) s
on t.dealroom_id = s.dealroom_id

when matched and s.loaded_at >= t.loaded_at then update set
  t.loaded_at = s.loaded_at,
  t.engine_version = s.engine_version,

  t.rating_letter = s.engine_output:"rating_letter"::string,
  t.rating_reason = s.engine_output:"reason"::string,

  t.tech_flag = s.engine_output:"flags":"tech"::boolean,
  t.vc_flag = s.engine_output:"flags":"vc"::boolean,
  t.accelerator_flag = s.engine_output:"flags":"accelerator"::boolean,
  t.gov_or_nonprofit_flag = s.engine_output:"flags":"gov_nonprofit"::boolean,
  t.service_provider_flag = s.engine_output:"flags":"service_provider"::boolean,
  t.consumer_only_flag = s.engine_output:"flags":"consumer_only"::boolean,

  t.dealroom_signal_rating_num = s.engine_output:"dealroom_signal_rating"::number(38,6),
  t.tech_strength = s.engine_output:"tech_strength"::number(38,0),

  t.engine_output = s.engine_output,
  t.silver_loaded_at = s.silver_loaded_at

when not matched then insert (
  dealroom_id, loaded_at,
  engine_version,
  rating_letter, rating_reason,
  tech_flag, vc_flag, accelerator_flag, gov_or_nonprofit_flag, service_provider_flag, consumer_only_flag,
  dealroom_signal_rating_num, tech_strength,
  engine_output,
  silver_loaded_at
) values (
  s.dealroom_id, s.loaded_at,
  s.engine_version,
  s.engine_output:"rating_letter"::string,
  s.engine_output:"reason"::string,
  s.engine_output:"flags":"tech"::boolean,
  s.engine_output:"flags":"vc"::boolean,
  s.engine_output:"flags":"accelerator"::boolean,
  s.engine_output:"flags":"gov_nonprofit"::boolean,
  s.engine_output:"flags":"service_provider"::boolean,
  s.engine_output:"flags":"consumer_only"::boolean,
  s.engine_output:"dealroom_signal_rating"::number(38,6),
  s.engine_output:"tech_strength"::number(38,0),
  s.engine_output,
  s.silver_loaded_at
);
