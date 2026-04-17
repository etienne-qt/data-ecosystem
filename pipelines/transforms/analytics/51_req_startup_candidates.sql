/* ============================================================
   51 — REQ STARTUP CANDIDATES (Gold Layer)
   ============================================================
   Two Gold-layer tables from the Silver classification:

   a) GOLD.REQ_STARTUP_CANDIDATES (strict)
      For net-new discovery: Société par actions, 2010+,
      has declared employees (not 'Aucun' or 'Non déclaré').

   b) GOLD.REQ_STARTUP_UNIVERSE (relaxed)
      For cross-referencing against HS / Dealroom / RC:
      includes Coopérative form, allows 'Aucun' employees
      if PRODUCT_SCORE >= 4, no date cutoff.

   Input:  SILVER.REQ_PRODUCT_CLASSIFICATION (from step 31)
           DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS

   Output: GOLD.REQ_STARTUP_CANDIDATES
           GOLD.REQ_STARTUP_UNIVERSE

   Changes from original (2026-04-01):
     Rewritten 2026-04-07 to match verified Snowflake schema.
     Company names now joined from REGISTRE_NOMS using the
     correct QUALIFY pattern (STATUT, TYPE_NOM, DAT_INIT_NOM_ASSUJ).
     Legal form filter updated from code 'CIE' to full text value
     'Société par actions ou compagnie'.
     Employee filter updated from bracket codes (O/N/P) to text
     values ('Aucun', 'Non déclaré').
     Relaxed view now includes 'Coopérative' as allowed legal form.
     COD_STAT_IMMAT / radiated status flags removed — source table
     ENTREPRISES_EN_FONCTION contains only active companies.
     HQ_CITY column passed through from step 31.
     NOTE: Step 32 (successor chain) is dropped — not applicable
     when source is ENTREPRISES_EN_FONCTION (active only).

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-07
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;

CREATE SCHEMA IF NOT EXISTS DEV_QUEBECTECH.GOLD;


/* ----------------------------------------------------------
   Helper: current primary name per company
   Sources: DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS

   Priority order:
     1. Status: 'En vigueur' before 'Antérieur' / 'Futur'
     2. Name type: 'Denomination sociale' > 'Nom' > 'Autre nom'
     3. Most recent start date (DAT_INIT_NOM_ASSUJ DESC)
   ---------------------------------------------------------- */
-- Pre-filter names: remove NULL and empty, then normalize
-- Two-stage approach to avoid JS UDF errors on edge-case inputs
CREATE OR REPLACE TEMPORARY TABLE _TMP_NAMES_RAW AS
SELECT
    NEQ,
    NOM_ASSUJ,
    STATUT,
    TYPE_NOM,
    DAT_INIT_NOM_ASSUJ
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS
WHERE NOM_ASSUJ IS NOT NULL
  AND TRIM(NOM_ASSUJ) != ''
  AND LENGTH(TRIM(NOM_ASSUJ)) >= 2
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY NEQ
    ORDER BY
        IFF(STATUT = 'En vigueur', 0, 1),
        CASE TYPE_NOM
            WHEN 'Denomination sociale' THEN 0
            WHEN 'Nom'                  THEN 1
            ELSE 2
        END,
        DAT_INIT_NOM_ASSUJ DESC
) = 1;

CREATE OR REPLACE TEMPORARY TABLE _TMP_NAMES AS
SELECT
    NEQ,
    NOM_ASSUJ                                                AS COMPANY_NAME_RAW,
    UTIL.NORM_NAME(NOM_ASSUJ)                                AS COMPANY_NAME_NORM,
    UTIL.NAME_KEY(NOM_ASSUJ)                                 AS NAME_KEY,
    SPLIT_PART(UTIL.NORM_NAME(NOM_ASSUJ), ' ', 1)           AS TOK1,
    LEFT(UTIL.NORM_NAME(NOM_ASSUJ), 4)                       AS P4
FROM _TMP_NAMES_RAW;


/* ============================================================
   A) STRICT VIEW — for net-new startup discovery
   ============================================================
   Filters:
     - Société par actions ou compagnie only
     - Incorporated 2010+
     - Has declared employees (excludes 'Aucun', 'Non déclaré')
     - IS_PRODUCT = TRUE
   ============================================================ */

CREATE OR REPLACE TABLE DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES AS
SELECT
    c.NEQ_NORM,
    c.NEQ,
    n.COMPANY_NAME_RAW,
    n.COMPANY_NAME_NORM,
    n.NAME_KEY,
    n.TOK1,
    n.P4,
    c.DESCRIPTION_RAW,
    c.CAE_CODE,
    c.CAE_CODE_2,
    c.HQ_CITY,
    c.DATE_IMMATRICULATION                                   AS INCORPORATION_DATE,
    c.INCORPORATION_YEAR,
    c.N_EMPLOYES,
    c.EMP_MIN,
    c.FORME_JURIDIQUE,
    c.PRODUCT_SCORE,
    c.PRODUCT_TIER,
    c.IS_TECH_SECTOR,
    c.MATCHED_SIGNALS,
    c.CLASSIFIED_AT
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION c
LEFT JOIN _TMP_NAMES n ON c.NEQ = n.NEQ
WHERE c.IS_PRODUCT = TRUE
  AND c.FORME_JURIDIQUE = 'Société par actions ou compagnie'
  AND c.INCORPORATION_YEAR >= 2010
  AND c.N_EMPLOYES NOT IN ('Aucun', 'Non déclaré')
  AND c.N_EMPLOYES IS NOT NULL
;

ALTER TABLE DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES
  CLUSTER BY (PRODUCT_TIER, P4, TOK1, NEQ_NORM);


/* ============================================================
   B) RELAXED VIEW — for cross-referencing and matching
   ============================================================
   Relaxations vs strict:
     - Includes 'Coopérative' in addition to 'Société par actions'
     - No date cutoff (all incorporation years)
     - 'Aucun' employees allowed if PRODUCT_SCORE >= 4
     - 'Non déclaré' employees allowed if PRODUCT_SCORE >= 4
   NOTE: No status filter needed — source table is already
   limited to active (en fonction) companies only.
   ============================================================ */

CREATE OR REPLACE TABLE DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE AS
SELECT
    c.NEQ_NORM,
    c.NEQ,
    n.COMPANY_NAME_RAW,
    n.COMPANY_NAME_NORM,
    n.NAME_KEY,
    n.TOK1,
    n.P4,
    c.DESCRIPTION_RAW,
    c.CAE_CODE,
    c.CAE_CODE_2,
    c.HQ_CITY,
    c.DATE_IMMATRICULATION                                   AS INCORPORATION_DATE,
    c.INCORPORATION_YEAR,
    c.N_EMPLOYES,
    c.EMP_MIN,
    c.FORME_JURIDIQUE,
    c.PRODUCT_SCORE,
    c.PRODUCT_TIER,
    c.IS_TECH_SECTOR,
    c.MATCHED_SIGNALS,

    -- Relaxation flags — explains why this company is in the universe
    -- but would not pass strict filters
    IFF(c.FORME_JURIDIQUE != 'Société par actions ou compagnie',
        TRUE, FALSE)                                         AS FLAG_NON_SA,
    IFF(c.INCORPORATION_YEAR < 2010
        OR c.INCORPORATION_YEAR IS NULL, TRUE, FALSE)        AS FLAG_PRE_2010,
    IFF(c.N_EMPLOYES IN ('Aucun', 'Non déclaré')
        OR c.N_EMPLOYES IS NULL, TRUE, FALSE)                AS FLAG_NO_EMPLOYEES,

    c.CLASSIFIED_AT
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION c
LEFT JOIN _TMP_NAMES n ON c.NEQ = n.NEQ
WHERE c.IS_PRODUCT = TRUE

  -- Legal form: Société par actions + Coopérative
  AND c.FORME_JURIDIQUE IN (
      'Société par actions ou compagnie',
      'Coopérative'
  )

  -- Employees: has declared employees, OR no employees but strong product signal
  AND (
      c.N_EMPLOYES NOT IN ('Aucun', 'Non déclaré')
      AND c.N_EMPLOYES IS NOT NULL
      OR c.PRODUCT_SCORE >= 4
  )
;

ALTER TABLE DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE
  CLUSTER BY (PRODUCT_TIER, P4, TOK1, NEQ_NORM);


/* ----------------------------------------------------------
   VALIDATION
   ---------------------------------------------------------- */

-- Compare counts: strict vs relaxed
SELECT 'STRICT (REQ_STARTUP_CANDIDATES)' AS VIEW_NAME, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES
UNION ALL
SELECT 'RELAXED (REQ_STARTUP_UNIVERSE)' AS VIEW_NAME, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE;

-- Relaxation breakdown — how many companies pass only due to each flag?
SELECT
    SUM(IFF(FLAG_NON_SA,       1, 0)) AS ADMITTED_NON_SA,
    SUM(IFF(FLAG_PRE_2010,     1, 0)) AS ADMITTED_PRE_2010,
    SUM(IFF(FLAG_NO_EMPLOYEES, 1, 0)) AS ADMITTED_NO_EMPLOYEES,
    COUNT(*)                           AS TOTAL_UNIVERSE
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE;

-- Tier distribution for both views
SELECT 'STRICT' AS SRC, PRODUCT_TIER, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES
GROUP BY PRODUCT_TIER
UNION ALL
SELECT 'RELAXED' AS SRC, PRODUCT_TIER, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_UNIVERSE
GROUP BY PRODUCT_TIER
ORDER BY SRC, PRODUCT_TIER;

-- Employee range distribution in strict view
SELECT N_EMPLOYES, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES
GROUP BY N_EMPLOYES
ORDER BY MIN(EMP_MIN);

-- HQ city distribution (top 15, strict)
SELECT HQ_CITY, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.REQ_STARTUP_CANDIDATES
WHERE HQ_CITY IS NOT NULL
GROUP BY HQ_CITY
ORDER BY N DESC
LIMIT 15;
