# Quebec Tech — Data Pipeline Overview

**Audience:** non-technical collaborators who need to understand where our startup registry comes from, what we do to the data at each stage, and why.

**Last updated:** 2026-04-13

> This doc is rendered as Markdown with a Mermaid diagram. In GitHub, Notion, and most Markdown viewers the diagram appears as a picture. In a plain text editor you'll see the code block.

---

## TL;DR

We pull company data from **five external sources**, clean and classify each one in its own lane, then match rows across sources using a deterministic-first waterfall. The final output is a single table — `GOLD.STARTUP_REGISTRY` — that lists every Quebec startup we know about, with a flag for each source that confirmed it.

As of 2026-04-13 the registry contains **7,608 rows**: 2,659 matched in both Dealroom and Réseau Capital, 2,560 in Dealroom only, 2,389 in Réseau Capital only.

**Applying our current startup definition:** **6,507 Quebec tech startups** — 4,651 anchored in Dealroom's classification plus 1,856 from extending the filter to Réseau Capital's Quebec population.

**Lifecycle breakdown** (Q3 v3, 2026-04-14):

| Lifecycle | N | % | Entity split (MATCHED / QT_ONLY / RC_ONLY) |
|---|---:|---:|---|
| **active** | **3,355** | **51.6%** | 1,370 / 1,228 / 757 |
| **mature** | 1,743 | 26.8% | 501 / 474 / 768 |
| **acquired** | 495 | 7.6% | 371 / 124 / 0* |
| **closed** | 235 | 3.6% | 90 / 143 / 2 |
| **unknown_age** | 650 | 10.0% | 20 / 301 / 329 |
| unknown_status | 29 | 0.4% | 4 / 25 / 0 |

> \* Zero RC_ONLY rows show as acquired because PitchBook tracks acquisitions in `FINANCING_STATUS` / deal-type fields rather than `BUSINESS_STATUS`. Our unified status mapping currently only reads `RC_BUSINESS_STATUS`. Known gap; we are asking Réseau Capital for guidance on the right field. Real-world impact: ~20–50 RC_ONLY acquisitions are being counted as mature instead.

**Sub-ecosystems worth flagging** (sector flags still fire mostly on the DR side — RC side has <3% sector coverage, see below):
- **Pharma / biotech:** 506 companies, **60% active** — the healthiest profile in the data.
- **Gaming:** 106 companies, **65% active** — deep indie layer on top of the AAA-studio-acquired tier.

> ⚠️ **Honest caveat on the RC_ONLY contribution.** The 1,856 RC_ONLY rows in this count come from a Q4 audit that found only **3.1% of RC_ONLY have any PitchBook sector assignment** — the remaining 1,880 rows are "dark matter" tracked only by Harmonic's long-tail scraping, with no industry signal. An eyeball of 95 RC_ONLY rows (Q4 §H+§I) suggested **~24% are clearly tech startups, ~54% are clearly non-tech** (DTC brands, restaurants, insurance, clinics, professional services, traditional manufacturing), and ~22% are ambiguous. Our name-keyword veto currently catches only ~50 of the expected ~1,000 non-tech rows.
>
> **Conservative real estimate:** **~5,100–5,500** clearly-tech Quebec startups, with the 6,507 headline being an upper bound. As we refine programmatic sector classification for the Harmonic long-tail, this bound will tighten downward.

---

## The pipeline at a glance

```mermaid
flowchart TB
    %% ========== RAW SOURCES ==========
    subgraph SRC["0 — RAW SOURCES"]
        DR_CSV["Dealroom<br/>(CSV export)"]
        HS_API["HubSpot<br/>(API sync)"]
        REQ_RAW["Quebec REQ<br/>(registry dump)"]
        RC_EXT["Réseau Capital<br/>(Harmonic + PitchBook,<br/>received as COMPANY_MASTER)"]
    end

    %% ========== BRONZE ==========
    subgraph BRONZE["1 — BRONZE (typed, landed)"]
        DR_BRONZE["DRM_COMPANY_BRONZE"]
        HS_RAW["HS_COMPANY_RAW"]
        REQ_CANON["REQ_CANONICAL"]
    end

    %% ========== SILVER — DR SIDE ==========
    subgraph SILVER_DR["2a — SILVER (Dealroom lane)"]
        DR_SILVER["DRM_COMPANY_SILVER<br/>normalized company fields"]
        DR_CLASS["DRM_STARTUP_CLASSIFICATION_SILVER<br/>A+/A/B/C/D rating"]
        DR_IND["DRM_INDUSTRY_SIGNALS_SILVER<br/>top-industry keywords"]
        DR_GEO["DRM_GEO_ENRICHMENT_SILVER<br/>city → region"]
        DR_BRIDGE["DRM_REGISTRY_BRIDGE_SILVER<br/>Dealroom ↔ NEQ"]
    end

    %% ========== SILVER — RC SIDE ==========
    subgraph SILVER_RC["2b — SILVER (Réseau Capital lane)"]
        RC_CM["COMPANY_MASTER<br/>Harmonic + PB merged,<br/>Quebec-filtered"]
        RC_PB["PITCHBOOK_ACQ_COMPANIES<br/>funding/headcount enrichment"]
    end

    %% ========== CROSS-SOURCE STAGING ==========
    subgraph STAGE["3 — CROSS-SOURCE STAGING"]
        ENT["T_ENTITIES<br/>one row per<br/>(source, company)"]
        VHS["V_HS_CLEAN<br/>normalized HS view"]
    end

    %% ========== MATCHING ==========
    subgraph MATCH["4 — MATCHING"]
        CLUSTERS["T_CLUSTERS_HS_DRM<br/>HubSpot ↔ Dealroom"]
        DR_RC["T_DRM_RC_MATCH_EDGES_DEDUP<br/>Dealroom ↔ Réseau Capital"]
    end

    %% ========== REVIEW ==========
    subgraph REVIEW["5 — MANUAL REVIEW (REF)"]
        REF["REF.MANUAL_REVIEW_DECISIONS<br/>whitelist / blacklist /<br/>C-promotion / sector calls"]
    end

    %% ========== GOLD ==========
    subgraph GOLD["6 — GOLD"]
        REGISTRY["GOLD.STARTUP_REGISTRY<br/>7,608 rows<br/>MATCHED / QT_ONLY / RC_ONLY"]
    end

    %% Edges
    DR_CSV --> DR_BRONZE --> DR_SILVER
    DR_SILVER --> DR_CLASS
    DR_SILVER --> DR_IND
    DR_SILVER --> DR_GEO
    DR_SILVER --> DR_BRIDGE
    REQ_RAW --> REQ_CANON --> DR_BRIDGE

    HS_API --> HS_RAW --> VHS

    RC_EXT --> RC_CM
    RC_EXT --> RC_PB

    DR_SILVER --> ENT
    VHS --> ENT
    REQ_CANON --> ENT
    RC_CM --> ENT

    ENT --> CLUSTERS
    ENT --> DR_RC
    DR_SILVER --> CLUSTERS
    VHS --> CLUSTERS
    DR_SILVER --> DR_RC
    RC_CM --> DR_RC

    DR_CLASS --> REGISTRY
    DR_SILVER --> REGISTRY
    DR_IND --> REGISTRY
    DR_GEO --> REGISTRY
    DR_BRIDGE --> REGISTRY
    CLUSTERS --> REGISTRY
    DR_RC --> REGISTRY
    RC_CM --> REGISTRY
    RC_PB --> REGISTRY
    REF --> REGISTRY

    classDef raw fill:#fef3c7,stroke:#d97706,color:#000
    classDef silver fill:#dbeafe,stroke:#1e40af,color:#000
    classDef match fill:#fce7f3,stroke:#be185d,color:#000
    classDef gold fill:#dcfce7,stroke:#166534,color:#000
    classDef ref fill:#ede9fe,stroke:#6d28d9,color:#000

    class DR_CSV,HS_API,REQ_RAW,RC_EXT raw
    class DR_BRONZE,HS_RAW,REQ_CANON,DR_SILVER,DR_CLASS,DR_IND,DR_GEO,DR_BRIDGE,RC_CM,RC_PB,ENT,VHS silver
    class CLUSTERS,DR_RC match
    class REGISTRY gold
    class REF ref
```

---

## Stage-by-stage walkthrough

### 0 — Raw sources

| Source | How we receive it | What's in it | Why we use it |
|---|---|---|---|
| **Dealroom** | CSV export, loaded by `dealroom_loader.py` | ~11K company profiles with ratings, industries, funding, HQ city | Primary source of truth for the "this is a startup" signal. Our whitelist is Dealroom A+/A/B. |
| **HubSpot** | API sync via `hubspot_sync.py` | All companies we've touched in our CRM | CRM context — deal status, contacts, partnership history. Used to enrich but not to define the registry. |
| **Quebec REQ** | Public registry dump (`REGISTRE_NOMS`, `ENTREPRISES_EN_FONCTION`) | Every registered Quebec legal entity with NEQ | Gives us the official NEQ identifier — the only unambiguous way to tie a Dealroom company to its legal entity. |
| **Réseau Capital** | Delivered to us as pre-merged `COMPANY_MASTER` (Harmonic + PitchBook, Quebec-filtered) | ~5K Quebec companies with funding, headcount, sectors | Captures the **VC-funded / deal-driven** population. Complements Dealroom's broader coverage. |
| _(PitchBook / Harmonic direct)_ | _Phase 2 — not yet activated_ | | |

### 1 — Bronze

**What we do:** Type everything (strings → dates, text → numbers), light cleanup (trim, null out empty strings), no business logic. One row per source row.

**Why:** Raw CSVs are full of surprises — inconsistent date formats, stray whitespace, CSV-escaping artifacts. Bronze gives us a stable foundation where we can run `SELECT *` without crashing.

**Tables:** `DRM_COMPANY_BRONZE`, `HS_COMPANY_RAW`, `REQ_CANONICAL`.

### 2a — Silver: Dealroom lane

This is where Dealroom data gets turned into something useful.

| Table | What it does | Why |
|---|---|---|
| `DRM_COMPANY_SILVER` | Normalizes domains, parses employee ranges, extracts funding to USD | We need one canonical shape for Dealroom companies across all downstream queries. |
| `DRM_STARTUP_CLASSIFICATION_SILVER` | Runs our rule-based classifier (`STARTUP_CLASSIFY_DEALROOM_V5`) → assigns each company an **A+/A/B/C/D** rating. Applies manual overrides from `REF.DRM_MANUAL_OVERRIDES`. | We can't include everything Dealroom has — Dealroom tracks 11K Quebec companies but many aren't really startups. The rating is our scope filter. |
| `DRM_INDUSTRY_SIGNALS_SILVER` | Keyword-matches Dealroom industry tags against `REF.INDUSTRY_KEYWORDS` → picks one top industry per company | Dealroom assigns multiple overlapping tags; we need a single "top industry" for reporting. |
| `DRM_GEO_ENRICHMENT_SILVER` | Maps city → region/MRC/agglomeration via `REF.CITY_REGION_MAPPING_NORM` | Raw cities are inconsistent (Montréal/Montreal/Mtl). Needed for regional breakdowns in reports. |
| `DRM_REGISTRY_BRIDGE_SILVER` | Matches Dealroom companies to the Quebec registry to attach an **NEQ**, using a tiered waterfall (NEQ-if-present → name similarity → Soundex) | NEQ is the only stable identifier for Quebec legal entities. Unlocks cross-ref with any official dataset. |

### 2b — Silver: Réseau Capital lane

Réseau Capital sends us pre-merged data, so our silver stage here is light:

- **`COMPANY_MASTER`** — the merged Harmonic + PitchBook view, already filtered to Quebec by record type (`HARMONIC_ONLY` / `PB_ONLY` / `BOTH`).
- **`PITCHBOOK_ACQ_COMPANIES`** — PitchBook-specific enrichment (headcount, total raised, revenue, financing status).

**Why we don't classify this side:** Réseau Capital is deal-driven — if a company is in there, it's because someone actually raised VC. No further filtering needed.

### 3 — Cross-source staging

**Table:** `T_ENTITIES` — one row per `(source, company_id)`, normalized fields (name, domain, LinkedIn, NEQ), with **blocking keys** for fast matching.

**Why:** The matcher needs all sources in the same shape. `T_ENTITIES` is the common ground where Dealroom, HubSpot, REQ, and RC all look alike.

`V_HS_CLEAN` is a parallel view for HubSpot that strips French column names and normalizes fields.

### 4 — Matching

Two separate matching jobs run here. Both use the same **tiered waterfall**: try deterministic keys first, fall back to fuzzy name similarity.

#### `T_CLUSTERS_HS_DRM` — HubSpot ↔ Dealroom
Label-propagation clustering. Deterministic edges on **NEQ / domain / LinkedIn**, then adds fuzzy name edges with similarity ≥ 0.92. Output: for each cluster of rows that represent the same company, one cluster ID.

**Why clustering and not 1:1 matching?** HubSpot has duplicates (companies we re-entered over time), and one Dealroom profile can correspond to several HubSpot rows.

#### `T_DRM_RC_MATCH_EDGES_DEDUP` — Dealroom ↔ Réseau Capital
1:1 match per side. Waterfall:
1. **Domain** (tier 1) — normalized website match
2. **LinkedIn slug** (tier 2)
3. **Crunchbase slug** (tier 3)
4. **Name similarity** ≥ 0.85 (tier 4)

As of the last run: **2,857 matches** (25.7% of 11K Dealroom rows), distributed as 2,539 domain / 62 LinkedIn / 85 Crunchbase / 171 name-sim.

**Why the low match rate is normal:** Q1 diagnostics (2026-04-10) confirmed that rating-A Dealroom rows are dominated (95%) by bootstrapped companies with zero VC funding, and Réseau Capital is deal-driven. The population simply doesn't overlap much. This is a **coverage feature, not a bug** — it's why we do the outer join.

### 5 — Manual review

**Table:** `REF.MANUAL_REVIEW_DECISIONS` — append-only log of human calls on:

- **Match confirmations / rejections** — override a 63D edge
- **Startup confirmations / rejections** — whitelist or blacklist a company
- **Sector calls** — adjudicate gaming / pharma / services ambiguities

Pipeline consumes this via views (`V_MATCH_WHITELIST`, `V_STARTUP_BLACKLIST`, etc.) so decisions auto-apply on the next build.

**Why this exists:** Automated classification is ~95% right, but the last 5% needs a human and needs to be reversible. Decisions are append-only so we can always audit and roll back.

### 6 — Gold: the registry

**Table:** `GOLD.STARTUP_REGISTRY`. One row per unique company, tagged as `MATCHED`, `QT_ONLY`, or `RC_ONLY`.

**How it's built:**
1. **QT candidates** = Dealroom A+/A/B + C-rated-and-matched-to-RC (promoted) + manually whitelisted, minus blacklisted. Rich with NEQ, HubSpot link, region, top industry.
2. **RC universe** = all Quebec `COMPANY_MASTER` rows + PitchBook enrichment, minus blacklisted.
3. **Outer join** via `T_DRM_RC_MATCH_EDGES_DEDUP`:
   - DR row + RC row both present → `MATCHED`
   - DR row only → `QT_ONLY`
   - RC row only → `RC_ONLY`

Each row carries:
- **Inclusion reason** (`QT_INCLUSION_REASON`): `CLS_APLUS` / `CLS_A` / `CLS_B` / `C_PROMOTED_RC_MATCH` / `MANUAL_WHITELIST` / `RC_ONLY`
- **Effective rating** (`RATING_LETTER_EFFECTIVE`) after promotion/whitelist
- **Source coverage flags**: `HAS_DEALROOM`, `HAS_HUBSPOT`, `HAS_RC`, `HAS_REQ`, `N_SOURCES`
- **Conflict flags** for matched rows: name / domain / city / year / employee / low-confidence
- **Sector flags**: `FLAG_SECTOR_GAMING`, `FLAG_SECTOR_PHARMA_BIOTECH`, `FLAG_SECTOR_SERVICES`
- **Review state**: `IS_STARTUP_WHITELISTED`, `IS_STARTUP_BLACKLISTED`
- **Review rollup**: `FLAG_NEEDS_REVIEW` — any flag above → surface to triage queue

---

## Row-count waypoints (2026-04-13)

### Raw / Silver — what each source brings to the table

| Stage | Table | Row count | Note |
|---|---|---:|---|
| Silver (DR) | `DRM_COMPANY_SILVER` | **11,136** | every Quebec company Dealroom tracks |
| Silver (DR) | `DRM_STARTUP_CLASSIFICATION_SILVER` — A+ | **198** | top-tier startups |
| Silver (DR) | `DRM_STARTUP_CLASSIFICATION_SILVER` — A | **2,376** | core startups |
| Silver (DR) | `DRM_STARTUP_CLASSIFICATION_SILVER` — B | **1,621** | borderline startups |
| Silver (DR) | `DRM_STARTUP_CLASSIFICATION_SILVER` — C | **5,277** | non-startup signal, eligible for promotion |
| Silver (DR) | `DRM_STARTUP_CLASSIFICATION_SILVER` — D | **1,664** | clearly not startups |
| Silver (DR) | `DRM_REGISTRY_BRIDGE_SILVER` — with NEQ | **8,375** / 11,136 | 75% of DR companies linked to REQ |
| Silver (RC) | `COMPANY_MASTER` — `HARMONIC_ONLY` | **2,984** | Harmonic long-tail scraping |
| Silver (RC) | `COMPANY_MASTER` — `PB_ONLY` | **487** | PitchBook deal-driven only |
| Silver (RC) | `COMPANY_MASTER` — `MATCHED` (H + PB) | **1,612** | present in both |
| Silver (RC) | `COMPANY_MASTER` — total Quebec | **5,083** | |
| Silver (RC) | `PITCHBOOK_ACQ_COMPANIES` | **40,019** | global PB enrichment (not Quebec-filtered) |
| Raw reference | Quebec REQ `REGISTRE_NOMS` | **1,357,447** | ~1.4M legal name records in the registry |

### Cross-source staging

| Stage | Table | Row count | Note |
|---|---|---:|---|
| Staging | `T_ENTITIES` — `DEALROOM` | **11,136** | |
| Staging | `T_ENTITIES` — `HUBSPOT` | **18,318** | includes historical CRM entries |
| Staging | `T_ENTITIES` — `REGISTRY` | **730,824** | REQ rows imported as entities |
| Staging | `T_ENTITIES` — total | **760,278** | |

### Matching

| Stage | Table / tier | Row count |
|---|---|---:|
| DR ↔ RC match | Tier 1 — DOMAIN | **2,539** |
| DR ↔ RC match | Tier 2 — LINKEDIN | **62** |
| DR ↔ RC match | Tier 3 — CRUNCHBASE | **85** |
| DR ↔ RC match | Tier 4 — NAME_SIM | **171** |
| DR ↔ RC match | `T_DRM_RC_MATCH_EDGES_DEDUP` total | **2,857** |
| HS ↔ DR cluster | DR-side rows | 11,135 → **11,067** clusters |
| HS ↔ DR cluster | HS-side rows | 18,066 → **17,768** clusters |

### Gold — final registry (post-whitelist, 2026-04-14)

| Stage | Cut | Row count |
|---|---|---:|
| **Gold — MATCHED** | both DR and RC | **2,667** |
| **Gold — QT_ONLY** | DR only (incl. C-promoted) | **2,559** |
| **Gold — RC_ONLY** | RC only | **2,381** |
| **Gold — TOTAL** | registry | **7,607** |
| **Startups v3 (full filter)** | | **6,507** |
| ↳ from MATCHED | | 2,356 |
| ↳ from QT_ONLY | | 2,295 |
| ↳ from RC_ONLY | | 1,856 |
| Active (post-2010 operational) | | 3,355 |
| Mature (1991–2010 operational) | | 1,743 |
| Acquired | | 495 |
| Closed | | 235 |
| Unknown age | | 650 |

Refresh waypoints via `ecosystem/sql/00_diagnostics/pipeline_row_counts.sql` and `Q3_startup_filter_and_lifecycle.sql`.

### Manual review (REF)

Empty as of this run — review queue infrastructure is in place but no decisions have been uploaded yet.

Refresh all numbers by running `ecosystem/sql/00_diagnostics/pipeline_row_counts.sql` (next section).

---

## Startup definition and lifecycle taxonomy

The `STARTUP_REGISTRY` table is our raw universe of companies from all sources. When a team member asks "how many Quebec startups do we have?", we apply a **startup filter** on top of the registry.

### Canonical startup filter (v3, 2026-04-14)

```sql
ENTITY_TYPE IN ('MATCHED', 'QT_ONLY', 'RC_ONLY')                    -- all three sides
AND NOT COALESCE(IS_STARTUP_BLACKLISTED, FALSE)                      -- manual blacklist veto
AND NOT UNIFIED_NON_TECH_NAME_HIT                                    -- non-tech veto (DR + RC)
AND (COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR) IS NULL              -- pre-internet cutoff
     OR COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR) > 1990)
```

**Unified fields** (via COALESCE):
- `UNIFIED_LAUNCH_YEAR = COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR)` — prefer Dealroom's year, fall back to Réseau Capital's.
- `UNIFIED_STATUS` — prefer `DRM_COMPANY_STATUS`, then regex-map `RC_BUSINESS_STATUS` ('acquir|merged' → acquired; 'out of business|closed|dissolv|wound|bankrupt|defunct' → closed); default to 'operational' for RC_ONLY rows with no PB status (Harmonic presence = alive signal).

**Why the pre-1990 cut:** companies born before the internet era aren't meaningfully "startups" by any contemporary definition. Null unified launch year is kept as an `unknown_age` bucket rather than dropped, so ~650 operational rows with incomplete profiles stay visible for triage.

**Why the non-tech-name veto** is applied on both sides: Q2 (2026-04-10) sampled 50 unmatched rating-A Dealroom rows and found a consistent pattern of companies mislabeled as "ICT / Enterprise Software" that are actually reno shops, moving companies, services agencies, etc. Q4 (2026-04-14) extended the same keyword list to RC_ONLY rows (`RC_NAME`) so we catch the obvious non-tech by name on both sides. The list is deliberately conservative — we'd rather under-veto and surface ambiguous rows for review than over-veto and cut legitimate tech companies.

---

### Why the count changes when we include RC

The single most common question stakeholders ask is "why did the number jump?" Here is the full waterfall so anyone can challenge any step:

```
7,607   raw registry (post-whitelist rebuild, 2026-04-14)
          = 2,667 MATCHED (DR + RC) + 2,559 QT_ONLY + 2,381 RC_ONLY

  −960   pre-1990 rows (pre-internet cutoff, unified launch year)
          ↳ ~485 on the QT-anchored side
          ↳ ~475 on the RC_ONLY side

   −64   non-tech name hits (DR side — Rénovation, Déménagement, etc.)

   −76   additional non-tech name hits (RC side — yogurt, chiro, insurance, etc.)

    −0   blacklisted (REF.MANUAL_REVIEW_DECISIONS currently empty)

= 6,507  startups (after filter) — upper bound
          ↳ 4,651 QT-anchored (2,356 MATCHED + 2,295 QT_ONLY)
          ↳ 1,856 RC_ONLY

Quality adjustment (Q4 manual eyeball of 95 RC_ONLY rows):
          ~24% clearly tech       →   ~460 real new tech startups
          ~22% ambiguous           →   ~420 maybe-tech
          ~54% clearly non-tech    → ~1,050 should not count

−~1,000  estimated RC_ONLY pollution not yet caught by name veto
          (dark matter: 1,880 Harmonic rows with no sector signal)

≈ 5,100-5,500  conservative real tech startup count
```

**How to read this for stakeholders:**

- **If you trust our filter and want the broadest defensible count:** 6,507.
- **If you want a conservative estimate after accounting for Harmonic pollution:** ~5,100–5,500.
- **If you want only the companies Dealroom directly classifies as startups:** 4,651.

All three numbers answer different questions. The "real" answer depends on what you're measuring for:
- Government relations / policy briefs → 5,100–5,500 (defensible mid-point)
- Annual ecosystem portrait → 6,507 with the caveat footnote
- Internal analytics needing precision → 4,651 (highest-quality subset only)

**What's driving the gap between 6,507 and ~5,300:** The Réseau Capital extension brings real coverage of VC-funded Quebec companies, but Harmonic's underlying data source is broad scraping that includes many non-tech businesses. Until we either (a) get better sector tags from our partners or (b) build name/description-based classification for the 1,880 dark-matter rows, the upper and lower bounds are the right way to talk about it.

**Open questions for the data partnership conversation:**
1. Does Harmonic expose a richer sector taxonomy we could pull through?
2. Where does PitchBook track acquisitions if not in `BUSINESS_STATUS`?
3. How do other users of this data handle the pre-internet cutoff?

These are tracked in memory and will feed the next partner catch-up.

### Lifecycle buckets

```
acquired     → DRM_COMPANY_STATUS = 'acquired'
closed       → DRM_COMPANY_STATUS IN ('closed', 'low-activity')
mature       → operational AND 1991 ≤ launch_year ≤ 2010
active       → operational AND launch_year ≥ 2011
unknown_age  → operational AND launch_year IS NULL
```

**Why age-only:** an earlier v1 rule used size and capital triggers too (`employees ≥ 250 OR funding ≥ $100M`). In practice those triggers fired on ~6% and ~1.5% of mature rows — age alone captured 99% of the signal. Dropping them simplified the story without losing anything meaningful.

**How to tune:** thresholds live in `ecosystem/sql/00_diagnostics/Q3_startup_filter_and_lifecycle.sql`. Edit the `>` and `>=` values in the `_Q3_STARTUPS` CREATE statement; no other file needs to change.

### Sector flags

Pharma / biotech / services / gaming are **flags on the rows, not exclusions from the filter**. Legitimate startups exist in all of these sectors. The flags let us surface sub-ecosystem cuts (like the pharma 58%-active or gaming 64%-active findings above) without removing them from the main count.

### What's intentionally not a startup
- `ENTITY_TYPE = 'RC_ONLY'` — *until v3 ships.* These are Réseau Capital Quebec companies not in Dealroom's A+/A/B whitelist.
- `DRM_LAUNCH_YEAR ≤ 1990` — pre-internet era.
- `FLAG_NON_TECH_NAME_HIT = TRUE` — non-tech name veto pending manual review.
- `IS_STARTUP_BLACKLISTED = TRUE` — manually rejected via `REF.MANUAL_REVIEW_DECISIONS`.

---

## How to refresh the numbers

Run `ecosystem/sql/00_diagnostics/pipeline_row_counts.sql` in Snowsight. It hits every waypoint table with a single-column `COUNT(*)` query — cheap. Output is one CSV per stage, matches the waypoints table above. Drop the CSVs back to the assistant to regenerate the diagram annotations.

## What's intentionally omitted

These folders exist in the SQL tree but are **not** part of the registry pipeline:

- `50_analytics/` — ad-hoc analysis queries
- `65_cluster_conflicts/`, `66_golden_per_cluster/` — audit/resolution support
- `67_push_list_hubspot/`, `68_push_list_dealroom/` — push-back enrichments from registry → source systems (reverse direction)
- `69_operational_tables/` — operational audit tables
- `70_req_discovery/` — REQ-based discovery queue (deprioritized 2026-04-08, kept for enrichment only)
- `90_tests/` — smoke tests

Keeping the main diagram clean of these makes it easier to explain.
