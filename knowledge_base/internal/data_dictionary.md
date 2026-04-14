# Data Dictionary — Startup Ecosystem Pipeline

Complete reference for all data columns, their sources, transformations, and flow through the pipeline.

---

## Pipeline Architecture

```
Dealroom CSV ──→ Bronze (raw) ──→ Silver (normalized + enriched) ──→ Analytics
HubSpot API  ──→ IMPORT       ──→ Matching / Clustering          ──→ Push views
Quebec Registry ──────────────────→ Registry Bridge                ──→ Enrichment
Website Checks ──→ Bronze       ──→ Silver (status)
```

---

## 1. Bronze Layer — Raw Data Ingestion

### BRONZE.DRM_COMPANY_BRONZE

Raw Dealroom export data with minimal transformation (type casting, array parsing).

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| **Lineage** | | | |
| LOAD_BATCH_ID | string | Generated | UUID per import batch |
| SOURCE_FILE_NAME | string | File metadata | Original CSV/Excel filename |
| LOADED_AT | timestamp_tz | System | File's original load timestamp |
| BRONZE_LOADED_AT | timestamp_tz | System | CURRENT_TIMESTAMP() at bronze processing |
| **Identity** | | | |
| DEALROOM_ID | string | CSV `ID` | Cast to string |
| NAME | string | CSV `Name` | NULLIF_BLANK() |
| DEALROOM_URL | string | CSV `Dealroom URL` | NULLIF_BLANK() |
| WEBSITE | string | CSV `Website` | NULLIF_BLANK() |
| TAGLINE | string | CSV `Tagline` | NULLIF_BLANK() |
| LONG_DESCRIPTION | string | CSV `Long description` | NULLIF_BLANK() |
| **Location** | | | |
| ADDRESS | string | CSV `Address` | NULLIF_BLANK() |
| STREET | string | CSV `Street` | NULLIF_BLANK() |
| STREET_NUMBER | string | CSV `Street number` | NULLIF_BLANK() |
| STREET_FULL | string | CSV `Street and street number` | NULLIF_BLANK() |
| ZIPCODE | string | CSV `Zipcode` | NULLIF_BLANK() |
| HQ_REGION | string | CSV `HQ region` | NULLIF_BLANK() |
| HQ_COUNTRY | string | CSV `HQ country` | NULLIF_BLANK() |
| HQ_STATE | string | CSV `HQ state` | NULLIF_BLANK() |
| HQ_CITY | string | CSV `HQ city` | NULLIF_BLANK() |
| LATITUDE | double | CSV `Latitude` | TRY_TO_DOUBLE_CLEAN() |
| LONGITUDE | double | CSV `Longitude` | TRY_TO_DOUBLE_CLEAN() |
| **Categorization (raw + parsed)** | | | |
| TAGS_RAW | string | CSV `Tags` | Original value |
| TAGS_ARR | variant | TAGS_RAW | SPLIT by detected delimiter (`;` or `,`) |
| INDUSTRIES_RAW | string | CSV `Industries` | Original value |
| INDUSTRIES_ARR | variant | INDUSTRIES_RAW | SPLIT by detected delimiter |
| SUB_INDUSTRIES_RAW | string | CSV `Sub industries` | Original value |
| SUB_INDUSTRIES_ARR | variant | SUB_INDUSTRIES_RAW | SPLIT by detected delimiter |
| INVESTORS_NAMES_RAW | string | CSV `Investors names` | Original value |
| INVESTORS_NAMES_ARR | variant | INVESTORS_NAMES_RAW | SPLIT by detected delimiter |
| **Funding** | | | |
| TOTAL_FUNDING_EUR_M | number(38,6) | CSV `Total funding (EUR M)` | TRY_TO_NUMBER_CLEAN() |
| TOTAL_FUNDING_USD_M | number(38,6) | CSV `Total funding (USD M)` | TRY_TO_NUMBER_CLEAN() |
| LAST_ROUND | string | CSV `Last round` | NULLIF_BLANK() |
| LAST_FUNDING_AMOUNT | number(38,6) | CSV `Last funding amount` | TRY_TO_NUMBER_CLEAN() |
| LAST_FUNDING_DATE | date | CSV `Last funding date` | TRY_TO_DATE_ANY() |
| FIRST_FUNDING_DATE | date | CSV `First funding date` | TRY_TO_DATE_ANY() |
| SEED_YEAR | number(38,0) | CSV `Seed year` | TRY_TO_NUMBER_CLEAN() |
| **Launch / Closing** | | | |
| LAUNCH_YEAR | number(38,0) | CSV `Launch year` | TRY_TO_NUMBER_CLEAN() |
| LAUNCH_MONTH | number(38,0) | CSV `Launch month` | TRY_TO_NUMBER_CLEAN() |
| LAUNCH_DATE | date | CSV `Launch date` | TRY_TO_DATE_ANY() |
| CLOSING_YEAR | number(38,0) | CSV `Closing year` | TRY_TO_NUMBER_CLEAN() |
| CLOSING_MONTH | number(38,0) | CSV `Closing month` | TRY_TO_NUMBER_CLEAN() |
| CLOSING_DATE | date | CSV `Closing date` | TRY_TO_DATE_ANY() |
| **Team / Size** | | | |
| EMPLOYEES_RANGE | string | CSV `Number of employees` | NULLIF_BLANK() |
| EMPLOYEES_LATEST_NUMBER | number(38,0) | CSV `Employees latest` | TRY_TO_NUMBER_CLEAN() |
| **Social Links** | | | |
| LINKEDIN | string | CSV `LinkedIn` | NULLIF_BLANK() |
| TWITTER | string | CSV `Twitter` | NULLIF_BLANK() |
| FACEBOOK | string | CSV `Facebook` | NULLIF_BLANK() |
| CRUNCHBASE | string | CSV `Crunchbase` | NULLIF_BLANK() |
| **Status & Signals** | | | |
| COMPANY_STATUS | string | CSV `Company status` | NULLIF_BLANK() |
| DEALROOM_SIGNAL_RATING | string | CSV `Dealroom Signal - Rating` | NULLIF_BLANK() |
| DEALROOM_SIGNAL_COMPLETENESS | number(38,6) | CSV `Completeness` | TRY_TO_NUMBER_CLEAN() |
| DEALROOM_SIGNAL_TEAM_STRENGTH | number(38,6) | CSV `Team Strength` | TRY_TO_NUMBER_CLEAN() |
| DEALROOM_SIGNAL_GROWTH_RATE | number(38,6) | CSV `Growth Rate` | TRY_TO_NUMBER_CLEAN() |
| DEALROOM_SIGNAL_TIMING | number(38,6) | CSV `Timing` | TRY_TO_NUMBER_CLEAN() |
| **Registry Hints** | | | |
| TRADE_REGISTER_NUMBER | string | CSV `Trade register number` | NULLIF_BLANK() |
| TRADE_REGISTER_NAME | string | CSV `Trade register name` | NULLIF_BLANK() |
| TRADE_REGISTER_URL | string | CSV `Trade register URL` | NULLIF_BLANK() |
| **Debug** | | | |
| PARSE_NOTES | variant | Generated | Delimiter detection metadata for array parsing |

### BRONZE.DRM_WEBSITE_CHECKS_BRONZE

Append-only HTTP check results for company websites.

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| company_id | string NOT NULL | Input | Company identifier (Dealroom ID) |
| checked_at | timestamp_ntz NOT NULL | System | When the check was performed |
| input_url | string | Input | URL submitted for checking |
| input_domain | string | Derived | Domain extracted from input_url |
| final_url | string | HTTP response | URL after following redirects |
| final_domain | string | Derived | Domain extracted from final_url |
| http_status | number(38,0) | HTTP response | HTTP status code (200, 404, etc.) |
| error_type | string | HTTP response | Error category (dns, timeout, connection, etc.) |
| error_message | string | HTTP response | Detailed error message |
| response_time_ms | number(38,0) | HTTP response | Response time in milliseconds |
| num_redirects | number(38,0) | HTTP response | Number of redirects followed |
| is_https | boolean | Derived | Whether final URL uses HTTPS |
| is_valid | boolean | Derived | HTTP status < 400 |
| is_parked | boolean | Derived | Domain is a placeholder/parked page |
| parked_reason | string | Derived | Why the domain was flagged as parked |
| content_sha256 | string | Derived | SHA-256 hash of page content |
| raw_result | variant | Full output | Complete check result as JSON |
| inserted_at | timestamp_ntz | System | DEFAULT CURRENT_TIMESTAMP() |

---

## 2. Silver Layer — Normalized & Enriched

### SILVER.DRM_COMPANY_SILVER

Standardized company data, merged from Bronze + latest import. All raw fields are cleaned and typed.

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| DEALROOM_ID | string | Bronze | Primary key |
| NAME | string | Bronze | Cleaned |
| DEALROOM_URL | string | Bronze | Cleaned |
| WEBSITE | string | Bronze | Cleaned |
| WEBSITE_DOMAIN | string | Derived | DOMAIN_FROM_URL(WEBSITE) — extracts bare domain |
| TAGLINE | string | Bronze | Cleaned |
| LONG_DESCRIPTION | string | Bronze | Cleaned |
| INDUSTRIES_RAW | string | Bronze | Original industries text |
| SUB_INDUSTRIES_RAW | string | Bronze | Original sub-industries text |
| TAGS_RAW | string | Bronze | Original tags text |
| ALL_TAGS_RAW | string | Bronze | All tags combined |
| TECHNOLOGIES_RAW | string | Bronze | Technologies text |
| EACH_INVESTOR_TYPE_RAW | string | Bronze | Investor types text |
| EACH_ROUND_TYPE_RAW | string | Bronze | Funding round types text |
| INVESTORS_NAMES_RAW | string | Bronze | Investor names text |
| LEAD_INVESTORS_RAW | string | Bronze | Lead investors text |
| HQ_COUNTRY | string | Bronze | |
| HQ_STATE | string | Bronze | |
| HQ_CITY | string | Bronze | |
| LATITUDE | double | Bronze | |
| LONGITUDE | double | Bronze | |
| TOTAL_FUNDING_USD_M | number(38,6) | Bronze | |
| TOTAL_FUNDING_EUR_M | number(38,6) | Bronze | |
| LAST_FUNDING_DATE | date | Bronze | |
| FIRST_FUNDING_DATE | date | Bronze | |
| VALUATION_USD | number(38,6) | Bronze/Import | |
| HISTORICAL_VALUATIONS_VALUES_USD_M | string | Bronze/Import | |
| DEALROOM_SIGNAL_RATING_RAW | string | Bronze | Original text rating |
| DEALROOM_SIGNAL_RATING_NUM | number(38,6) | Bronze | Parsed to number |
| DEALROOM_SIGNAL_COMPLETENESS | number(38,6) | Bronze | |
| DEALROOM_SIGNAL_TEAM_STRENGTH | number(38,6) | Bronze | |
| DEALROOM_SIGNAL_GROWTH_RATE | number(38,6) | Bronze | |
| DEALROOM_SIGNAL_TIMING | number(38,6) | Bronze | |
| COMPANY_STATUS | string | Bronze | |
| CLOSING_DATE | date | Bronze | |
| LAUNCH_DATE | date | Bronze | |
| LAUNCH_MONTH | number(38,0) | Bronze | |
| LAUNCH_YEAR | number(38,0) | Bronze | |
| EMPLOYEES_RANGE | string | Bronze | |
| EMPLOYEES_LATEST_NUMBER | number(38,0) | Bronze | |
| TAGS_ARR | variant | Bronze | Parsed array |
| INDUSTRIES_ARR | variant | Bronze | Parsed array |
| SUB_INDUSTRIES_ARR | variant | Bronze | Parsed array |
| INVESTORS_NAMES_ARR | variant | Bronze | Parsed array |
| LOADED_AT | timestamp_tz | Bronze | |
| SILVER_LOADED_AT | timestamp_tz | System | CURRENT_TIMESTAMP() |

### SILVER.DRM_COMPANY_MATCH_TEXT_VW (View)

Composite text field for keyword matching (industry/tech enrichment).

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| DEALROOM_ID | string | DRM_COMPANY_SILVER | |
| MATCH_TEXT | string | Derived | NORMALIZE_TEXT_FOR_MATCHING(MATCH_TEXT_RAW) — accent-folded, lowercased, punctuation→space |
| MATCH_TEXT_RAW | string | Derived | Concatenation of name, tagline, long_description, industries, sub_industries, tags, all_tags, technologies |

### SILVER.DRM_STARTUP_SIGNALS_SILVER

Raw classifier engine output. One row per company.

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| DEALROOM_ID | string | DRM_COMPANY_SILVER | |
| ENGINE_VERSION | string | Constant | `'dealroom_v5_js_udf'` |
| RATING_LETTER | string | Classifier UDF | A+, A, B, C, or D |
| RATING_REASON | string | Classifier UDF | Decision path (e.g., `A+_vc_tech_not_svc_not_consumer_signal_ge_50`) |
| TECH_FLAG | boolean | Classifier UDF | Tech keywords found in text |
| VC_FLAG | boolean | Classifier UDF | VC/investment signal detected |
| ACCELERATOR_FLAG | boolean | Classifier UDF | Accelerator/incubator signal detected |
| GOV_OR_NONPROFIT_FLAG | boolean | Classifier UDF | Government or nonprofit entity |
| SERVICE_PROVIDER_FLAG | boolean | Classifier UDF | Service provider keywords detected |
| CONSUMER_ONLY_FLAG | boolean | Classifier UDF | Consumer keywords without tech |
| DEALROOM_SIGNAL_RATING_NUM | number(38,6) | DRM_COMPANY_SILVER | Dealroom's signal rating (numeric) |
| TECH_STRENGTH | number(38,0) | Classifier UDF | Count of text columns with tech keyword hits |
| ENGINE_OUTPUT | variant | Classifier UDF | Full JSON engine output |
| LOADED_AT | timestamp_tz | DRM_COMPANY_SILVER | |
| SILVER_LOADED_AT | timestamp_tz | System | |

### SILVER.DRM_STARTUP_CLASSIFICATION_SILVER_V2

Maps signals → status/score, applies manual overrides.

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| DEALROOM_ID | string | DRM_COMPANY_SILVER | |
| LOADED_AT | timestamp_tz | DRM_COMPANY_SILVER | |
| STARTUP_STATUS | string | Derived + Override | COALESCE(override, computed). Values: `startup` / `non_startup` / `uncertain` / `unknown` |
| STARTUP_SCORE | number(38,6) | Derived | RATING_LETTER_TO_SCORE(). A+=95, A=85, B=70, C=50, D=20 |
| CONFIDENCE_LEVEL | string | Derived | A+/D → `High`, A/B → `Medium`, C → `Low` |
| RATING_LETTER | string | Signals | A+ / A / B / C / D |
| RATING_REASON | string | Signals | Decision path identifier |
| CLASSIFICATION_REASON | variant | Derived | JSON: computed status, confidence, score, override info, signals |
| IS_MANUAL_OVERRIDE | boolean | Derived | TRUE if override exists |
| OVERRIDE_REASON | string | DRM_MANUAL_OVERRIDES | Reason for manual override |
| SILVER_LOADED_AT | timestamp_tz | System | |

### SILVER.DRM_ACTIVITY_STATUS_SILVER_V2

Company operational status heuristic with website validity.

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| company_id | string | DRM_COMPANY_SILVER | |
| activity_status | string | Derived + Override | COALESCE(override, computed). Values: `active` / `inactive` / `unknown` |
| activity_status_computed | string | Derived | Pre-override status |
| activity_score | float | Derived | `50 + funding(20) + has_website(10) + website_valid(15) - website_bad(25) - closed(80)` clamped 0-100 |
| activity_reason | string | Derived | Semicolon-separated signal names |
| activity_debug | variant | Derived | JSON with all component signals |
| activity_override_value | string | DRM_MANUAL_OVERRIDES | Manual override value |
| activity_override_reason | string | DRM_MANUAL_OVERRIDES | |
| activity_overridden_at | timestamp | DRM_MANUAL_OVERRIDES | |
| activity_overridden_by | string | DRM_MANUAL_OVERRIDES | |

**Component signals (embedded in activity_debug):**

| Signal | Type | Logic |
|--------|------|-------|
| sig_closed | bool | closing_date IS NOT NULL OR company_status IN ('closed','bankrupt','dissolved','inactive') |
| sig_recent_funding_24m | bool | last_funding_date >= NOW() - 24 months |
| sig_has_website | bool | website_url OR website_domain is non-empty |
| sig_website_valid | bool | website_status = 'valid' |
| sig_website_bad | bool | website_status IN ('invalid','parked','error') |

### SILVER.DRM_WEBSITE_STATUS_SILVER

Latest website check per company (deduplicated from Bronze).

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| company_id | string | Bronze checks | |
| website_checked_at | timestamp_ntz | Bronze checks | |
| input_url | string | Bronze checks | |
| input_domain | string | Bronze checks | |
| final_url | string | Bronze checks | |
| final_domain | string | Bronze checks | |
| http_status | number(38,0) | Bronze checks | |
| error_type | string | Bronze checks | |
| error_message | string | Bronze checks | |
| response_time_ms | number(38,0) | Bronze checks | |
| num_redirects | number(38,0) | Bronze checks | |
| is_https | boolean | Bronze checks | |
| is_valid | boolean | Bronze checks | |
| is_parked | boolean | Bronze checks | |
| parked_reason | string | Bronze checks | |
| content_sha256 | string | Bronze checks | |
| website_status | string | Derived | CASE: no_website / parked / valid / error / invalid / unknown |
| website_reason | string | Derived | Human-readable explanation |
| website_debug | variant | Bronze checks | Full raw_result |

### SILVER.DRM_GEO_ENRICHMENT_SILVER

City → region mapping for Quebec companies.

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| DEALROOM_ID | string | DRM_COMPANY_SILVER | |
| HQ_CITY | string | DRM_COMPANY_SILVER | Raw city |
| HQ_CITY_KEY | string | Derived | CLEAN_CITY_KEY(HQ_CITY) — accent-folded, uppercase, normalized |
| AGGLOMERATION | string | REF.CITY_REGION_MAPPING | Metropolitan area (e.g., "Grand Montréal") |
| AGGLOMERATION_DETAILS | string | REF.CITY_REGION_MAPPING | Sub-area details |
| MRC | string | REF.CITY_REGION_MAPPING | Municipalité Régionale de Comté |
| REGION_ADMIN | string | REF.CITY_REGION_MAPPING | Quebec administrative region (17 total) |
| GEO_MATCH_STATUS | string | Derived | `matched` or `unmatched` |
| GEO_LABELED_AT | timestamp | System | |

### SILVER.DRM_INDUSTRY_SIGNALS_SILVER

Keyword-based industry classification.

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| DEALROOM_ID | string | DRM_COMPANY_SILVER | |
| INDUSTRY_LABELS | array | Derived | All matched industries, ordered by score DESC |
| TOP_INDUSTRY | string | Derived | MAX_BY(industry_label, score) |
| TOP_INDUSTRY_SCORE | number | Derived | Weighted sum of keyword matches |
| INDUSTRY_MATCHES | variant | Derived | JSON array: [{industry, score, matched_keywords}, ...] |
| INDUSTRY_LABELED_AT | timestamp | System | |

### SILVER.DRM_TECHNOLOGY_SIGNALS_SILVER

Keyword-based technology classification.

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| DEALROOM_ID | string | DRM_COMPANY_SILVER | |
| TECHNOLOGY_LABELS | array | Derived | All matched technologies, ordered by score DESC |
| TOP_TECHNOLOGY | string | Derived | MAX_BY(technology_label, score) |
| TOP_TECHNOLOGY_SCORE | number | Derived | Weighted sum of keyword matches |
| TECHNOLOGY_MATCHES | variant | Derived | JSON array: [{technology, score, matched_keywords}, ...] |
| TECHNOLOGY_LABELED_AT | timestamp | System | |

### SILVER.DRM_STARTUP_LIFECYCLE_SILVER

Lifecycle classification combining startup rating, activity, and maturity signals.

| Column | Type | Source | Transformation |
|--------|------|--------|----------------|
| dealroom_id | string | DRM_COMPANY_SILVER | |
| startup_status | string | Classification | startup / non_startup / uncertain |
| rating_letter | string | Classification | A+ / A / B / C / D |
| confidence_level | string | Classification | High / Medium / Low |
| activity_status | string | Activity | active / inactive / unknown |
| launch_year | number | DRM_COMPANY_SILVER | |
| company_status | string | DRM_COMPANY_SILVER | |
| valuation_usd | number | DRM_COMPANY_SILVER | |
| employees_range | string | DRM_COMPANY_SILVER | |
| EMPLOYEES_LATEST_NUMBER | number | DRM_COMPANY_SILVER | |
| employees_parsed | variant | Derived | PARSE_EMPLOYEES_RANGE_DEALROOM_V1() output |
| sig_pre_1990 | boolean | Derived | launch_year < 1990 |
| sig_1990_2010 | boolean | Derived | 1990 <= launch_year < 2010 |
| sig_mature_exit | boolean | Derived | company_status matches acquired/ipo/public |
| sig_mature_1000_employees | boolean | Derived | employees_parsed >= 1000 |
| sig_mature_1b_valuation | boolean | Derived | valuation_usd >= 1,000,000,000 |
| sig_mature_any | boolean | Derived | OR(exit, 1000_employees, 1b_valuation) |
| sig_closed | boolean | Derived | activity_status = 'inactive' |
| maturity_detail | string | Derived | Comma-separated maturity reasons |
| lifecycle_bucket_computed | string | Derived | CASE logic (see below) |
| lifecycle_reason_computed | string | Derived | Human-readable reasons |
| lifecycle_bucket | string | Derived + Override | COALESCE(override, computed) |
| lifecycle_reason | string | Derived + Override | |
| is_ex_startup | boolean | Derived | lifecycle_bucket != 'active_startup' |
| is_current_active_startup | boolean | Derived | lifecycle_bucket = 'active_startup' AND startup_status = 'startup' |
| lifecycle_override_value | string | DRM_MANUAL_OVERRIDES | |
| lifecycle_override_reason | string | DRM_MANUAL_OVERRIDES | |
| lifecycle_overridden_at | timestamp | DRM_MANUAL_OVERRIDES | |
| lifecycle_overridden_by | string | DRM_MANUAL_OVERRIDES | |

**Lifecycle bucket logic (priority order):**
1. startup_status IS NULL → `unknown`
2. startup_status = 'non_startup' → `not_startup`
3. sig_mature_any → `mature_startup`
4. sig_closed → `closed_startup`
5. sig_pre_1990 → `founded_before_1990`
6. sig_1990_2010 → `founded_1990_2010`
7. startup/uncertain + active/unknown + launch_year >= 2010 → `active_startup`
8. else → `unknown`

### SILVER.DRM_COMPANY_ENRICHED_SILVER (View)

Unified view joining company data with all enrichment layers.

All columns from DRM_COMPANY_SILVER, plus:
- From GEO: AGGLOMERATION, AGGLOMERATION_DETAILS, MRC, REGION_ADMIN, GEO_MATCH_STATUS
- From INDUSTRY: INDUSTRY_LABELS, TOP_INDUSTRY, TOP_INDUSTRY_SCORE, INDUSTRY_MATCHES
- From TECH: TECHNOLOGY_LABELS, TOP_TECHNOLOGY, TOP_TECHNOLOGY_SCORE, TECHNOLOGY_MATCHES

### SILVER.DRM_REGISTRY_BRIDGE_SILVER

Dealroom ↔ Quebec Registry matching results.

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| DEALROOM_ID | string | DRM_COMPANY_SILVER | |
| DRM_NAME | string | DRM_COMPANY_SILVER | Company name |
| DRM_TRADE_REGISTER_NUMBER | string | DRM_COMPANY_SILVER | Registry number from Dealroom |
| DRM_NEQ_CLEAN | string | Derived | Normalized NEQ from Dealroom |
| NEQ_NUMBER_MATCH | string | Registry | NEQ found by exact number match |
| NEQ_NAME_MATCH | string | Registry | NEQ found by name similarity |
| REG_NAME_RAW | string | Registry | Registry business name |
| REG_NAME_STATUS | string | Registry | Name status in registry |
| NAME_SIM | number | Derived | Name similarity score (0-1) |
| NAME_MATCH_QUALITY | string | Derived | perfect / strong / weak / none |
| NEQ_FINAL | string | Derived | Best NEQ (number match > name match) |
| MATCH_SOURCE | string | Derived | 'number' / 'name' / NULL |
| FLAG_NEQ_NAME_CONFLICT | int | Derived | Number match and name match disagree |
| FLAG_NUMBER_NOT_FOUND_IN_REGISTRY | int | Derived | Dealroom NEQ not in registry |
| FLAG_MULTIPLE_DEALROOM_SAME_NEQ | int | Derived | Multiple Dealroom companies share NEQ |
| FLAG_NAME_MATCH_AMBIGUOUS | int | Derived | Name match is not clearly best |
| DATE_IMMATRICULATION | date | Registry | Registration date |
| ANNEE_DERNIERE_PRODUCTION_DECLARATION_IMPOT | number | Registry | Last tax year |
| N_EMPLOYES | number | Registry | Employee count from registry |
| REGISTRY_ADDRESSES | string | Registry | Pipe-delimited addresses |

### SILVER.DRM_MANUAL_OVERRIDES

Manual classification overrides (persists across pipeline runs).

| Column | Type | Description |
|--------|------|-------------|
| DEALROOM_ID | string | Company to override |
| OVERRIDE_TYPE | string | `startup` / `activity` / `lifecycle` |
| OVERRIDE_VALUE | string | The overridden value |
| OVERRIDE_REASON | string | Why the override was made |
| OVERRIDDEN_BY | string | User who made the override |
| OVERRIDDEN_AT | timestamp_tz | When override was made |
| IS_ACTIVE | boolean | Whether override is currently active |
| SOURCE | string | Where the override came from |

### SILVER.DRM_REVIEW_QUEUE_SILVER

Generated queue of companies needing manual review.

| Column | Type | Description |
|--------|------|-------------|
| DEALROOM_ID | string | Company to review |
| REVIEW_TYPE | string | `startup` / `activity` |
| PRIORITY | number(38,0) | Priority order |
| REASONS | variant | JSON with component scores and flags |
| GENERATED_AT | timestamp | When queue was generated |

---

## 3. Matching & Clustering Layer

### Entity Resolution Tables (Transient)

These tables are rebuilt on each matching run.

#### UTIL.T_ENTITIES_HS_DRM

Union of all entities for matching.

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| SRC | string | Constant | `HUBSPOT` / `DEALROOM` / `REGISTRY` |
| SRC_ID | string | Source system | Company ID in source system |
| NAME_RAW | string | Source | Original company name |
| NAME_NORM | string | Derived | NORM_NAME(): lowercased, whitespace collapsed |
| DOMAIN_NORM | string | Derived | Domain from website, normalized |
| LINKEDIN_NORM | string | Derived | LinkedIn URL, normalized |
| NEQ_NORM | string | Derived | NORM_NEQ(): alphanumeric uppercase only |
| TOK1 | string | Derived | First token of normalized name |
| P4 | string | Derived | First 4 characters of normalized name |

#### UTIL.T_EDGES_HS_DRM_DEDUP

Match edges between pairs of entities.

| Column | Type | Description |
|--------|------|-------------|
| SRC_A | string | Source system of entity A |
| ID_A | string | ID of entity A |
| SRC_B | string | Source system of entity B |
| ID_B | string | ID of entity B |
| MATCH_TYPE | string | `NEQ` / `DOMAIN` / `LINKEDIN` / `NAME_SIM` |
| SCORE | float | Match confidence (0.90 - 1.0) |

**Match types and thresholds:**
- `NEQ` — exact NEQ match (score = 1.0)
- `DOMAIN` — exact domain match (score = 1.0)
- `LINKEDIN` — exact LinkedIn match (score = 1.0)
- `NAME_SIM` — Jaro-Winkler similarity >= 0.90 (candidates filtered by TOK1 or P4)

#### UTIL.T_CLUSTERS_HS_DRM → UTIL.T_CLUSTERS

Label propagation clustering result.

| Column | Type | Description |
|--------|------|-------------|
| SRC | string | `HUBSPOT` / `DEALROOM` / `REGISTRY` |
| SRC_ID | string | Company ID in source system |
| CLUSTER_ID | string | Canonical cluster label (smallest SRC_ID) |

#### UTIL.T_CLUSTER_FLAGS

Conflict detection within clusters.

| Column | Type | Description |
|--------|------|-------------|
| CLUSTER_ID | string | Cluster identifier |
| FLAG_NEQ_CONFLICT | int | Multiple NEQ values in same cluster |
| FLAG_DOMAIN_CONFLICT | int | Multiple domains in same cluster |
| FLAG_LINKEDIN_CONFLICT | int | Multiple LinkedIn URLs in same cluster |
| FLAG_DOMAIN_NAME_MISMATCH | int | Same domain but dissimilar names |
| FLAG_HAS_REGISTRY_NODE | int | Cluster contains a registry entity |
| FLAG_REGISTRY_AMBIGUOUS_LINK | int | Registry entity in multiple clusters |
| FLAG_ANY_CONFLICT | int | OR of all conflict flags |
| ANY_NEQ | string | Sample NEQ from cluster |
| ANY_DOMAIN | string | Sample domain from cluster |
| ANY_LINKEDIN | string | Sample LinkedIn from cluster |

#### UTIL.T_CLUSTER_GOLDEN

Best-of values per safe cluster (no conflicts).

| Column | Type | Description |
|--------|------|-------------|
| CLUSTER_ID | string | Cluster identifier |
| GOLD_NEQ | string | Best NEQ (priority: Registry > Dealroom > HubSpot) |
| GOLD_DOMAIN | string | Best domain |
| GOLD_LINKEDIN | string | Best LinkedIn URL |
| GOLD_NAME | string | Best company name |

---

## 4. Push Views (Output to External Systems)

### UTIL.V_PUSH_HS_ENRICH

Enrichment suggestions to push to HubSpot.

| Column | Type | Description |
|--------|------|-------------|
| HS_COMPANY_ID | number | HubSpot company ID |
| SUGGEST_NEQ | string | NEQ to fill in HubSpot |
| SUGGEST_DOMAIN | string | Domain to fill in HubSpot |
| SUGGEST_LINKEDIN | string | LinkedIn to fill in HubSpot |
| CLUSTER_ID | string | Cluster that provided the enrichment |
| HS_NAME_RAW | string | Current HubSpot name |
| HS_NEQ_RAW | string | Current HubSpot NEQ (empty = gap) |
| HS_DOMAIN_RAW | string | Current HubSpot domain |
| HS_WEBSITE_RAW | string | Current HubSpot website |
| HS_LINKEDIN_RAW | string | Current HubSpot LinkedIn |

### UTIL.V_PUSH_HS_DEALROOM_LINK

Dealroom linkage suggestions for HubSpot.

| Column | Type | Description |
|--------|------|-------------|
| HS_COMPANY_ID | number | HubSpot company ID |
| CLUSTER_ID | string | Cluster identifier |
| SUGGEST_DRM_ID | string | Dealroom ID to link |
| SUGGEST_DRM_URL | string | Dealroom profile URL |
| SUGGEST_DRM_WEBSITE | string | Dealroom website |
| SUGGEST_DRM_LINKEDIN | string | Dealroom LinkedIn |

### UTIL.V_PUSH_DRM_ENRICH

Enrichment suggestions to push to Dealroom.

| Column | Type | Description |
|--------|------|-------------|
| DRM_ID | string | Dealroom company ID |
| CLUSTER_ID | string | Cluster identifier |
| SUGGEST_NEQ | string | NEQ to fill |
| SUGGEST_DOMAIN | string | Domain to fill |
| SUGGEST_LINKEDIN | string | LinkedIn to fill |
| DRM_NAME_RAW | string | Current Dealroom name |
| DRM_WEBSITE_RAW | string | Current Dealroom website |
| DRM_LINKEDIN_RAW | string | Current Dealroom LinkedIn |
| DRM_NEQ_RAW | string | Current Dealroom NEQ |

---

## 5. Reference Tables

### REF.CITY_REGION_MAPPING

Quebec city-to-region reference data (source: manually maintained).

| Column | Description |
|--------|-------------|
| HQ City | City name |
| AGGLOMERATION | Metropolitan area |
| AGGLOMERATION_DETAILS | Sub-area |
| MRC | Municipal regional county |
| REGION_ADMIN | Quebec administrative region |

### REF.INDUSTRY_KEYWORDS

Industry classification keywords (source: CSV in Snowflake stage).

| Column | Description |
|--------|-------------|
| INDUSTRY_LABEL | Industry category name |
| KEYWORD | Matching keyword |
| WEIGHT | Score weight (default 1) |
| ACTIVE | Boolean enable/disable |
| NOTES | Description |

### REF.TECHNOLOGY_KEYWORDS

Technology classification keywords (source: CSV in Snowflake stage).

| Column | Description |
|--------|-------------|
| TECHNOLOGY_LABEL | Technology category name |
| KEYWORD | Matching keyword |
| WEIGHT | Score weight (default 1) |
| ACTIVE | Boolean enable/disable |
| NOTES | Description |

### UTIL.RATING_LETTER_TO_SCORE

Rating letter to numeric score mapping.

| RATING_LETTER | RATING_SCORE |
|---------------|-------------|
| A+ | 95 |
| A | 85 |
| B | 70 |
| C | 50 |
| D | 20 |

---

## 6. Quebec Enterprise Registry Tables

Source: `DEV_DATAMART.ENTREPRISES_DU_QUEBEC`

### REGISTRE_NOMS

| Column | Description |
|--------|-------------|
| NEQ | Quebec enterprise number |
| NOM_ASSUJ | Business name |
| DAT_INIT_NOM_ASSUJ | Name start date |
| DAT_FIN_NOM_ASSUJ | Name end date (NULL if current) |

### ENTREPRISES_EN_FONCTION

| Column | Description |
|--------|-------------|
| NEQ | Quebec enterprise number |
| DATE_IMMATRICULATION | Registration date |
| FORME_JURIDIQUE | Legal form/structure |
| SECTEUR_ACTIVITE_PRINCIPAL | Primary activity sector |
| SECTEUR_ACTIVITE_SECONDAIRE | Secondary activity sector |
| N_EMPLOYES | Employee count |
| ANNEE_DERNIERE_PRODUCTION_DECLARATION_IMPOT | Last tax year |

### REGISTRE_ADRESSES

Address records for registry entities (used for geocoding).

---

## 7. HubSpot Source Columns

Properties fetched via Python connector (`src/ecosystem/connectors/hubspot.py`):

| HubSpot Property | Description |
|------------------|-------------|
| name | Company name |
| domain | Company domain |
| website | Website URL |
| linkedin_company_page | LinkedIn URL |
| industry | Industry classification |
| city | City |
| state | State/Province |
| country | Country |
| numberofemployees | Employee count |
| annualrevenue | Annual revenue |
| founded_year | Year founded |
| description | Company description |
| dealroom___id | Linked Dealroom ID |
| neq__numero_d_entreprise_du_quebec | Quebec business number |
| hs_object_id | HubSpot object ID |

HubSpot import columns (French-named CSV export) mapped in SQL:

| CSV Column (French) | Normalized Column |
|---------------------|-------------------|
| ID de fiche d'informations | HS_COMPANY_ID |
| Nom de l'entreprise | HS_NAME_RAW → HS_NAME_NORM |
| URL du site web | HS_WEBSITE_RAW → HS_DOMAIN_FROM_WEBSITE |
| Nom de domaine de l'entreprise | HS_DOMAIN_RAW → HS_DOMAIN_NORM |
| Page d'entreprise LinkedIn | HS_LINKEDIN_RAW → HS_LINKEDIN_NORM |
| IDENTIFIANT LINKEDIN | HS_LINKEDIN_ID_RAW → HS_LINKEDIN_ID_NORM |
| (NEQ) Numéro d'entreprise du Québec | HS_NEQ_RAW → HS_NEQ_NORM |
| Dealroom - ID | HS_DEALROOM_ID_RAW |
| Dealroom - Profile URL | HS_DEALROOM_URL_RAW |
| Dealroom - Website | HS_DEALROOM_WEBSITE_RAW |
| Dealroom - LinkedIn | HS_DEALROOM_LINKEDIN_RAW |

---

## 8. Python Processing Output Columns

### Classifier (`src/ecosystem/processing/classifier.py`)

Output of `rate_companies()`:

| Column | Type | Description |
|--------|------|-------------|
| drm_company_id | string | Dealroom company ID |
| startup_rating_letter | string | A+ / A / B / C / D |
| rating_reason | string | Decision path identifier |
| score_version | string | Version tag (e.g., "v5") |

Debug output of `attach_flags_for_qc()` (adds columns to input DataFrame):

| Column | Type | Description |
|--------|------|-------------|
| is_gov_nonprofit | bool | Government or nonprofit entity |
| has_accelerator | bool | Accelerator/incubator signal |
| is_service_provider | bool | Service provider keywords found |
| has_tech_indication | bool | Tech keywords found |
| is_consumer_only | bool | Consumer without tech |
| is_vc_backed | bool | VC/investment signal |
| completeness | float | Fraction of key fields filled (0-1) |
| tech_strength | int | Count of text columns with tech hits |
| dealroom_signal_nudge | bool | Dealroom signal >= 20 |

### Website Checker (`src/ecosystem/processing/website_checker.py`)

Output of `WebsiteChecker.check()`:

| Field | Type | Description |
|-------|------|-------------|
| url | str | Checked URL |
| is_alive | bool | HTTP status < 400 |
| status_code | int | HTTP status code |
| redirect_url | str | Final URL after redirects |
| error | str | Error message if failed |
| pages_crawled | int | Number of pages crawled |
| pages | list[PageContent] | Crawled page data (when crawl=True) |

Each `PageContent`:

| Field | Type | Description |
|-------|------|-------------|
| url | str | Page URL |
| title | str | HTML title tag |
| headings | str | Combined h1/h2/h3 text |
| text | str | Main body text |
| snippet | str | Truncated headings+text (max 3000 chars) |

### Matcher (`src/ecosystem/processing/matcher.py`)

Output of `match_datasets()` — returns two DataFrames (HubSpot, Dealroom) with one added column each:

| Column | Added To | Description |
|--------|----------|-------------|
| matched with Dealroom | HubSpot DataFrame | Boolean — matched via name/website/LinkedIn/NEQ |
| matched with Hubspot | Dealroom DataFrame | Boolean — matched via name/website/LinkedIn/NEQ |

---

## 9. Utility UDFs

Key Snowflake UDFs used in transformations:

| UDF | Input | Output | Purpose |
|-----|-------|--------|---------|
| NULLIF_BLANK(s) | string | string or NULL | Trim + null empty strings |
| TRY_TO_NUMBER_CLEAN(s) | string | number | Parse numbers with commas/spaces |
| TRY_TO_DOUBLE_CLEAN(s) | string | double | Parse lat/long |
| TRY_TO_DATE_ANY(s) | string | date | Parse various date formats |
| DOMAIN_FROM_URL(url) | string | string | Extract bare domain from URL |
| CLEAN_CITY_KEY(city) | string | string | Accent-fold + uppercase + normalize city |
| NORMALIZE_TEXT_FOR_MATCHING(txt) | string | string | Accent-fold + lowercase + punctuation→space |
| NORMALIZE_DEALROOM_URL(url) | string | string | Lowercase + remove querystring |
| NORM_NAME(name) | string | string | Name normalization for matching |
| NORM_NEQ(neq) | string | string | Alphanumeric uppercase only |
| KEYWORD_TO_REGEX(keyword) | string | string | Keyword → Snowflake REGEXP_LIKE pattern |
| RATING_LETTER_TO_SCORE(letter) | string | number | A+=95, A=85, B=70, C=50, D=20 |
| PARSE_EMPLOYEES_RANGE_DEALROOM_V1(range, number) | string, float | variant | Parse "11-50" → {min, max, mid, employees_ge_1000} |
| STARTUP_CLASSIFY_DEALROOM_V5(row) | variant | variant | Full classifier engine (JS UDF) |
