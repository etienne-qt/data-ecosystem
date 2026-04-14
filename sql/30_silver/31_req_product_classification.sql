/* ============================================================
   31 — REQ PRODUCT CLASSIFICATION (Silver Layer)
   ============================================================
   Classifies every active company from the Quebec Business Registry
   (REQ) as PRODUCT or SERVICE using keyword scoring on the REQ
   sector description fields and CAE economic activity codes.

   This is a Silver-layer enrichment, analogous to:
     - DRM_STARTUP_CLASSIFICATION_SILVER (Dealroom classification)
     - DRM_INDUSTRY_SIGNALS_SILVER (industry tagging)

   Input:
     - DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION
       (730,446 rows — active companies, no status filter needed)
     - DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_ADRESSES
       (770,132 rows — one address per NEQ selected via QUALIFY)

   Output:
     - DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION

   Changes from original (2026-03-30):
     Rewritten 2026-04-07 to target the verified Snowflake schema.
     REQ_CANONICAL and REF schema are replaced by ENTREPRISES_EN_FONCTION.
     Column mapping: DAT_CONSTI → DATE_IMMATRICULATION, COD_FORME_JURI →
     FORME_JURIDIQUE (full text), COD_INTVAL_EMPLO_QUE / EMPLOYEE_BRACKET →
     N_EMPLOYES (text ranges), DESC_ACT_ECON_ASSUJ → SECTEUR_ACTIVITE_PRINCIPAL,
     CAE source moved to REGISTRE_ADRESSES.CAE_PRIMAIRE.
     Added sector allowlist CTE for known REQ tech sector labels (+3 boost).
     Added HQ_CITY extraction from REGISTRE_ADRESSES.ADRESSE.
     Added EMP_MIN numeric mapping from N_EMPLOYES text ranges.
     NOTE: Step 32 (successor chain) is intentionally omitted —
     ENTREPRISES_EN_FONCTION contains only active/en-fonction companies,
     so there are no radiated companies requiring successor chain resolution.

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-07
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;

CREATE SCHEMA IF NOT EXISTS DEV_QUEBECTECH.SILVER;

/* ----------------------------------------------------------
   Q0: VERIFY COLUMNS (run once, comment out for prod)
   ---------------------------------------------------------- */
-- SELECT column_name, data_type
-- FROM DEV_DATAMART.INFORMATION_SCHEMA.COLUMNS
-- WHERE table_schema = 'ENTREPRISES_DU_QUEBEC'
--   AND table_name IN ('ENTREPRISES_EN_FONCTION', 'REGISTRE_ADRESSES')
-- ORDER BY table_name, ordinal_position;


/* ----------------------------------------------------------
   SILVER TABLE
   ---------------------------------------------------------- */
CREATE OR REPLACE TABLE DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION AS

/* ----------------------------------------------------------
   CTE 1: Base registry — one row per active company
   No status filter needed: ENTREPRISES_EN_FONCTION is already
   filtered to active (en fonction) companies only.
   ---------------------------------------------------------- */
WITH registry AS (
    SELECT
        NEQ,
        UTIL.NORM_NEQ(NEQ::VARCHAR)                          AS NEQ_NORM,
        FORME_JURIDIQUE,
        DATE_IMMATRICULATION,
        YEAR(DATE_IMMATRICULATION)                           AS INCORPORATION_YEAR,
        N_EMPLOYES,
        -- Map text employee bracket to numeric minimum for sorting/filtering
        CASE N_EMPLOYES
            WHEN 'Aucun'          THEN 0
            WHEN 'De 1 à 5'       THEN 1
            WHEN 'De 6 à 10'      THEN 6
            WHEN 'De 11 à 25'     THEN 11
            WHEN 'De 26 à 49'     THEN 26
            WHEN 'De 50 à 99'     THEN 50
            WHEN 'De 100 à 249'   THEN 100
            WHEN 'De 250 à 499'   THEN 250
            WHEN 'De 500 à 749'   THEN 500
            WHEN 'De 750 à 999'   THEN 750
            WHEN 'De 1000 à 2499' THEN 1000
            WHEN 'De 2500 à 4999' THEN 2500
            WHEN 'Plus de 5000'   THEN 5000
            ELSE -1  -- 'Non déclaré' and any unrecognised value
        END                                                  AS EMP_MIN,
        ANNEE_DERNIERE_PRODUCTION_DECLARATION_IMPOT,
        -- Primary sector: SECTEUR_ACTIVITE_PRINCIPAL is the standardized
        -- REQ label equivalent to the old DESC_ACT_ECON_ASSUJ
        LOWER(TRIM(COALESCE(SECTEUR_ACTIVITE_PRINCIPAL, ''))) AS DESC_LOWER,
        LOWER(TRIM(COALESCE(SECTEUR_ACTIVITE_SECONDAIRE, ''))) AS DESC2_LOWER,
        SECTEUR_ACTIVITE_PRINCIPAL                           AS DESCRIPTION_RAW
    FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.ENTREPRISES_EN_FONCTION
),

/* ----------------------------------------------------------
   CTE 2: One address per NEQ from REGISTRE_ADRESSES
   QUALIFY picks the address with the lowest non-null CAE_PRIMAIRE.
   Falls back to any row if all CAE_PRIMAIRE are null.
   ---------------------------------------------------------- */
addresses AS (
    SELECT
        NEQ,
        CAE_PRIMAIRE,
        CAE_SECONDAIRE,
        ADRESSE,
        -- Extract city from address format:
        -- "101B boul. du Portage, Port-Cartier (Québec), G5B1C9"
        TRIM(REGEXP_SUBSTR(ADRESSE, ',\\s*([^(]+)\\s*\\(Québec\\)', 1, 1, 'e', 1)) AS HQ_CITY
    FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_ADRESSES
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY NEQ
        ORDER BY
            IFF(CAE_PRIMAIRE IS NOT NULL, 0, 1),  -- prefer non-null CAE
            CAE_PRIMAIRE ASC NULLS LAST
    ) = 1
),

/* ----------------------------------------------------------
   CTE 3: Join registry + addresses
   ---------------------------------------------------------- */
with_address AS (
    SELECT
        r.*,
        a.CAE_PRIMAIRE                                       AS CAE_CODE,
        a.CAE_SECONDAIRE                                     AS CAE_CODE_2,
        a.HQ_CITY,
        CONCAT(r.DESC_LOWER, ' ', r.DESC2_LOWER)            AS DESC_ALL,
        -- Boolean: has meaningful sector description
        (r.DESC_LOWER != '' AND r.DESC_LOWER != '-'
         AND r.DESC_LOWER != 'non déclaré')                  AS HAS_DESC
    FROM registry r
    LEFT JOIN addresses a ON r.NEQ = a.NEQ
),

/* ----------------------------------------------------------
   CTE 4: Sector allowlist — known REQ tech sector labels
   Boosts KEYWORD_SCORE by +3 for companies whose primary
   sector description contains recognized tech-sector terms.
   Partial, case-insensitive matching via ILIKE patterns.
   ---------------------------------------------------------- */
sector_boost AS (
    SELECT
        NEQ,
        CASE WHEN (
               DESC_LOWER ILIKE '%logiciel%'
            OR DESC_LOWER ILIKE '%informatique%'
            OR DESC_LOWER ILIKE '%numérique%'
            OR DESC_LOWER ILIKE '%technolog%'
            OR DESC_LOWER ILIKE '%intelligence artificielle%'
            OR DESC_LOWER ILIKE '%biotechnolog%'
            OR DESC_LOWER ILIKE '%pharmaceut%'
            OR DESC_LOWER ILIKE '%médical%'
            OR DESC_LOWER ILIKE '%jeux vidéo%'
            OR DESC_LOWER ILIKE '%jeu vidéo%'
            OR DESC_LOWER ILIKE '%aérospatial%'
            OR DESC_LOWER ILIKE '%robotiq%'
            OR DESC_LOWER ILIKE '%nanotechnolog%'
            OR DESC_LOWER ILIKE '%télécommunication%'
            OR DESC_LOWER ILIKE '%photoniq%'
            OR DESC_LOWER ILIKE '%quantiq%'
            OR DESC_LOWER ILIKE '%cybersécurité%'
            OR DESC_LOWER ILIKE '%cybersecurit%'
            OR DESC_LOWER ILIKE '%intelligence d''affaires%'
            OR DESC_LOWER ILIKE '%analytique%'
            OR DESC_LOWER ILIKE '%données%'
            OR DESC_LOWER ILIKE '%infonuagique%'
            OR DESC_LOWER ILIKE '%cloud%'
        ) THEN TRUE ELSE FALSE END                           AS IS_TECH_SECTOR,
        3                                                    AS TECH_SECTOR_BOOST
    FROM with_address
),

/* ----------------------------------------------------------
   CTE 5: SERVICE EXCLUSION PATTERNS
   Identifies companies whose description strongly suggests
   IT services/consulting rather than product development.
   ---------------------------------------------------------- */
service_flagged AS (
    SELECT
        wa.*,
        sb.IS_TECH_SECTOR,
        sb.TECH_SECTOR_BOOST,
        CASE WHEN wa.HAS_DESC AND (
               REGEXP_LIKE(wa.DESC_LOWER, 'consult[a-z0-9_]+ (en |informatiq|technolog|ti|it|gestion)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'conseil[a-z0-9_]* (en |informatiq|technolog|ti|stratég)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'services?\\s*-?\\s*conseil')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'consultation?.{0,20}(informatiq|technolog|ti|it|gestion)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'it consulting|it\\s+consult[a-z0-9_]+|software.?consult[a-z0-9_]+')
            OR REGEXP_LIKE(wa.DESC_LOWER, '^services?\\s+informatiq|^gestion\\s+informatiq|^soutien\\s+(informatiq|technique)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'services? (informatiques?|techniques?|technologiques?)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'infogérance|managed\\s+(service|it)|support\\s+(informatiq|technique|it|ti)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'maintenance\\s+(informatiq|de système|de réseau|logiciel)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'dépannage\\s+informatiq|réparation\\s+(d.ordinat|informatiq)')
            OR REGEXP_LIKE(wa.DESC_LOWER, '^(développement|création|conception)\\s+(de\\s+)?(sites?\\s+web|sites?\\s+internet)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'web\\s+(design|development)|website\\s+(design|development)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'agence.{0,20}(web|numérique|digital|marketing|communication|publicité)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'marketing\\s+(web|numérique|digital|en ligne)|référencement|seo')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'intégration\\s+(de\\s+)?(systèmes?|erp|crm|sap)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'implantation\\s+(de\\s+)?(systèmes?|erp|crm|sap)')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'vente\\s+(et\\s+service\\s+)?d.ordinateur')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'vente\\s+(de\\s+)?(matériel|équipement)\\s+informatiq')
            OR REGEXP_LIKE(wa.DESC_LOWER, 'revendeur|négociant\\s+(de\\s+)?(matériel|équipement)')
            OR REGEXP_LIKE(wa.DESC_LOWER, '^formation\\s+(en\\s+)?(informatiq|technolog|numérique)')
            OR REGEXP_LIKE(wa.DESC_LOWER, '^(conception|création)\\s+graphi[a-z0-9_]+|design\\s+graphi[a-z0-9_]+')
            OR REGEXP_LIKE(wa.DESC_LOWER, '^services?\\s+(aux\\s+)?entreprises?|^prestations?\\s+de\\s+services?')
        ) THEN TRUE ELSE FALSE END AS IS_SERVICE
    FROM with_address wa
    JOIN sector_boost sb ON wa.NEQ = sb.NEQ
),

/* ----------------------------------------------------------
   CTE 6: PRODUCT SIGNAL SCORING
   Each signal contributes a point value. Scores are summed
   in the next CTE. Patterns match against DESC_ALL which
   concatenates primary + secondary sector descriptions.
   ---------------------------------------------------------- */
scored AS (
    SELECT
        s.*,

        -- Strong signals (4–5 pts)
        IFF(REGEXP_LIKE(DESC_ALL, 'saas|en tant que service|as a service'), 5, 0)                                 AS S_SAAS,
        IFF(REGEXP_LIKE(DESC_ALL, 'édition\\s+(de\\s+)?(logiciel|progiciel)|éditeur\\s+(de\\s+)?(logiciel|progiciel)'), 5, 0) AS S_PUBLISHER,
        IFF(REGEXP_LIKE(DESC_ALL, 'commercialis[a-z0-9_]+\\s+(de\\s+|d.un|d.une)?(logiciel|progiciel|plateforme|solution|produit|application)'), 5, 0) AS S_COMMERCIALIZE,
        IFF(REGEXP_LIKE(DESC_ALL, 'développement\\s+et\\s+(commercialisation|exploitation|vente)\\s+(de|d)'), 5, 0) AS S_BUILD_SELL,
        IFF(REGEXP_LIKE(DESC_ALL, 'développ[a-z0-9_]+\\s+et\\s+exploit[a-z0-9_]+\\s+(d.un|d.une|de\\s+(la|sa|son))\\s+(plateforme|logiciel|application|solution)'), 5, 0) AS S_BUILD_OPERATE,
        IFF(REGEXP_LIKE(DESC_ALL, 'intelligence artificielle|artificial intelligence'), 4, 0)                            AS S_AI,
        IFF(REGEXP_LIKE(DESC_ALL, 'machine learning|apprentissage\\s+(automatique|profond|machine)|deep learning'), 4, 0) AS S_ML,
        IFF(REGEXP_LIKE(DESC_ALL, 'genai|gen\\s*ai|ia générati[a-z0-9_]+'), 5, 0)                                             AS S_GENAI,
        IFF(REGEXP_LIKE(DESC_ALL, 'biotechnolog[a-z0-9_]+|biotech|sciences?\\s+de\\s+la\\s+vie'), 4, 0)                  AS S_BIOTECH,
        IFF(REGEXP_LIKE(DESC_ALL, 'génomiq[a-z0-9_]+|protéomiq[a-z0-9_]+|bioinformatiq[a-z0-9_]+|biologie\\s+synthétiq'), 4, 0)            AS S_GENOMICS,
        IFF(REGEXP_LIKE(DESC_ALL, 'dispositif[a-z0-9_]*\\s+médica[a-z0-9_]+'), 5, 0)                                                AS S_MEDTECH,
        IFF(REGEXP_LIKE(DESC_ALL, 'essai[a-z0-9_]*\\s+cliniq[a-z0-9_]+|médicament|molécule|thérapeutiq[a-z0-9_]+'), 4, 0)            AS S_PHARMA,
        IFF(REGEXP_LIKE(DESC_ALL, 'télémédecine|santé\\s+numérique'), 4, 0)                                             AS S_DIGITAL_HEALTH,
        IFF(REGEXP_LIKE(DESC_ALL, 'jeu[a-z0-9_]*\\s+vidéo[a-z0-9_]*|jeu[a-z0-9_]*\\s+video[a-z0-9_]*|gaming|studio\\s+de\\s+jeux'), 4, 0) AS S_GAMING,
        IFF(REGEXP_LIKE(DESC_ALL, 'réalité\\s+(augmentée|virtuelle|mixte)|métavers'), 4, 0)                           AS S_XR,
        IFF(REGEXP_LIKE(DESC_ALL, 'quantiq[a-z0-9_]+.{0,20}(ordinateur|comput|informatique|technolog)|quantum.{0,20}(comput|technolog)'), 5, 0) AS S_QUANTUM,
        IFF(REGEXP_LIKE(DESC_ALL, 'nanotechnolog[a-z0-9_]+'), 4, 0)                                                           AS S_NANOTECH,
        IFF(REGEXP_LIKE(DESC_ALL, 'semi.?conducteur[a-z0-9_]*|semiconductor[a-z0-9_]*|puce[a-z0-9_]*\\s+électroniq|circuit[a-z0-9_]*\\s+intégré'), 4, 0) AS S_SEMICONDUCTOR,
        IFF(REGEXP_LIKE(DESC_ALL, 'photoniq[a-z0-9_]+'), 4, 0)                                                                AS S_PHOTONICS,
        IFF(REGEXP_LIKE(DESC_ALL, 'drone[a-z0-9_]*'), 4, 0)                                                                AS S_DRONE,
        IFF(REGEXP_LIKE(DESC_ALL, 'objets?\\s+connectés?|internet\\s+des\\s+objets|capteur[a-z0-9_]*\\s+intelligent|système[a-z0-9_]*\\s+embarqué'), 4, 0) AS S_IOT,
        IFF(REGEXP_LIKE(DESC_ALL, 'robotiq[a-z0-9_]+|robot.{0,20}(industriel|collaborat|autonom|mobile|chirurg)'), 4, 0)  AS S_ROBOTICS,
        IFF(REGEXP_LIKE(DESC_ALL, 'fintech|technologie\\s+financière|assurtech|insurtech|regtech'), 4, 0)          AS S_FINTECH,
        IFF(REGEXP_LIKE(DESC_ALL, 'blockchain|chaîne\\s+de\\s+blocs|cryptomonnaie|contrat\\s+intelligent|smart\\s+contract|nft|web3'), 4, 0) AS S_BLOCKCHAIN,
        IFF(REGEXP_LIKE(DESC_ALL, 'cleantech|technologies?\\s+propres?|stockage\\s+d.énergie|borne\\s+de\\s+recharge|véhicule\\s+électrique|mobilité\\s+électrique'), 4, 0) AS S_CLEANTECH,
        IFF(REGEXP_LIKE(DESC_ALL, 'cybersécurité|cybersecurite|sécurité\\s+informatique|chiffrement|cryptographi[a-z0-9_]+'), 3, 0) AS S_CYBERSECURITY,
        IFF(REGEXP_LIKE(DESC_ALL, 'agritech|agrotech|agriculture\\s+(de\\s+)?précision'), 4, 0)                       AS S_AGRITECH,
        IFF(REGEXP_LIKE(DESC_ALL, 'proptech|bâtiment\\s+intelligent|construction\\s+4\\.0'), 4, 0)                      AS S_PROPTECH,
        IFF(REGEXP_LIKE(DESC_ALL, 'edtech|éducation\\s+en\\s+ligne|e-learning|apprentissage\\s+en\\s+ligne'), 3, 0)     AS S_EDTECH,

        -- Moderate signals (2–3 pts)
        IFF(REGEXP_LIKE(DESC_ALL, 'progiciel'), 3, 0)                                                            AS S_PROGICIEL,
        IFF(REGEXP_LIKE(DESC_ALL, 'logiciel.{0,30}(gestion|intégré|erp|spécialisé|propriétaire)|production\\s+de\\s+logiciel|fabrication\\s+de\\s+logiciel'), 3, 0) AS S_OWN_SOFTWARE,
        IFF(REGEXP_LIKE(DESC_ALL, 'plateforme.{0,30}(permettant|qui\\s+permet|facilitant|reliant|connectant)'), 5, 0) AS S_PLATFORM_PRODUCT,
        IFF(REGEXP_LIKE(DESC_ALL, 'plateforme.{0,20}(numérique|technologique|en\\s+ligne|web|saas|cloud|infonuagique)'), 3, 0) AS S_PLATFORM,
        IFF(REGEXP_LIKE(DESC_ALL, 'marketplace|place\\s+de\\s+marché'), 4, 0)                                           AS S_MARKETPLACE,
        IFF(REGEXP_LIKE(DESC_ALL, 'infonuagiq[a-z0-9_]+|cloud.{0,20}(solution|produit|plateforme|logiciel)'), 3, 0)      AS S_CLOUD,
        IFF(REGEXP_LIKE(DESC_ALL, 'data.{0,20}(analytics|platform|solution|produit)|données.{0,20}(plateforme|solution|analyse|produit)'), 3, 0) AS S_DATA,
        IFF(REGEXP_LIKE(DESC_ALL, 'automatis[a-z0-9_]+.{0,20}(industriel|processus|manufactur|logiciel|solution|système)'), 3, 0) AS S_AUTOMATION,
        IFF(REGEXP_LIKE(DESC_ALL, 'aérospatial[a-z0-9_]+|satellite|télédétection|géospatial[a-z0-9_]+'), 3, 0)               AS S_AEROSPACE,

        -- CAE code score (from REGISTRE_ADRESSES.CAE_PRIMAIRE)
        CASE
            WHEN CAE_CODE IN (2851)                     THEN 3
            WHEN CAE_CODE IN (3361)                     THEN 3
            WHEN CAE_CODE IN (3740, 3741)               THEN 3
            WHEN CAE_CODE IN (3910)                     THEN 3
            WHEN CAE_CODE IN (3350, 3351, 3352)         THEN 3
            ELSE 0
        END AS S_CAE_STRONG,

        CASE
            WHEN CAE_CODE IN (2851,3361,3740,3741,3910,3350,3351,3352,3359,3340,3341,3300,4823) THEN 2
            ELSE 0
        END AS S_CAE_BOOST

    FROM service_flagged s
),

/* ----------------------------------------------------------
   CTE 7: AGGREGATE SCORES + FINAL CLASSIFICATION
   Sector allowlist boost (+3) is applied to KEYWORD_SCORE here.
   ---------------------------------------------------------- */
final AS (
    SELECT
        NEQ,
        NEQ_NORM,
        FORME_JURIDIQUE,
        DATE_IMMATRICULATION,
        INCORPORATION_YEAR,
        N_EMPLOYES,
        EMP_MIN,
        CAE_CODE,
        CAE_CODE_2,
        HQ_CITY,
        DESCRIPTION_RAW,
        HAS_DESC,
        IS_SERVICE,
        IS_TECH_SECTOR,

        -- Raw keyword score (sum all signals)
        (S_SAAS + S_PUBLISHER + S_COMMERCIALIZE + S_BUILD_SELL + S_BUILD_OPERATE
         + S_AI + S_ML + S_GENAI + S_BIOTECH + S_GENOMICS + S_MEDTECH + S_PHARMA + S_DIGITAL_HEALTH
         + S_GAMING + S_XR + S_QUANTUM + S_NANOTECH + S_SEMICONDUCTOR + S_PHOTONICS + S_DRONE
         + S_IOT + S_ROBOTICS + S_FINTECH + S_BLOCKCHAIN + S_CLEANTECH + S_CYBERSECURITY
         + S_AGRITECH + S_PROPTECH + S_EDTECH
         + S_PROGICIEL + S_OWN_SOFTWARE + S_PLATFORM_PRODUCT + S_PLATFORM + S_MARKETPLACE
         + S_CLOUD + S_DATA + S_AUTOMATION + S_AEROSPACE
         -- Sector allowlist boost: +3 if company is in a known REQ tech sector
         + IFF(IS_TECH_SECTOR, TECH_SECTOR_BOOST, 0)
        ) AS KEYWORD_SCORE,

        S_CAE_STRONG,
        S_CAE_BOOST,

        -- Human-readable signal list for debugging / enrichment review
        ARRAY_TO_STRING(ARRAY_COMPACT(ARRAY_CONSTRUCT(
            IFF(S_SAAS>0,'saas',NULL), IFF(S_PUBLISHER>0,'publisher',NULL), IFF(S_COMMERCIALIZE>0,'commercialize',NULL),
            IFF(S_BUILD_SELL>0,'build_sell',NULL), IFF(S_BUILD_OPERATE>0,'build_operate',NULL),
            IFF(S_AI>0,'ai',NULL), IFF(S_ML>0,'ml',NULL), IFF(S_GENAI>0,'genai',NULL),
            IFF(S_BIOTECH>0,'biotech',NULL), IFF(S_GENOMICS>0,'genomics',NULL), IFF(S_MEDTECH>0,'medtech',NULL),
            IFF(S_PHARMA>0,'pharma',NULL), IFF(S_DIGITAL_HEALTH>0,'digital_health',NULL),
            IFF(S_GAMING>0,'gaming',NULL), IFF(S_XR>0,'xr',NULL),
            IFF(S_QUANTUM>0,'quantum',NULL), IFF(S_NANOTECH>0,'nanotech',NULL),
            IFF(S_SEMICONDUCTOR>0,'semiconductor',NULL), IFF(S_PHOTONICS>0,'photonics',NULL), IFF(S_DRONE>0,'drone',NULL),
            IFF(S_IOT>0,'iot',NULL), IFF(S_ROBOTICS>0,'robotics',NULL),
            IFF(S_FINTECH>0,'fintech',NULL), IFF(S_BLOCKCHAIN>0,'blockchain',NULL),
            IFF(S_CLEANTECH>0,'cleantech',NULL), IFF(S_CYBERSECURITY>0,'cybersecurity',NULL),
            IFF(S_AGRITECH>0,'agritech',NULL), IFF(S_PROPTECH>0,'proptech',NULL), IFF(S_EDTECH>0,'edtech',NULL),
            IFF(S_PROGICIEL>0,'progiciel',NULL), IFF(S_OWN_SOFTWARE>0,'own_software',NULL),
            IFF(S_PLATFORM_PRODUCT>0,'platform_product',NULL), IFF(S_PLATFORM>0,'platform',NULL),
            IFF(S_MARKETPLACE>0,'marketplace',NULL), IFF(S_CLOUD>0,'cloud',NULL),
            IFF(S_DATA>0,'data',NULL), IFF(S_AUTOMATION>0,'automation',NULL), IFF(S_AEROSPACE>0,'aerospace',NULL),
            IFF(S_CAE_STRONG>0,'cae_strong',NULL),
            IFF(IS_TECH_SECTOR,'tech_sector',NULL)
        )), ', ') AS MATCHED_SIGNALS,

        -- IS_PRODUCT classification
        CASE
            WHEN IS_SERVICE AND KEYWORD_SCORE >= 4 THEN TRUE
            WHEN IS_SERVICE THEN FALSE
            WHEN KEYWORD_SCORE >= 4 THEN TRUE
            WHEN KEYWORD_SCORE >= 1 AND KEYWORD_SCORE + S_CAE_BOOST >= 3 THEN TRUE
            WHEN KEYWORD_SCORE >= 3 THEN TRUE
            WHEN S_CAE_STRONG > 0 THEN TRUE
            ELSE FALSE
        END AS IS_PRODUCT,

        -- PRODUCT_SCORE
        CASE
            WHEN IS_SERVICE AND KEYWORD_SCORE >= 4 THEN KEYWORD_SCORE
            WHEN NOT IS_SERVICE AND KEYWORD_SCORE > 0 THEN KEYWORD_SCORE + IFF(S_CAE_BOOST > 0, S_CAE_BOOST, 0)
            WHEN S_CAE_STRONG > 0 THEN S_CAE_STRONG
            ELSE 0
        END AS PRODUCT_SCORE,

        -- PRODUCT_TIER
        CASE
            WHEN IS_SERVICE AND KEYWORD_SCORE < 4 THEN 'EXCLUDED_SERVICE'
            WHEN KEYWORD_SCORE >= 6 OR (KEYWORD_SCORE >= 4 AND S_CAE_BOOST > 0) THEN 'HIGH'
            WHEN KEYWORD_SCORE >= 3 OR S_CAE_STRONG > 0 THEN 'MEDIUM'
            WHEN KEYWORD_SCORE >= 1 AND S_CAE_BOOST > 0 THEN 'MEDIUM'
            WHEN KEYWORD_SCORE > 0 THEN 'LOW'
            ELSE 'NONE'
        END AS PRODUCT_TIER,

        CURRENT_TIMESTAMP() AS CLASSIFIED_AT

    FROM scored
)

SELECT * FROM final;

-- Cluster key for fast lookup by tier and normalized NEQ
ALTER TABLE DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
  CLUSTER BY (IS_PRODUCT, PRODUCT_TIER, NEQ_NORM);


/* ----------------------------------------------------------
   VALIDATION
   ---------------------------------------------------------- */

-- Row count and IS_PRODUCT split
SELECT
    COUNT(*)                              AS TOTAL_ROWS,
    SUM(IFF(IS_PRODUCT, 1, 0))           AS PRODUCT_COUNT,
    SUM(IFF(NOT IS_PRODUCT, 1, 0))       AS NON_PRODUCT_COUNT,
    SUM(IFF(IS_TECH_SECTOR, 1, 0))       AS TECH_SECTOR_BOOST_APPLIED,
    SUM(IFF(IS_SERVICE, 1, 0))           AS EXCLUDED_SERVICE_COUNT
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION;

-- Tier distribution
SELECT PRODUCT_TIER, COUNT(*) AS N
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
GROUP BY PRODUCT_TIER
ORDER BY PRODUCT_TIER;

-- Legal form breakdown among IS_PRODUCT = TRUE
SELECT FORME_JURIDIQUE, COUNT(*) AS N
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
WHERE IS_PRODUCT = TRUE
GROUP BY FORME_JURIDIQUE
ORDER BY N DESC;

-- Top 10 HQ cities among product companies
SELECT HQ_CITY, COUNT(*) AS N
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
WHERE IS_PRODUCT = TRUE AND HQ_CITY IS NOT NULL
GROUP BY HQ_CITY
ORDER BY N DESC
LIMIT 10;
