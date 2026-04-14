---
title: Entity Resolution Consolidation Plan
category: internal
created: 2026-03-05
status: planned
---

# Consolidated Company Registry — Entity Resolution Expansion Plan

## Context

We have a working entity resolution pipeline in Snowflake (sql/61-69) that matches companies across 3 sources: HubSpot, Dealroom, and Quebec Registry. It produces a golden record (`T_CLUSTER_GOLDEN`) with 4 fields (NEQ, domain, LinkedIn, name) for conflict-free clusters. We need to:

1. **Add Pitchbook and Harmonic** as new data sources
2. **Build a consolidated registry table** (`T_COMPANY_REGISTRY`) — a permanent, single-source-of-truth table
3. **Match using priority ordering**: domain → LinkedIn → NEQ → name (last resort)

Column names for Pitchbook and Harmonic will be provided later. The plan is designed so that scaffolding can be built now and activated with minimal changes once schemas arrive.

---

## Matching Strategy

### Match Key Priority (applied in edge creation order)
1. **Domain/website** — deterministic, score 0.95
2. **LinkedIn URL/slug** — deterministic, score 0.95
3. **NEQ (registry number)** — deterministic, score 1.0
4. **Name similarity** — fuzzy fallback (NAME_SIM >= 0.90), only for entities with no deterministic match, blocked by (P4, TOK1) with stopword filtering

### Source Priority (for golden record field selection)
```
REGISTRY > PITCHBOOK > DEALROOM > HARMONIC > HUBSPOT
```
- Registry: legal ground truth (NEQ, legal name)
- Pitchbook: institutional-grade, high precision
- Dealroom: curated, already trusted in pipeline
- Harmonic: strong on newer startups
- HubSpot: internal CRM, user-entered

### Key Architecture Decision
The existing pipeline architecture (staging → entities → edges → clusters → golden) is solid. We **extend** it, not rebuild it. The generalization uses `a.SRC < b.SRC` self-joins on `T_ENTITIES` instead of hard-coded source pairs, making the pipeline source-count-agnostic.

---

## What Changes Where

```
sql/61_clean_staging_views/
  61A_hubspot_clean.sql           UNCHANGED
  61B_dealroom_clean.sql          UNCHANGED
  61C_req_clean.sql               UNCHANGED
  61D_pitchbook_clean.sql         NEW (stub → Phase 2)
  61E_harmonic_clean.sql          NEW (stub → Phase 2)

sql/62_unified_entity_table/
  unified_entity_table.sql        MODIFY — add PB + HAR UNION ALL arms

sql/63_match_edges/
  63A_deterministic_edges.sql     REWRITE — generic SRC < SRC cross-join
  63B_name_similarity_edges.sql   REWRITE — generic unmatched fallback

sql/64_build_clusters/
  clusters_enhanced.sql           MODIFY — rename tables, update priority

sql/65_cluster_conflicts/
  conflicts.sql                   MODIFY — read from T_ENTITIES

sql/66_golden_per_cluster/
  golden_clusters.sql             REWRITE — 5-source priority, expanded fields

sql/69_operational_tables/
  T_COMPANY_REGISTRY.sql          NEW — permanent consolidated table + MERGE
  company_resolution_map.sql      MODIFY — read from T_ENTITIES

sql/90_tests/
  91_registry_smoke_tests.sql     NEW — validation queries
```

### Table Renames
| Old | New |
|-----|-----|
| `T_ENTITIES_HS_DRM` | `T_ENTITIES` |
| `T_EDGES_HS_DRM` | `T_EDGES_ALL_RAW` |
| `T_EDGES_HS_DRM_DEDUP` | `T_EDGES_ALL_DEDUP` |
| `T_CLUSTERS_HS_DRM` | `T_CLUSTERS_COMMERCIAL` |
| `T_UNDIRECTED_HS_DRM` | `T_UNDIRECTED` |

Backward-compat view: `T_ENTITIES_HS_DRM AS SELECT * FROM T_ENTITIES WHERE SRC IN ('HUBSPOT','DEALROOM')` — keeps push-list SQL (67/68) working unchanged.

---

## Consolidated Registry Table Schema (Lean — Identifiers Only)

```sql
CREATE TABLE IF NOT EXISTS DEV_QUEBECTECH.UTIL.T_COMPANY_REGISTRY (
  CLUSTER_ID              VARCHAR NOT NULL PRIMARY KEY,

  -- Core identifiers
  GOLD_NEQ                VARCHAR,
  GOLD_DOMAIN             VARCHAR,
  GOLD_LINKEDIN           VARCHAR,
  GOLD_WEBSITE            VARCHAR,
  GOLD_NAME               VARCHAR,

  -- Cross-reference IDs (one per source)
  GOLD_REGISTRY_NEQ       VARCHAR,
  GOLD_PITCHBOOK_ID       VARCHAR,
  GOLD_DEALROOM_ID        VARCHAR,
  GOLD_HARMONIC_ID        VARCHAR,
  GOLD_HUBSPOT_ID         VARCHAR,

  -- Conflict flags
  FLAG_ANY_CONFLICT       BOOLEAN DEFAULT FALSE,
  FLAG_NEQ_CONFLICT       BOOLEAN DEFAULT FALSE,
  FLAG_DOMAIN_CONFLICT    BOOLEAN DEFAULT FALSE,
  FLAG_LINKEDIN_CONFLICT  BOOLEAN DEFAULT FALSE,

  -- Metadata
  DATA_SOURCES            VARCHAR,
  SOURCE_COUNT            NUMBER(2,0),
  LAST_PIPELINE_RUN_AT    TIMESTAMP_TZ NOT NULL
) CLUSTER BY (GOLD_NEQ, GOLD_DOMAIN, GOLD_LINKEDIN);
```

Descriptive/financial fields are NOT in this table — join to source tables via cross-reference IDs when needed.

---

## Implementation Phases

### Phase 1: Scaffolding (no column names needed)

Three parallel sub-agents in separate worktrees:

**Sub-agent A** (`feature/registry-entities-expansion`):
- Create stub views `61D_pitchbook_clean.sql`, `61E_harmonic_clean.sql`
- Expand `62_unified_entity_table.sql` with PB + HAR arms
- Add backward-compat alias `T_ENTITIES_HS_DRM`

**Sub-agent B** (`feature/registry-edges-expansion`):
- Rewrite `63A_deterministic_edges.sql` with generic `SRC < SRC` pattern
- Rewrite `63B_name_similarity_edges.sql` for unmatched-only fallback
- Update table references in `clusters_enhanced.sql` and `conflicts.sql`

**Sub-agent C** (`feature/registry-golden-and-output`):
- Redesign `golden_clusters.sql` with 5-source priority + expanded fields
- Create `T_COMPANY_REGISTRY.sql` (DDL + MERGE)
- Update `company_resolution_map.sql`
- Create `91_registry_smoke_tests.sql`

Merge order: A → B → C.

### Phase 2: Activation (after column names arrive)

- Fill in `61D_pitchbook_clean.sql` and `61E_harmonic_clean.sql` bodies
- Run full pipeline end-to-end
- Run smoke tests

### Phase 3: Validation & Tuning

- Check conflict rate (target < 5%)
- Check name-sim candidate set size
- Spot-check 5-source clusters
- Verify no duplicate GOLD_NEQ or GOLD_DOMAIN in safe clusters
- Regression: HS-DRM cluster count should not decrease

---

## Smoke Tests

1. Row count by source in `T_ENTITIES`
2. Edge count by match type and source pair
3. Cluster size distribution by `SOURCE_COUNT`
4. Conflict rate (% with `FLAG_ANY_CONFLICT`)
5. Golden record completeness (% with each field)
6. Duplicate check on safe clusters
7. Regression: HS-DRM cluster count vs baseline

---

## Risks

| Risk | Mitigation |
|------|-----------|
| PB/Harmonic don't carry NEQ | Set `*_NEQ_NORM = NULL` |
| Name-sim explosion with 5 sources | `SRC < SRC` + (P4,TOK1) + stopwords |
| Conflict rate spikes | Monitor; tighten thresholds if needed |
| Subdomain noise in Harmonic | `NORM_DOMAIN` already handles this |
