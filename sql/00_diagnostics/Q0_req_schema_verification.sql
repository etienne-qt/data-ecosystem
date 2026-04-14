/* ============================================================
   Q0 — REQ SCHEMA VERIFICATION
   ============================================================
   Run this BEFORE executing the pipeline (31 → 32 → 51 → 63R → 70).
   It validates that the actual Snowflake schema matches what the
   pipeline expects, and surfaces sample values for key columns.

   Database: DEV_DATAMART.ENTREPRISES_DU_QUEBEC
   Run each section individually. Results inform the pipeline rewrite.

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-07
   ============================================================ */


/* ----------------------------------------------------------
   1. ROW COUNTS
   How many companies in each table?
   ---------------------------------------------------------- */

SELECT 'ENTREPRISES_EN_FONCTION' AS tbl, COUNT(*) AS n
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION
UNION ALL
SELECT 'REGISTRE_ADRESSES', COUNT(*)
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_ADRESSES
UNION ALL
SELECT 'REGISTRE_NOMS', COUNT(*)
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS;


/* ----------------------------------------------------------
   2. FORME_JURIDIQUE — what values exist?
   We assumed 'CIE' = corporation. Actual values may differ.
   ---------------------------------------------------------- */

SELECT
    FORME_JURIDIQUE,
    COUNT(*) AS n
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION
GROUP BY FORME_JURIDIQUE
ORDER BY n DESC
LIMIT 30;


/* ----------------------------------------------------------
   3. N_EMPLOYES — what values exist?
   We assumed letter brackets (A/B/C...). May be ranges or text.
   ---------------------------------------------------------- */

SELECT
    N_EMPLOYES,
    COUNT(*) AS n
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION
GROUP BY N_EMPLOYES
ORDER BY n DESC
LIMIT 30;


/* ----------------------------------------------------------
   4. SECTEUR_ACTIVITE_PRINCIPAL — sample values
   This is the main text field for product classification.
   Is it free text, a code, or a description?
   ---------------------------------------------------------- */

SELECT
    SECTEUR_ACTIVITE_PRINCIPAL,
    COUNT(*) AS n
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION
WHERE SECTEUR_ACTIVITE_PRINCIPAL IS NOT NULL
GROUP BY SECTEUR_ACTIVITE_PRINCIPAL
ORDER BY n DESC
LIMIT 50;


/* ----------------------------------------------------------
   5. REGISTRE_ADRESSES — sample ADRESSE values
   Is it a full address string? Is city extractable?
   Also check CAE_PRIMAIRE range.
   ---------------------------------------------------------- */

SELECT ADRESSE
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_ADRESSES
WHERE ADRESSE IS NOT NULL
LIMIT 20;

SELECT
    MIN(CAE_PRIMAIRE) AS cae_min,
    MAX(CAE_PRIMAIRE) AS cae_max,
    COUNT(DISTINCT CAE_PRIMAIRE) AS distinct_cae,
    COUNT(*) AS total_rows,
    SUM(IFF(CAE_PRIMAIRE IS NULL, 1, 0)) AS null_cae
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_ADRESSES;


/* ----------------------------------------------------------
   6. REGISTRE_NOMS — name structure
   What STATUT and TYPE_NOM values exist?
   Need to know how to pick the current active name.
   ---------------------------------------------------------- */

SELECT STATUT, TYPE_NOM, COUNT(*) AS n
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS
GROUP BY STATUT, TYPE_NOM
ORDER BY n DESC
LIMIT 20;

-- Sample names to verify NOM_ASSUJ format
SELECT NEQ, NOM_ASSUJ, NOM_ASSUJ_LANG_ETRNG, STATUT, TYPE_NOM,
       DAT_INIT_NOM_ASSUJ, DAT_FIN_NOM_ASSUJ
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS
LIMIT 20;


/* ----------------------------------------------------------
   7. DATE_IMMATRICULATION — range check
   Verify the date format and year distribution.
   ---------------------------------------------------------- */

SELECT
    YEAR(DATE_IMMATRICULATION) AS inc_year,
    COUNT(*) AS n
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION
WHERE DATE_IMMATRICULATION IS NOT NULL
GROUP BY inc_year
ORDER BY inc_year DESC
LIMIT 20;

-- How many null / unparseable dates?
SELECT
    SUM(IFF(DATE_IMMATRICULATION IS NULL, 1, 0)) AS null_dates,
    COUNT(*) AS total
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION;


/* ----------------------------------------------------------
   8. DEV_QUEBECTECH DATABASE — does it exist?
   The pipeline writes output tables here.
   ---------------------------------------------------------- */

SHOW DATABASES LIKE 'DEV_QUEBECTECH';

-- If it exists, check for SILVER / GOLD / UTIL schemas:
-- SELECT schema_name FROM DEV_QUEBECTECH.INFORMATION_SCHEMA.SCHEMATA;


/* ----------------------------------------------------------
   9. UTIL UDFs — do NORM_NEQ, NORM_NAME, NAME_SIM exist?
   The pipeline relies on these for normalized matching.
   ---------------------------------------------------------- */

SHOW USER FUNCTIONS IN DATABASE DEV_QUEBECTECH;
-- If this fails (DEV_QUEBECTECH doesn't exist), we'll inline
-- the normalization logic directly in the SQL.


/* ----------------------------------------------------------
   10. NEQ JOIN COVERAGE — how many EF companies have addresses + names?
   ---------------------------------------------------------- */

SELECT
    COUNT(DISTINCT ef.NEQ)                                AS total_ef,
    COUNT(DISTINCT ra.NEQ)                                AS has_address,
    COUNT(DISTINCT rn.NEQ)                                AS has_name,
    COUNT(DISTINCT CASE WHEN ra.NEQ IS NOT NULL
                         AND rn.NEQ IS NOT NULL THEN ef.NEQ END) AS has_both
FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION ef
LEFT JOIN DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_ADRESSES ra ON ef.NEQ = ra.NEQ
LEFT JOIN DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS rn ON ef.NEQ = rn.NEQ;
