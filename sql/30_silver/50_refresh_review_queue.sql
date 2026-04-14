-- =============================================================================
-- File: 50_refresh_review_queue.sql
-- Location: /snowflake/sql/30_silver/
-- Purpose:
--   Generate human review queue.
-- =============================================================================

use database DEV_QUEBECTECH;
use schema SILVER;

truncate table DRM_REVIEW_QUEUE_SILVER;

-- Startup: C is “uncertain by design”
insert into DRM_REVIEW_QUEUE_SILVER (DEALROOM_ID, REVIEW_TYPE, PRIORITY, REASONS)
select
  c.dealroom_id,
  'startup',
  case
    when c.rating_letter = 'C' then 90
    when c.startup_status = 'uncertain' then 80
    else 60
  end as priority,
  object_construct(
    'startup_status', c.startup_status,
    'startup_score', c.startup_score,
    'confidence', c.confidence_level,
    'rating_letter', c.rating_letter,
    'rating_reason', c.rating_reason,
    'engine', c.classification_reason
  ) as reasons
from SILVER.DRM_STARTUP_CLASSIFICATION_SILVER c
where c.is_manual_override = false
  and (c.rating_letter = 'C' or c.startup_status = 'uncertain');

-- Activity: unknown, or inactive but classified startup (contradiction)
insert into DRM_REVIEW_QUEUE_SILVER (DEALROOM_ID, REVIEW_TYPE, PRIORITY, REASONS)
select
  a.dealroom_id,
  'activity',
  case
    when a.activity_status = 'unknown' then 80
    when a.activity_status = 'inactive' and sc.startup_status = 'startup' then 95
    else 60
  end as priority,
  object_construct(
    'activity_status', a.activity_status,
    'activity_score', a.activity_score,
    'activity_reason', a.activity_reason,
    'startup_status', sc.startup_status,
    'rating_letter', sc.rating_letter,
    'startup_score', sc.startup_score
  ) as reasons
from SILVER.DRM_ACTIVITY_STATUS_SILVER a
left join SILVER.DRM_STARTUP_CLASSIFICATION_SILVER sc
  on sc.dealroom_id = a.dealroom_id
where a.is_manual_override = false
  and (
    a.activity_status = 'unknown'
    or (a.activity_status = 'inactive' and sc.startup_status = 'startup')
  );
