CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.V_DRM_LATEST AS
WITH d AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY ID
      ORDER BY LOADED_AT DESC, LOAD_BATCH_ID DESC, SOURCE_FILE_NAME DESC
    ) AS RN
  FROM DEV_QUEBECTECH.IMPORT.DRM_COMPANY_RAW
)
SELECT
  ID                                                        AS DRM_ID,
  NAME                                                      AS DRM_NAME_RAW,
  UTIL.NORM_NAME(NAME)                                      AS DRM_NAME_NORM,

  DEALROOM_URL                                              AS DRM_DEALROOM_URL,
  WEBSITE                                                   AS DRM_WEBSITE_RAW,
  UTIL.NORM_DOMAIN(WEBSITE)                                 AS DRM_DOMAIN_NORM,

  LINKEDIN                                                  AS DRM_LINKEDIN_RAW,
  UTIL.NORM_LINKEDIN(LINKEDIN)                              AS DRM_LINKEDIN_NORM,

  TRADE_REGISTER_NUMBER                                     AS DRM_NEQ_RAW,
  UTIL.NORM_NEQ(TRADE_REGISTER_NUMBER)                      AS DRM_NEQ_NORM,

  LOADED_AT,
  LOAD_BATCH_ID,
  SOURCE_FILE_NAME
FROM d
WHERE RN = 1;
