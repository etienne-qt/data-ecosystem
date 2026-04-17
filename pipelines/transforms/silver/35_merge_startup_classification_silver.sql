-- =============================================================================
-- File: 35_merge_startup_classification_silver.sql
-- Purpose:
--   Convert engine letter rating into:
--     - startup_status (startup/non_startup/uncertain)
--     - startup_score (via mapping table)
--     - confidence
--   Apply manual overrides (SILVER.DRM_MANUAL_OVERRIDES override_type='startup').
--
-- IMPORTANT BUGFIX:
--   Do NOT QUALIFY on columns from the LEFT JOINed override table (o.*),
--   because NULL overrides collapse into a single partition and keep only 1 row.
--   Instead, pre-select "latest override per dealroom_id" in a separate CTE, then join.
-- =============================================================================

use database DEV_QUEBECTECH;

merge into DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER t
using (
  with base as (
    select
      s.dealroom_id,
      s.loaded_at,
      s.rating_letter,
      s.rating_reason,
      s.engine_output,

      m.rating_score as startup_score,

      case
        when s.rating_letter in ('A+','A','B') then 'startup'
        when s.rating_letter = 'C' then 'uncertain'
        else 'non_startup'
      end as startup_status,

      case
        when s.rating_letter in ('A+','D') then 'high'
        when s.rating_letter in ('A','B') then 'medium'
        else 'low'
      end as confidence_level
    from DEV_QUEBECTECH.SILVER.DRM_STARTUP_SIGNALS_SILVER s
    left join DEV_QUEBECTECH.UTIL.RATING_LETTER_TO_SCORE m
      on m.rating_letter = s.rating_letter
    where s.dealroom_id is not null
  ),

  latest_overrides as (
    select
      dealroom_id,
      override_value,
      override_reason,
      overridden_at
    from DEV_QUEBECTECH.SILVER.DRM_MANUAL_OVERRIDES
    where override_type = 'startup'
    qualify row_number() over (partition by dealroom_id order by overridden_at desc) = 1
  ),

  final as (
    select
      b.dealroom_id,
      b.loaded_at,

      iff(o.dealroom_id is not null, o.override_value, b.startup_status) as startup_status,
      coalesce(b.startup_score, 0) as startup_score,
      b.confidence_level,

      b.rating_letter,
      b.rating_reason,
      b.engine_output as classification_reason,

      iff(o.dealroom_id is not null, true, false) as is_manual_override,
      o.override_reason as override_reason,

      current_timestamp() as silver_loaded_at
    from base b
    left join latest_overrides o
      on o.dealroom_id = b.dealroom_id
  )

  select * from final
) s
on t.dealroom_id = s.dealroom_id

when matched and s.loaded_at >= t.loaded_at then update set
  t.startup_status = s.startup_status,
  t.startup_score = s.startup_score,
  t.confidence_level = s.confidence_level,
  t.rating_letter = s.rating_letter,
  t.rating_reason = s.rating_reason,
  t.classification_reason = s.classification_reason,
  t.is_manual_override = s.is_manual_override,
  t.override_reason = s.override_reason,
  t.loaded_at = s.loaded_at,
  t.silver_loaded_at = s.silver_loaded_at

when not matched then insert (
  dealroom_id,
  loaded_at,
  startup_status, startup_score, confidence_level,
  rating_letter, rating_reason,
  classification_reason,
  is_manual_override, override_reason,
  silver_loaded_at
) values (
  s.dealroom_id,
  s.loaded_at,
  s.startup_status, s.startup_score, s.confidence_level,
  s.rating_letter, s.rating_reason,
  s.classification_reason,
  s.is_manual_override, s.override_reason,
  s.silver_loaded_at
);



SELECT rating_letter, startup_status, COUNT(*) AS n
FROM SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_V2
GROUP BY 1,2
ORDER BY 3 DESC;