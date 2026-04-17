USE DATABASE DEV_QUEBECTECH;

WITH aab AS (
  /* active_startup + mature_startup, A+/A/B */
  SELECT
    sc.DEALROOM_ID,
    lc.LIFECYCLE_BUCKET
  FROM SILVER.DRM_STARTUP_CLASSIFICATION_SILVER sc
  JOIN SILVER.DRM_STARTUP_LIFECYCLE_SILVER lc
    ON lc.DEALROOM_ID = sc.DEALROOM_ID
  WHERE lc.LIFECYCLE_BUCKET IN ('active_startup','mature_startup')
    AND sc.RATING_LETTER IN ('A+','A','B')
),

/* -------------------- MAPPINGS -------------------- */

map_industry_labels AS (
  SELECT * FROM VALUES
    ('climate change and renewables',              'CleanTech'),
    ('consumer',                                  'Others'),
    ('defense, aerospace and security',            'Others'),
    ('financial services (fintech and insurtech)', 'ICT'),
    ('healthcare and life sciences',               'Life Sciences'),
    ('ict / enterprise software',                  'ICT'),
    ('manufacturing and industrial',               'Others'),
    ('natural resources',                          'Others'),
    ('transportation and logistics',               'Others')
  AS m(raw_value, secteur_rc)
),

map_industries_arr AS (
  SELECT * FROM VALUES
    ('chemicals',                                 'Others'),
    ('consumer electronics',                      'Others'),
    ('dating',                                    'ICT'),
    ('education',                                 'Others'),
    ('energy',                                    'CleanTech'),
    ('engineering and manufacturing equipment',   'Others'),
    ('enterprise software',                       'ICT'),
    ('event tech',                                'ICT'),
    ('fashion',                                   'Others'),
    ('fintech',                                   'ICT'),
    ('food',                                      'Agribusiness'),
    ('gaming',                                    'Others'),
    ('health',                                    'Life Sciences'),
    ('home living',                               'Others'),
    ('hosting',                                   'Others'),
    ('jobs recruitment',                          'Others'),
    ('kids',                                      'Others'),
    ('legal',                                     'ICT'),
    ('marketing',                                 'ICT'),
    ('media',                                     'Others'),
    ('music',                                     'Others'),
    ('real estate',                               'Others'),
    ('robotics',                                  'Others'),
    ('security',                                  'Others'),
    ('semiconductors',                            'Others'),
    ('space',                                     'Others'),
    ('sports',                                    'Others'),
    ('telecom',                                   'ICT'),
    ('transportation',                            'Others'),
    ('travel',                                    'Others'),
    ('wellness beauty',                           'Others')
  AS m(raw_value, secteur_rc)
),

map_sub_industries_arr AS (
  SELECT * FROM VALUES
    ('accessories',                               'Others'),
    ('accommodation',                             'Others'),
    ('adtech',                                    'ICT'),
    ('agritech',                                  'Agribusiness'),
    ('apparel',                                   'Others'),
    ('autonomous & sensor tech',                  'Others'),
    ('banking',                                   'ICT'),
    ('betting & gambling',                        'Others'),
    ('biotechnology',                             'Life Sciences'),
    ('booking & search',                          'ICT'),
    ('business travel',                           'ICT'),
    ('buy & rent',                                'ICT'),
    ('clean energy',                              'CleanTech'),
    ('cloud & infrastructure',                    'ICT'),
    ('console & pc gaming',                       'Others'),
    ('construction',                              'Others'),
    ('content production',                        'Others'),
    ('crm & sales',                               'ICT'),
    ('crypto and defi',                           'ICT'),
    ('data protection',                           'ICT'),
    ('device security & antivirus',               'ICT'),
    ('ecommerce solutions',                       'ICT'),
    ('education management',                      'ICT'),
    ('education providers',                       'Others'),
    ('energy efficiency',                         'CleanTech'),
    ('energy providers',                          'CleanTech'),
    ('energy storage',                            'CleanTech'),
    ('financial management solutions',            'ICT'),
    ('fitness',                                   'Life Sciences'),
    ('food logistics & delivery',                 'Others'),
    ('footwear',                                  'Others'),
    ('health platform',                           'Life Sciences'),
    ('in-store retail & restaurant tech',         'ICT'),
    ('innovative food',                           'Agribusiness'),
    ('insurance',                                 'ICT'),
    ('intellectual property',                     'Others'),
    ('kitchen & cooking tech',                    'Agribusiness'),
    ('learning tools and resources',              'ICT'),
    ('legal documents management',                'ICT'),
    ('legal matter management',                   'ICT'),
    ('logistics & delivery',                      'ICT'),
    ('maintenance',                               'Others'),
    ('marketing analytics',                       'ICT'),
    ('medical devices',                           'Life Sciences'),
    ('mobile gaming',                             'Others'),
    ('mobility',                                  'Others'),
    ('mortgages & lending',                       'ICT'),
    ('navigation & mapping',                      'ICT'),
    ('oil & gas',                                 'Others'),
    ('payments',                                  'ICT'),
    ('pharmaceutical',                            'Life Sciences'),
    ('public safety',                             'ICT'),
    ('publishing',                                'Others'),
    ('real estate services',                      'Others'),
    ('real estate software',                      'ICT'),
    ('regtech',                                   'ICT'),
    ('regtech & compliance',                      'ICT'),
    ('search',                                    'ICT'),
    ('search, buy & rent',                        'ICT'),
    ('social media',                              'ICT'),
    ('sport league & club',                       'ICT'),
    ('sport media',                               'ICT'),
    ('sport platform & application',              'ICT'),
    ('sporting equipment',                        'Others'),
    ('streaming',                                 'ICT'),
    ('travel analytics & software',               'ICT'),
    ('vehicle production',                        'Others'),
    ('waste solution',                            'CleanTech'),
    ('water',                                     'CleanTech'),
    ('wealth management',                         'ICT'),
    ('workspaces',                                'Others')
  AS m(raw_value, secteur_rc)
),

/* -------------------- FLATTEN + MAP -------------------- */

labels_mapped AS (
  SELECT
    s.DEALROOM_ID,
    a.LIFECYCLE_BUCKET,
    'INDUSTRY_LABELS' AS SOURCE_COL,
    m.secteur_rc
  FROM SILVER.DRM_INDUSTRY_SIGNALS_SILVER s
  JOIN aab a ON a.DEALROOM_ID = s.DEALROOM_ID,
  LATERAL FLATTEN(input => s.INDUSTRY_LABELS) f
  JOIN map_industry_labels m
    ON LOWER(TRIM(f.value::string)) = m.raw_value
),

industries_mapped AS (
  SELECT
    c.DEALROOM_ID,
    a.LIFECYCLE_BUCKET,
    'INDUSTRIES_ARR' AS SOURCE_COL,
    m.secteur_rc
  FROM SILVER.DRM_COMPANY_SILVER c
  JOIN aab a ON a.DEALROOM_ID = c.DEALROOM_ID,
  LATERAL FLATTEN(input => c.INDUSTRIES_ARR) f
  JOIN map_industries_arr m
    ON LOWER(TRIM(f.value::string)) = m.raw_value
),

sub_industries_mapped AS (
  SELECT
    c.DEALROOM_ID,
    a.LIFECYCLE_BUCKET,
    'SUB_INDUSTRIES_ARR' AS SOURCE_COL,
    m.secteur_rc
  FROM SILVER.DRM_COMPANY_SILVER c
  JOIN aab a ON a.DEALROOM_ID = c.DEALROOM_ID,
  LATERAL FLATTEN(input => c.SUB_INDUSTRIES_ARR) f
  JOIN map_sub_industries_arr m
    ON LOWER(TRIM(f.value::string)) = m.raw_value
),

all_mapped AS (
  SELECT * FROM labels_mapped
  UNION ALL
  SELECT * FROM industries_mapped
  UNION ALL
  SELECT * FROM sub_industries_mapped
),

/* -------------------- PRIMARY SECTOR (per company, not per lifecycle) -------------------- */

sector_source_weights AS (
  SELECT * FROM VALUES
    ('INDUSTRY_LABELS',     3),
    ('SUB_INDUSTRIES_ARR',  2),
    ('INDUSTRIES_ARR',      1)
  AS w(source_col, w_source)
),

sector_priority AS (
  SELECT * FROM VALUES
    ('CleanTech',      5),
    ('Life Sciences',  4),
    ('Agribusiness',   3),
    ('ICT',            2),
    ('Others',         1)
  AS p(secteur_rc, p_sector)
),

sector_scored AS (
  SELECT
    am.dealroom_id,
    am.secteur_rc,
    (SUM(w.w_source) * 100 + MAX(p.p_sector)) AS score_total
  FROM all_mapped am
  JOIN sector_source_weights w
    ON w.source_col = am.source_col
  JOIN sector_priority p
    ON p.secteur_rc = am.secteur_rc
  GROUP BY 1,2
),

sector_filtered AS (
  SELECT
    s.*,
    MAX(IFF(secteur_rc <> 'Others', 1, 0)) OVER (PARTITION BY dealroom_id) AS has_non_others,
    MAX(IFF(secteur_rc NOT IN ('Others','ICT'), 1, 0)) OVER (PARTITION BY dealroom_id) AS has_non_others_non_ict
  FROM sector_scored s
),

sector_candidates AS (
  SELECT *
  FROM sector_filtered
  WHERE
    NOT (secteur_rc = 'Others' AND has_non_others = 1)
    AND NOT (secteur_rc = 'ICT' AND has_non_others_non_ict = 1)
),

primary_sector AS (
  SELECT
    dealroom_id,
    secteur_rc AS primary_secteur_rc
  FROM sector_candidates
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY dealroom_id
    ORDER BY score_total DESC, secteur_rc
  ) = 1
),

/* -------------------- FUNDING -------------------- */
funding AS (
  SELECT
    c.DEALROOM_ID,
    COALESCE(c.TOTAL_FUNDING_USD_M, 0) AS TOTAL_FUNDING_USD_M
  FROM SILVER.DRM_COMPANY_SILVER c
  JOIN aab a ON a.DEALROOM_ID = c.DEALROOM_ID
)

SELECT
  a.LIFECYCLE_BUCKET AS "Company category",
  COALESCE(ps.primary_secteur_rc, 'UNMAPPED') AS "Secteur RC",
  COUNT(DISTINCT a.dealroom_id) AS "Number of companies",
  COUNT(DISTINCT IFF(f.TOTAL_FUNDING_USD_M > 0, a.dealroom_id, NULL)) AS "Number of funded companies",
  SUM(f.TOTAL_FUNDING_USD_M) AS "VC Funding (USD M)"
FROM aab a
LEFT JOIN primary_sector ps
  ON ps.dealroom_id = a.dealroom_id
LEFT JOIN funding f
  ON f.dealroom_id = a.dealroom_id
GROUP BY 1,2
ORDER BY
  CASE a.LIFECYCLE_BUCKET
    WHEN 'active_startup' THEN 1
    WHEN 'mature_startup' THEN 2
    ELSE 99
  END,
  CASE COALESCE(ps.primary_secteur_rc, 'UNMAPPED')
    WHEN 'CleanTech'      THEN 1
    WHEN 'Life Sciences'  THEN 2
    WHEN 'Agribusiness'   THEN 3
    WHEN 'ICT'            THEN 4
    WHEN 'Others'         THEN 5
    WHEN 'UNMAPPED'       THEN 99
    ELSE 98
  END,
  2;
