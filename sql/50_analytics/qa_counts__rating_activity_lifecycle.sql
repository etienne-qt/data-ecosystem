-- -----------------------------------------------------------------------------
-- QA queries: counts by rating letter, activity status, lifecycle bucket
-- -----------------------------------------------------------------------------
use database dev_quebectech;
/* 1) Count by letter rating (engine output) */
SELECT
    rating_letter,
    COUNT(*) AS n_companies
FROM SILVER.DRM_STARTUP_SIGNALS_SILVER
GROUP BY 1
ORDER BY 1;

/* 2) Count by startup_status + rating_letter (post-mapping + overrides) */
SELECT
    startup_status,
    rating_letter,
    confidence_level,
    COUNT(*) AS n_companies
FROM SILVER.DRM_STARTUP_CLASSIFICATION_SILVER
GROUP BY 1,2,3
ORDER BY 1,2,3;

/* 3) Count by activity_status (v2) */
SELECT
    activity_status,
    COUNT(*) AS n_companies
FROM SILVER.DRM_ACTIVITY_STATUS_SILVER_V2
GROUP BY 1
ORDER BY 1;

/* 4) Cross-tab: rating_letter x activity_status */
SELECT
    cls.rating_letter,
    act.activity_status,
    COUNT(*) AS n_companies
FROM SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
JOIN SILVER.DRM_ACTIVITY_STATUS_SILVER_V2 act
  ON cls.dealroom_id = act.dealroom_id
GROUP BY 1,2
ORDER BY 1,2;

/* 5) Lifecycle counts (the new ex-startup filter layer) */
SELECT
    lfc.lifecycle_bucket,
    cls.rating_letter,
    COUNT(*) AS n_companies
FROM SILVER.DRM_STARTUP_LIFECYCLE_SILVER lfc
JOIN silver.DRM_STARTUP_CLASSIFICATION_SILVER cls
on lfc.dealroom_id = cls.dealroom_id
GROUP BY 2, 1
ORDER BY 1, 2;

/* 6) “Active startups” headline number (A+/A/B mapped to startup + lifecycle eligible) */
SELECT
    COUNT(*) AS n_current_active_startups
FROM SILVER.DRM_STARTUP_LIFECYCLE_SILVER
WHERE is_current_active_startup = TRUE;

/* 7) Breakdown of mature reasons */
SELECT
    maturity_detail,
    COUNT(*) AS n_companies
FROM SILVER.DRM_STARTUP_LIFECYCLE_SILVER
WHERE lifecycle_bucket = 'mature_startup'
GROUP BY 1
ORDER BY 2 DESC;
