# Quebec Startup Ecosystem — Classification Methodology & Key Statistics

**Date**: 2026-03-16
**Pipeline version**: v1.0 (bronze → silver → gold)
**Data source**: Dealroom export (2025-12-09)

---

## 1. Executive Summary

From a raw dataset of **11,136 companies** listed in Dealroom for Quebec, our 3-layer classification pipeline identifies **2,195 current active startups** — companies founded post-2010 (or with unknown founding date), still operating, and classified as startups through algorithmic scoring and/or human review.

A broader universe of **3,239 startups** includes mature exits (IPOs, acquisitions, 1000+ employees) and legacy companies (pre-2010) that still exhibit startup characteristics.

| Metric | Count |
|--------|------:|
| Total companies in dataset | 11,136 |
| Current active startups (`is_current_active_startup`) | 2,195 |
| Broad startup universe (`is_startup_broad`) | 3,239 |
| Non-startups | 5,378 |
| Uncertain (requires further review) | 2,817 |

---

## 2. Data Pipeline Architecture

The pipeline follows a **medallion architecture** (bronze → silver → gold), processing data through 3 stages and 12 enrichment steps.

### 2.1 Bronze Layer (Raw Ingestion)

- **Input**: Dealroom CSV export (11,136 rows, 137 columns)
- **Processing**: Select 76 relevant columns, rename to snake_case, parse types (numeric, date, boolean)
- **Output**: 11,136 rows, 74 columns

### 2.2 Silver Layer (Enrichment)

Twelve sequential enrichment steps add 55 derived columns:

| Step | Name | Description | Coverage |
|------|------|-------------|----------|
| 1 | Normalize | Normalized names, domains, LinkedIn slugs, NEQ, match text | 100% |
| 2 | Geo enrichment | Map cities to Quebec admin regions (17 regions) | 93% (10,310/11,136) |
| 3 | Industry keywords | Match against 303 industry keywords | 68% (7,625/11,136) |
| 4 | Technology keywords | Match against 366 technology keywords | 33% (3,703/11,136) |
| 5 | Website active status | Join Dealroom website check data | 85% (9,434/11,136) |
| 6 | Manual reviews | Merge human + auto reviews (human takes priority) | 70% (7,784/11,136) |
| 7 | Classification | Rule-based A+/A/B/C/D rating + manual overrides | 100% |
| 8 | Activity status | Score-based active/inactive/unknown | 100% |
| 9 | Accelerator detection | Pattern match accelerator/incubator names | 10% (1,165/11,136) |
| 10 | Funding enrichment | Derive financing flags and funding stage | 100% |
| 11 | Founder enrichment | Derive founder metrics (count, experience, serial) | 100% |
| 12 | Lifecycle bucketing | Assign lifecycle bucket + final flags | 100% |

### 2.3 Gold Layer (Final Output)

- Column cleanup (drop intermediate join keys)
- Add pipeline metadata (`_pipeline_version`, `_gold_built_at`)
- **Output**: 11,136 rows, 128 columns

---

## 3. Classification Methodology

### 3.1 Three-Layer Classification

Classification uses three layers in order of authority:

```
Layer 1: Algorithmic rating (A+ through D)    — all 11,136 companies
Layer 2: Human manual review                  — 6,768 companies
Layer 3: Website auto-review (crawl + score)  — 1,016 companies
```

**Human review always takes priority** over algorithmic or auto-review classifications when a definitive answer (startup / non-startup) was provided. When a human marked "for review" (uncertain), the auto-review's definitive answer takes priority.

### 3.2 Algorithmic Rating (Layer 1)

Rule-based classifier using keyword lists and feature flags. Produces a letter grade:

| Rating | Meaning | Count |
|--------|---------|------:|
| A+ | Confirmed startup (manual override) | 2,354 |
| A | Strong startup signals | 382 |
| B | Moderate startup signals | 205 |
| C | Uncertain / insufficient signals | 2,817 |
| D | Non-startup (or manual override) | 5,378 |

The classifier examines:
- Industry and technology keywords
- Funding signals (VC-backed, round types)
- Investor types (accelerator, incubator involvement)
- Company status and employee data
- Government/nonprofit indicators
- Service provider patterns

### 3.3 Human Manual Review (Layer 2)

Human reviewers examined 6,768 companies and classified them as:

| Status | Count |
|--------|------:|
| Non-startup | 4,013 |
| Startup | 1,652 |
| For review (uncertain) | 1,103 |

Manual review results override algorithmic ratings:
- "startup" → rating elevated to A+
- "non-startup" → rating set to D
- "for review" → rating set to C (uncertain)

### 3.4 Website Auto-Review (Layer 3)

Automated website crawling and signal extraction for companies where human review was inconclusive or unavailable. Processed 1,016 companies:

| Status | Count |
|--------|------:|
| Startup | 680 |
| Non-startup | 336 |

Website signals extracted include:
- Product/technology language detection
- Funding/investor mentions
- Career page presence and hiring signals
- B2B vs B2C indicators
- Startup URL path patterns (e.g., /investors, /careers)

### 3.5 Effective Classification

The final `startup_status_effective` field resolves all three layers:

| Status | Count | Description |
|--------|------:|-------------|
| Startup | 2,941 | A+, A, or B rating (after overrides) |
| Uncertain | 2,817 | C rating — needs more data or review |
| Non-startup | 5,378 | D rating (after overrides) |

### 3.6 Confidence Levels

| Level | Count | Description |
|-------|------:|-------------|
| Manual | 7,784 | Human or auto-reviewed |
| High | 1,387 | Algo-only, clear A+ or D |
| Medium | 382 | Algo-only, A rating |
| Low | 1,583 | Algo-only, B or C rating |

---

## 4. Activity Status Methodology

Activity is scored on a 0–100 scale based on available signals:

| Signal | Points |
|--------|-------:|
| Base score | +50 |
| Has website | +10 |
| Website is active | +15 |
| Website inactive (non-reviewed) | -25 |
| Website inactive (manually reviewed as startup) | -10 |
| Recent funding (last 3 years) | +20 |
| Employee growth > 0 (12 months) | +10 |
| Company closed/dead | -80 |
| Has closing year | -80 |
| Dormant old company (pre-2005, no recent signals) | -5 |

**Thresholds**: active ≥ 65, inactive ≤ 25, unknown = between.

**Key design decision**: Manually-reviewed startups with unknown activity (missing website check or no signals) are **presumed active**. A human classification carries more weight than a missing data point.

| Activity Status | Count |
|-----------------|------:|
| Active | 8,241 |
| Unknown | 2,658 |
| Inactive | 237 |

---

## 5. Lifecycle Buckets

Each company is assigned to exactly one lifecycle bucket, evaluated in priority order:

| Priority | Bucket | Count | Criteria |
|----------|--------|------:|----------|
| 1 | `not_startup` | 5,378 | D-rated (non-startup) |
| 2 | `mature_startup` | 394 | Exit (acquired/IPO/merged), 1000+ employees, or $1B+ valuation |
| 3 | `closed_startup` | 145 | Startup but company status is closed/dead |
| 4 | `founded_before_1990` | 213 | Launch year before 1990 |
| 5 | `growth_startup` | 452 | Startup + active + funded + >10 employees |
| 6 | `early_startup` | 1,153 | Startup + active + launched 2015+ + ≤10 employees |
| 7 | `active_startup` | 590 | Startup + active + launched 2010+ (or no year) |
| 8 | `legacy_active` | 650 | Startup/uncertain + active + launched 1990–2010 |
| 9 | `legacy_dormant` | 135 | Startup/uncertain + not active + launched 1990–2010 |
| 10 | `uncertain` | 1,879 | C-rated, not closed, not inactive |
| 11 | `unknown` | 147 | Everything else |

### 5.1 Flag Definitions

**`is_current_active_startup`** (2,195) = `early_startup` + `active_startup` + `growth_startup`
- Current operating startups
- Excludes mature exits, legacy (pre-2010), and closed companies
- Includes companies with no launch year data (benefit of the doubt)
- Includes companies with unknown activity status if manually reviewed as startup

**`is_startup_broad`** (3,239) = above + `mature_startup` + `legacy_active`
- Full startup universe including exits and older active companies

---

## 6. Key Statistics — Current Active Startups (2,195)

### 6.1 Geographic Distribution

| Region | Count | Share |
|--------|------:|------:|
| Montréal (06) | 1,672 | 76.2% |
| Capitale-Nationale (03) | 295 | 13.4% |
| Montérégie (16) | 110 | 5.0% |
| Estrie (05) | 74 | 3.4% |
| Laval (13) | 71 | 3.2% |
| Outaouais (07) | 46 | 2.1% |
| Laurentides (15) | 31 | 1.4% |
| Chaudière-Appalaches (12) | 29 | 1.3% |
| Mauricie (04) | 21 | 1.0% |
| Saguenay–Lac-Saint-Jean (02) | 17 | 0.8% |

Geo match rate: 2,411/2,195 (93%)

### 6.2 Founding Year Distribution

| Period | Count | Share |
|--------|------:|------:|
| No year data | 241 | 11.0% |
| 2010–2014 | 432 | 19.7% |
| 2015–2017 | 509 | 23.2% |
| 2018–2020 | 558 | 25.4% |
| 2021–2023 | 402 | 18.3% |
| 2024–2026 | 177 | 8.1% |

Peak founding period: 2015–2020 (48.6% of active startups).

### 6.3 Top Industries

Companies can have multiple industry labels. Of 2,195 active startups, 2,226 (86%) have at least one industry label.

| Industry | Count |
|----------|------:|
| ICT / Enterprise Software | 1,460 |
| Manufacturing and Industrial | 953 |
| Defense, Aerospace and Security | 874 |
| Consumer | 803 |
| Healthcare and Life Sciences | 643 |
| Financial Services (Fintech/Insurtech) | 581 |
| Transportation and Logistics | 375 |
| Climate Change and Renewables | 369 |
| Natural Resources | 325 |

**Primary industry** (single best match):

| Industry | Count |
|----------|------:|
| ICT / Enterprise Software | 620 |
| Healthcare and Life Sciences | 390 |
| Consumer | 309 |
| Manufacturing and Industrial | 210 |
| Financial Services | 199 |
| Defense, Aerospace and Security | 181 |
| Climate Change and Renewables | 180 |
| Transportation and Logistics | 82 |
| Natural Resources | 55 |

### 6.4 Top Technologies

1,705 (66%) of active startups have at least one technology label.

| Technology | Count |
|------------|------:|
| AI | 632 |
| SaaS and Cloud | 475 |
| Frontier Tech | 436 |
| Energy and CleanTech | 431 |
| Hardware and Components | 371 |
| Data and Analytics | 358 |
| Robotics | 280 |
| Hard Tech | 279 |
| Deep Tech | 260 |
| SpaceTech and Geospatial | 228 |
| Cyber | 212 |
| IoT and Embedded | 198 |
| XR and Spatial | 88 |
| Blockchain and Web3 | 78 |
| Advanced Materials and Nanotech | 47 |

### 6.5 Funding

| Metric | Count | Share |
|--------|------:|------:|
| Has received financing | 1,363 | 53% |
| VC-backed | 910 | 35% |
| Not financed (or no data) | 1,226 | 47% |

**Funding stage** (of financed startups):

| Stage | Count |
|-------|------:|
| Other (debt, crowdfunding, etc.) | 680 |
| Early (pre-seed, seed, angel) | 395 |
| Grant | 104 |
| Growth (Series A–C) | 90 |
| Late (Series D+, IPO, secondary) | 13 |
| No data | 1,307 |

### 6.6 Employee Size

| Size | Count | Share |
|------|------:|------:|
| No data | 515 | 23.5% |
| 1–10 | 1,237 | 56.4% |
| 11–50 | 577 | 26.3% |
| 51–200 | 189 | 8.6% |
| 201–500 | 38 | 1.7% |
| 500+ | 33 | 1.5% |

Majority (56%) are small teams of 1–10 employees.

### 6.7 Founder Profile

| Metric | Count | Share |
|--------|------:|------:|
| Has founder data | 1,306 | 50.4% |
| Has serial founder | 155 | 6.0% |
| Has experienced founder | 422 | 16.3% |
| Has top university founder | 40 | 1.5% |

### 6.8 Other Signals

| Signal | Count | Share |
|--------|------:|------:|
| Has website | 2,580 | 99.4% |
| Website confirmed active | 2,189 | 84.4% |
| Has accelerator/incubator connection | 1,084 | 41.8% |

---

## 7. Data Quality Notes

### 7.1 Known Gaps

- **Launch year missing** for 241 active startups (11%) — these are included (benefit of the doubt) rather than excluded
- **Activity status unknown** for ~250 startups — manually reviewed startups are presumed active
- **Industry/technology labels** missing for ~14% / ~34% of active startups
- **Employee data** missing for 23.5% of active startups
- **Founder data** missing for ~50% of active startups
- **Website active check** from Dealroom can be stale; softened penalty for manually-confirmed startups

### 7.2 Review Coverage

- 70% of all companies (7,784/11,136) have been reviewed (human or auto)
- The remaining 3,352 rely solely on the algorithmic classifier
- Of the 2,195 active startups, 1,791 (82%) were manually confirmed

### 7.3 Potential Undercounting

- **Uncertain bucket** (2,817 companies): some may be startups but lack sufficient signals
  - 1,879 are in the `uncertain` lifecycle bucket, active but unresolved
  - These are candidates for future manual review rounds
- **147 companies** remain in the `unknown` lifecycle bucket — algo-classified as startups (A/B) but with no activity signals and no manual review

### 7.4 Potential Overcounting

- Companies with **no launch year** are assumed post-2010 — some may be older
- **Website auto-reviews** (680 classified as startup) have not been human-validated
- Dealroom data may include companies that have **quietly ceased operations** without updating their status

---

## 8. Definitions Glossary

| Term | Definition |
|------|-----------|
| **Active startup** | `is_current_active_startup` — early, active, or growth stage; not closed; not pre-2010; not exited |
| **Broad startup** | `is_startup_broad` — active startup + mature exits + legacy active |
| **Startup (effective)** | Company rated A+, A, or B after all review overrides |
| **Non-startup** | Company rated D after all review overrides |
| **Uncertain** | Company rated C — insufficient data or signals to classify |
| **Manual review** | Human classification (startup / non-startup / for-review) |
| **Auto-review** | Website crawl-based classification |
| **Activity score** | 0–100 composite score from website, funding, employment signals |
| **Lifecycle bucket** | Mutually exclusive stage assignment (growth, early, active, legacy, mature, closed, etc.) |
