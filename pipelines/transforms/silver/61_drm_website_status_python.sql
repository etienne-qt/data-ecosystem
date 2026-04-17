-- Use your DB/warehouse as needed, then:
USE SCHEMA SILVER;

-- 1) Create the target table (same name as the file/table you want)
CREATE TABLE IF NOT EXISTS SILVER.DRM_WEBSITE_ACTIVE (
  DEALROOM_ID        STRING,
  WEBSITE            STRING,
  ACTIVE             STRING,         -- 'yes' | 'no' | 'n/a'
  LAST_DATE_CHECKED  TIMESTAMP_NTZ
);

-- 2) Define (or reuse) a file format that matches your CSV
CREATE OR REPLACE FILE FORMAT SILVER.CSV_STD
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('', 'NULL', 'null');

-- 3) Load from the stage into the table
-- Replace @YOUR_STAGE/path/file.csv with your actual stage + filename
COPY INTO SILVER.DRM_WEBSITE_ACTIVE
FROM @DEV_QUEBECTECH.SILVER.WEBSITE_ACTIVITY
FILE_FORMAT = (FORMAT_NAME = REF.CSV_GENERIC)
ON_ERROR = 'ABORT_STATEMENT';

-- 4) Quick check
SELECT COUNT(*) AS ROWS_LOADED FROM SILVER.DRM_WEBSITE_ACTIVE;
SELECT * FROM SILVER.DRM_WEBSITE_ACTIVE ORDER BY LAST_DATE_CHECKED DESC LIMIT 50;
