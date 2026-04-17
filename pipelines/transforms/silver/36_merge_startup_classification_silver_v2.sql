USE DATABASE DEV_QUEBECTECH;

CREATE OR REPLACE VIEW SILVER.DRM_STARTUP_SIGNALS_SILVER_NORM AS
SELECT
  dealroom_id,

  /* Pull letter from the engine output payload */
  ENGINE_OUTPUT:"rating_letter"::STRING AS rating_letter,
  ENGINE_OUTPUT:"reason"::STRING        AS rating_reason,

  ENGINE_OUTPUT AS engine_output
FROM SILVER.DRM_STARTUP_SIGNALS_SILVER;


CREATE OR REPLACE TABLE SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_V2 AS
WITH latest_startup_override AS (
    SELECT
        dealroom_id,
        override_value  AS startup_override_value,
        override_reason AS startup_override_reason,
        overridden_at   AS startup_overridden_at,
        overridden_by   AS startup_overridden_by
    FROM SILVER.DRM_MANUAL_OVERRIDES
    WHERE override_type = 'startup'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY dealroom_id ORDER BY overridden_at DESC) = 1
),
base AS (
    SELECT
        c.dealroom_id,
        c.loaded_at,

        s.rating_letter,
        s.rating_reason,
        s.engine_output,

        o.startup_override_value,
        o.startup_override_reason,
        o.startup_overridden_at,
        o.startup_overridden_by
    FROM SILVER.DRM_COMPANY_SILVER c
    LEFT JOIN SILVER.DRM_STARTUP_SIGNALS_SILVER_NORM s
      ON c.dealroom_id = s.dealroom_id
    LEFT JOIN latest_startup_override o
      ON c.dealroom_id = o.dealroom_id
),
computed AS (
    SELECT
        b.*,

        CASE
            WHEN b.rating_letter IN ('A+','A','B') THEN 'startup'
            WHEN b.rating_letter = 'C' THEN 'uncertain'
            WHEN b.rating_letter = 'D' THEN 'non_startup'
            ELSE 'unknown'
        END AS startup_status_computed,

        CASE
            WHEN b.rating_letter IN ('A+','D') THEN 'High'
            WHEN b.rating_letter IN ('A','B') THEN 'Medium'
            WHEN b.rating_letter = 'C' THEN 'Low'
            ELSE 'Unknown'
        END AS confidence_level_computed,

        CASE b.rating_letter
          WHEN 'A+' THEN 95
          WHEN 'A'  THEN 85
          WHEN 'B'  THEN 70
          WHEN 'C'  THEN 50
          WHEN 'D'  THEN 20
          ELSE NULL
        END::NUMBER(38,6) AS startup_score_computed
    FROM base b
)
SELECT
    dealroom_id,
    loaded_at,

    COALESCE(startup_override_value, startup_status_computed) AS startup_status,
    startup_score_computed AS startup_score,
    confidence_level_computed AS confidence_level,

    rating_letter,
    rating_reason,

    TO_VARIANT(OBJECT_CONSTRUCT(
        'startup_status_computed', startup_status_computed,
        'confidence_level_computed', confidence_level_computed,
        'startup_score_computed', startup_score_computed,
        'startup_override_value', startup_override_value,
        'engine_output', engine_output
    )) AS classification_reason,

    IFF(startup_override_value IS NOT NULL, TRUE, FALSE) AS is_manual_override,
    startup_override_reason AS override_reason,

    CURRENT_TIMESTAMP() AS silver_loaded_at
FROM computed;




SELECT
  COUNT(*) AS n_company,
  COUNT_IF(cls.dealroom_id IS NULL) AS n_missing_cls_join
FROM SILVER.DRM_COMPANY_SILVER c
LEFT JOIN SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_V2 cls
  ON c.dealroom_id = cls.dealroom_id;



SELECT
  COUNT(*) AS n,
  COUNT_IF(startup_status IS NULL) AS n_null_startup_status,
  startup_status,
  COUNT(*) AS n_by_status
FROM SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_V2
GROUP BY 3
ORDER BY 4 DESC;

ALTER TABLE SILVER.DRM_STARTUP_CLASSIFICATION_SILVER
RENAME TO SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_OLD;

ALTER TABLE SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_V2
RENAME TO SILVER.DRM_STARTUP_CLASSIFICATION_SILVER;

