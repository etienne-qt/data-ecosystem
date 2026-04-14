# Startup Ecosystem Taxonomy

This document consolidates all classification systems used to categorize, rate, and filter startups in our data pipeline.

---

## 1. Startup Rating (A+ / A / B / C / D)

The primary quality rating for startups, implemented in both Python (`src/ecosystem/processing/classifier.py`) and SQL (`sql/10_utils/30_udf_startup_classifier_v5.sql`).

### Rating Scale

| Rating | Score | Meaning |
|--------|-------|---------|
| **A+** | 95 | Top-tier startup — strong tech + signal (VC/accelerator/Dealroom) + no services |
| **A** | 85 | Strong startup — tech + VC or accelerator, no services, lower signal |
| **B** | 70 | Moderate startup — tech + services, or consumer + high signal |
| **C** | 50 | Uncertain — some signals present but inconclusive |
| **D** | 20 | Non-startup — gov/nonprofit, services-only, or no startup signals |

### Classification Flags (inputs to decision tree)

1. **has_tech_indication** — matches tech keywords in name/tagline/description/tags/technologies
2. **is_vc_backed** — investor type or round type contains VC/seed/series keywords
3. **has_accelerator_signal** — investor type or known accelerator name present
4. **is_service_provider** — service/consulting/agency keywords detected
5. **is_consumer_only** — consumer keywords present AND no tech keywords
6. **is_gov_or_nonprofit** — government domain suffix or nonprofit keywords
7. **dealroom_signal >= 50** — Dealroom's own signal rating is 50+

### Decision Tree Summary

| Path | Rating | Key Condition |
|------|--------|---------------|
| Accel + VC + Tech + !Svc + Signal>=50 | **A+** | All positive signals aligned |
| VC + Tech + !Svc + !Consumer + Signal>=50 | **A+** | Strong VC+Tech without services |
| Tech + !Svc + !Consumer + Signal>=50 | **A+** | High-signal pure tech company |
| Accel + VC + Tech + !Svc + Signal<50 | **A** | Strong signals, lower Dealroom score |
| VC + Tech + !Svc + !Consumer + Signal<50 | **A** | Solid VC-backed tech startup |
| Tech + !Svc + !Consumer + Signal<50 | **A** | Tech company without external signals |
| Accel + VC + Tech + Svc | **B** | Good signals but also a service provider |
| VC + Tech + Consumer + Signal>=50 | **B** | Consumer tech with strong signal |
| No VC + No Tech + !Svc + !Consumer + Signal>=50 | **B** | High Dealroom signal compensates |
| Accel + No VC + No Tech | **C** | Accelerator alone isn't enough |
| VC + No Tech | **C** | VC without tech indication |
| Tech + Svc (no accel) | **C** | Tech-enabled services company |
| No signals at all | **C** | Insufficient data |
| No VC + No Tech + Svc | **D** | Service provider, no startup signals |
| Gov/Nonprofit | **D** | Not a startup by definition |

### Derived Fields

- **startup_status**: `startup` (A+/A/B) · `uncertain` (C) · `non_startup` (D)
- **confidence_level**: `High` (A+, D) · `Medium` (A, B) · `Low` (C)

---

## 2. Technology Keywords

Used for the `has_tech_indication` flag in the classifier and for keyword-based technology enrichment in Snowflake (`sql/30_silver/82_tech_enrichment.sql`).

### Python Classifier Categories (`classifier.py`)

| Category | Keywords (sample) |
|----------|-------------------|
| **AI & Machine Learning** | ai, machine learning, deep learning, nlp, llm, generative ai, computer vision, neural network, chatbot, copilot, reinforcement learning, explainable ai |
| **Data & Analytics** | data, analytics, big data, data science, data warehouse, business intelligence, bi, etl, data pipeline, data governance |
| **IoT & Embedded** | iot, internet of things, connected device, edge computing, smart sensor, wearable, telemetry, lora, mqtt |
| **Robotics & Automation** | robotics, robot, cobot, industrial automation, rpa, autonomous vehicle, drone, uav, motion control |
| **Cybersecurity** | cybersecurity, information security, encryption, threat detection, identity management, zero trust, siem, firewall |
| **Blockchain & Web3** | blockchain, web3, crypto, defi, nft, smart contract, dao, tokenization, metaverse, dapp |
| **Quantum** | quantum computing, qubit, quantum sensor, superconducting, quantum annealing |
| **Hardware & Components** | semiconductor, chip, fpga, sensor, pcb, ai accelerator, neuromorphic |
| **Photonics & Laser** | photonics, laser, optics, lidar, spectroscopy, fiber optics, optoelectronics |
| **XR & Spatial Computing** | vr, ar, mixed reality, xr, holography, digital twin, spatial computing |
| **Additive Manufacturing** | 3d printing, additive manufacturing, rapid prototyping, generative design |
| **Energy & CleanTech** | renewable energy, cleantech, carbon capture, hydrogen, battery, solar, smart grid, circular economy |
| **Space & Geospatial** | satellite, nanosatellite, earth observation, geospatial, remote sensing, space tech |
| **Advanced Materials** | nanotech, composites, graphene, ceramics, metamaterials |
| **Biotech & MedTech** | biotech, medtech, healthtech, medical device, synthetic biology |
| **Frontier / Deep Tech** | hard tech, industrial tech, advanced manufacturing, nuclear fusion, solid-state battery, direct air capture |
| **General Tech** | saas, software, cloud, api, platform, devops, kubernetes, docker |

### Snowflake Technology Enrichment

Technology labels and keywords are loaded from CSV into `REF.TECHNOLOGY_KEYWORDS` and matched against company text via regex. Produces:
- `TECHNOLOGY_LABELS` — array of all matched technologies (ordered by score)
- `TOP_TECHNOLOGY` — single highest-scoring match
- `TOP_TECHNOLOGY_SCORE` — numeric score

The actual keyword lists are maintained in `technology_keywords_simplified.csv` (stored in Snowflake stage `@DEV_QUEBECTECH.REF.TECH_KEYWORDS`).

---

## 3. Industry / Sector Classification

Keyword-based industry classification via Snowflake (`sql/30_silver/81_industry_enrichment.sql`).

Industry labels and keywords are loaded from CSV into `REF.INDUSTRY_KEYWORDS` and matched using the same regex engine as technology.

Produces:
- `INDUSTRY_LABELS` — array of all matched industries (ordered by score)
- `TOP_INDUSTRY` — single highest-scoring match
- `TOP_INDUSTRY_SCORE` — numeric score
- `INDUSTRY_MATCHES` — JSON with industry, score, and matched keywords

The actual keyword lists are maintained in `industry_keywords_simplified.csv` (stored in Snowflake stage `@DEV_QUEBECTECH.REF.INDUSTRY_KEYWORDS`).

> **Note:** The specific industry and technology label lists are maintained as CSV files in Snowflake stages. To retrieve the current lists, query:
> ```sql
> SELECT DISTINCT INDUSTRY_LABEL FROM REF.INDUSTRY_KEYWORDS WHERE ACTIVE ORDER BY 1;
> SELECT DISTINCT TECHNOLOGY_LABEL FROM REF.TECHNOLOGY_KEYWORDS WHERE ACTIVE ORDER BY 1;
> ```

---

## 4. Geographic Classification

Implemented in `sql/30_silver/80_geo_enrichment.sql` using a reference mapping table `REF.CITY_REGION_MAPPING`.

### Geographic Dimensions

| Dimension | Description | Example |
|-----------|-------------|---------|
| **HQ City** | Raw city name (normalized via `CLEAN_CITY_KEY`) | Montréal |
| **Agglomeration** | Metropolitan area | Grand Montréal |
| **Agglomeration Details** | Sub-area within agglomeration | Laval |
| **MRC** | Municipalité Régionale de Comté | Communauté-Métropolitaine-de-Montréal |
| **Region Admin** | Quebec administrative region (17 total) | Montréal |

### Quebec Administrative Regions

1. Bas-Saint-Laurent
2. Saguenay–Lac-Saint-Jean
3. Capitale-Nationale
4. Mauricie
5. Estrie
6. Montréal
7. Outaouais
8. Abitibi-Témiscamingue
9. Côte-Nord
10. Nord-du-Québec
11. Gaspésie–Îles-de-la-Madeleine
12. Chaudière-Appalaches
13. Laval
14. Lanaudière
15. Laurentides
16. Montérégie
17. Centre-du-Québec

### City Normalization

The `CLEAN_CITY_KEY` function (`sql/10_utils/50_udf_city_mapping.sql`):
1. Extracts the first part before any comma ("Montreal, QC, Canada" → "Montreal")
2. Removes parenthetical notes ("Québec (City)" → "Québec")
3. Folds accents (É→E, etc.)
4. Converts to uppercase
5. Replaces non-alphanumeric with spaces
6. Collapses whitespace

**Geo Match Status**: `matched` (city found in reference table) or `unmatched`.

---

## 5. Lifecycle Bucket

Determines whether a startup is currently active, mature, or historical. Implemented in `sql/30_silver/70_startup_lifecycle_silver.sql`.

### Lifecycle Values

| Bucket | Criteria | Meaning |
|--------|----------|---------|
| **active_startup** | startup/uncertain + active/unknown + founded >= 2010 | Eligible for tracking |
| **mature_startup** | Exit/IPO/acquisition OR 1000+ employees OR $1B+ valuation | Scaled beyond startup phase |
| **closed_startup** | activity_status = inactive | No longer operating |
| **founded_before_1990** | launch_year < 1990 | Too old to be a startup |
| **founded_1990_2010** | 1990 <= launch_year < 2010 | Old vintage |
| **not_startup** | startup_status = non_startup (D rating) | Failed startup criteria |
| **unknown** | Insufficient data | Cannot determine |

### Maturity Detection Signals

- `sig_mature_exit` — company_status matches 'acquired', 'ipo', 'public'
- `sig_mature_1000_employees` — employee count >= 1,000
- `sig_mature_1b_valuation` — valuation_usd >= $1,000,000,000

### Derived Flags

- **is_ex_startup** — TRUE if lifecycle_bucket != 'active_startup'
- **is_current_active_startup** — TRUE if 'active_startup' AND startup_status = 'startup'

---

## 6. Activity Status

Heuristic for whether a company is still operating. Implemented in `sql/30_silver/40_merge_activity_status_silver.sql`.

### Status Values

| Status | Score Range | Meaning |
|--------|------------|---------|
| **active** | >= 60 | Company shows signs of life |
| **inactive** | <= 35 or sig_closed | Company appears dead |
| **unknown** | 36-59 | Ambiguous signals |

### Scoring Formula

```
Base:   50
 + 20   recent funding (last 24 months)
 + 10   has a website URL
 + 15   website responds with valid HTTP status
 - 25   website is invalid/parked/error
 - 80   closed signal (closing_date set or status = closed/bankrupt/dissolved)
```

---

## 7. Website Status

HTTP check results for company websites. Implemented in `sql/30_silver/60_drm_website_status.sql`.

| Status | Meaning |
|--------|---------|
| **valid** | Website returns HTTP 200-399 |
| **invalid** | HTTP 400+ status code |
| **parked** | Domain is a parked/placeholder page |
| **error** | DNS, timeout, or connection error |
| **no_website** | No URL provided |
| **unknown** | Not yet checked |

---

## 8. Exclusion Keywords

### Government / Non-Profit Detection

**Domain suffixes:** `.gov`, `.gouv.qc.ca`, `.gc.ca`, `.quebec`, `.org`, `.ong`, `.qc.ca`, `.gouv.ca`, `.gouv.fr`, `.gov.uk`

**Keywords:** ministere, ministry, municipalite, municipality, city of, ville de, centre integre de sante, chsld, cisss, ciusss, non-profit, fondation, foundation, cooperative, coop, societe d'etat, charity, organisme

### Service Provider Detection

**Keywords:** agence, agency, conseil, consulting, services, web design, seo, marketing, dev shop, custom software, recrutement, recruitment, formation, coaching, comptabilite, accounting, hebergement, hosting, it services, managed services, studio, freelance

### Consumer-Only Detection

**Keywords:** ecommerce, marketplace, retail, clothing, fashion, beauty, cosmetics, food, restaurant, cafe, grocery, gym, yoga, salon, spa, home renovation, furniture, bakery, plombier, electricien

---

## 9. VC / Investment Detection

**Investor type keywords:** venture capital, vc, seed, series a/b/c, angel, pre-seed, equity crowdfunding

**Accelerator keywords:** accelerator, incubator, accélérateur, incubateur

**Known accelerator programs:** centech, cycle momentum, le camp, acet, techstars, scale ai, propolys, quantino, 2 degres, station fintech, district3, nextai, founderfuel, esplanade, cdl montreal, medxlab, apollo13, aquaaction, cqib, groupe3737, ceim, tandemlaunch, y combinator (80+ total)

---

## 10. Pipeline Summary

All classifications flow through the Snowflake medallion architecture:

```
Bronze (raw)
  → Silver (normalized + classified)
      → DRM_STARTUP_CLASSIFICATION_SILVER (rating + status + confidence)
      → DRM_ACTIVITY_STATUS_SILVER (active/inactive/unknown)
      → DRM_WEBSITE_STATUS_SILVER (valid/invalid/parked/error)
      → DRM_GEO_ENRICHMENT_SILVER (city → region mapping)
      → DRM_INDUSTRY_SIGNALS_SILVER (keyword-based industry labels)
      → DRM_TECHNOLOGY_SIGNALS_SILVER (keyword-based tech labels)
      → DRM_STARTUP_LIFECYCLE_SILVER (lifecycle bucket + ex-startup flag)
        → Analytics (aggregations, reports)
```

Manual overrides are supported via `SILVER.DRM_MANUAL_OVERRIDES` for startup status, activity status, and lifecycle bucket.
