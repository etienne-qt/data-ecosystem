USE DATABASE DEV_QUEBECTECH;

CREATE SCHEMA IF NOT EXISTS UTIL;

-- Normalize whitespace, lower, trim
CREATE OR REPLACE FUNCTION UTIL.NORM_TXT(s STRING)
RETURNS STRING
AS
$$
  NULLIF(
    TRIM(
      REGEXP_REPLACE(LOWER(COALESCE(s,'')), '\\s+', ' ')
    ),
    ''
  )
$$;

-- Keep digits only for NEQ
CREATE OR REPLACE FUNCTION UTIL.NORM_NEQ(s STRING)
RETURNS STRING
AS
$$
  NULLIF(REGEXP_REPLACE(COALESCE(s,''), '[^0-9]', ''), '')
$$;

-- Basic domain extraction & normalization
CREATE OR REPLACE FUNCTION UTIL.NORM_DOMAIN(url_or_domain STRING)
RETURNS STRING
AS
$$
  CASE
    WHEN UTIL.NORM_TXT(url_or_domain) IS NULL THEN NULL
    ELSE
      NULLIF(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(LOWER(url_or_domain), '^https?://', ''),
            '^www\\.',
            ''
          ),
          '/.*$',
          ''
        ),
        ''
      )
  END
$$;

-- Normalize LinkedIn company URL/id to a canonical token
CREATE OR REPLACE FUNCTION UTIL.NORM_LINKEDIN(s STRING)
RETURNS STRING
AS
$$
  CASE
    WHEN UTIL.NORM_TXT(s) IS NULL THEN NULL
    ELSE
      -- keep only the meaningful path part, drop protocol/query/fragments, lowercase
      NULLIF(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(LOWER(s), '^https?://', ''),
            '\\?.*$|#.*$',
            ''
          ),
          '^([a-z0-9.-]+/)?(company/|school/)?',
          ''
        ),
        ''
      )
  END
$$;

-- Normalize legal suffixes + punctuation for name matching
CREATE OR REPLACE FUNCTION UTIL.NORM_NAME(s STRING)
RETURNS STRING
AS
$$
  CASE
    WHEN UTIL.NORM_TXT(s) IS NULL THEN NULL
    ELSE
      NULLIF(
        TRIM(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                LOWER(s),
                '[^a-z0-9 ]',
                ' '
              ),
              '\\b(incorporated|inc|ltd|limitée|limitee|llc|corp|corporation|co|compagnie|sarl|s\\.a\\.r\\.l\\.|sa|s\\.a\\.|lp|plc)\\b',
              ' '
            ),
            '\\s+',
            ' '
          )
        ),
        ''
      )
  END
$$;

-- Cheap similarity score using edit distance (0..1). Avoids missing Jaro functions.
CREATE OR REPLACE FUNCTION UTIL.NAME_SIM(a STRING, b STRING)
RETURNS FLOAT
AS
$$
  CASE
    WHEN UTIL.NORM_NAME(a) IS NULL OR UTIL.NORM_NAME(b) IS NULL THEN NULL
    ELSE
      CAST(
        1.0 - (
          CAST(EDITDISTANCE(UTIL.NORM_NAME(a), UTIL.NORM_NAME(b)) AS FLOAT)
          / NULLIF(CAST(GREATEST(LENGTH(UTIL.NORM_NAME(a)), LENGTH(UTIL.NORM_NAME(b))) AS FLOAT), 0.0)
        )
        AS FLOAT
      )
  END
$$;

