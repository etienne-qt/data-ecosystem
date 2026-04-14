-- 1) Build/refresh the review queue (companies NOT in overrides)
create or replace table SILVER.DRM_REVIEW_QUEUE_SILVER as
select
  c.DEALROOM_ID,
  current_timestamp() as GENERATED_AT,
  50 as PRIORITY,
  'NOT_IN_OVERRIDES' as REASONS,
  'startup_classification' as REVIEW_TYPE
from SILVER.DRM_COMPANY_SILVER c
left join SILVER.DRM_STARTUP_OVERRIDES o
  on o.DEALROOM_ID = c.DEALROOM_ID
where o.DEALROOM_ID is null
  and c.DEALROOM_ID is not null;

-- 2) Pull full details for export (run this and export from the results grid)
select
  q.DEALROOM_ID,
  q.GENERATED_AT,
  q.PRIORITY,
  q.REASONS,
  q.REVIEW_TYPE,
  c.*
from SILVER.DRM_REVIEW_QUEUE_SILVER q
join SILVER.DRM_COMPANY_SILVER c
  on c.DEALROOM_ID = q.DEALROOM_ID;


SELECT
  c.*,
  s.RATING_LETTER
FROM SILVER.DRM_COMPANY_ENRICHED_SILVER c
LEFT JOIN SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_V2 s
  ON s.DEALROOM_ID = c.DEALROOM_ID
WHERE c.DEALROOM_ID IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM SILVER.DRM_STARTUP_OVERRIDES o
    WHERE o.DEALROOM_ID = c.DEALROOM_ID
  );
