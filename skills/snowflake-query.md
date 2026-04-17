# Skill: Snowflake Query

## Purpose
This skill teaches you how to query the shared Snowflake instance using the conventions, schemas, and taxonomy of this repo.

## When to use
- Building SQL queries against the shared ecosystem database
- Exploring data for a report or scratch analysis
- Producing aggregate findings for insight files
- Validating data quality across sources

## Connection

**Current operating mode (April 2026): Claude Code does NOT connect directly to Snowflake.** There is no wired MCP server yet. The workflow is:

1. Claude Code writes the SQL in a file under `pipelines/` or inline in the chat.
2. The human analyst runs the SQL in Snowsight (or `snowsql`) using their own credentials.
3. The analyst saves query results as CSV to the local `data/` directory.
4. The analyst hands the CSV (or a summary) back to Claude Code for interpretation.

This is the same code-generation pattern Quebec Tech has used internally for months. It keeps credentials out of the repo and out of Claude sessions, and it keeps raw record-level results on the analyst's machine rather than in any shared context.

**Future state:** once a vetted Snowflake MCP server is chosen and wired in, Claude will be able to run queries directly. Until then, assume Snowflake is out-of-band.

The shared database is `shared_ecosystem` with schemas per org (see `docs/snowflake-schemas.md`).

## Query conventions

### Always use fully qualified names
```sql
SELECT * FROM shared_ecosystem.qt_schema.companies
-- Never: SELECT * FROM companies
```

### Always use taxonomy codes for filtering
```sql
-- Correct: use the code from taxonomy/sectors.yaml
WHERE sector_primary = 'AI'

-- Wrong: use free text
WHERE sector_primary = 'Artificial Intelligence'
WHERE sector LIKE '%AI%'
```

### Date conventions
- Date fields use `YYYY-MM-DD` format
- For period-based analysis, use `DATE_TRUNC('quarter', date_field)`
- Year references: `YEAR(date_field) = 2024`

### Currency
- Default currency is CAD unless the column name specifies otherwise
- When comparing across sources, verify the currency before aggregating
- Conversion rates should be documented if applied

## Aggregation for insights

When query results will be committed as insights, aggregate before extracting:

```sql
-- For insight: aggregate counts and totals
SELECT
    YEAR(deal_date) AS period,
    sector_primary,
    COUNT(*) AS deal_count,
    SUM(deal_amount_cad) AS total_invested,
    MEDIAN(deal_amount_cad) AS median_deal_size
FROM shared_ecosystem.rc_schema.vc_deals
WHERE geography = 'QC'
GROUP BY 1, 2
HAVING COUNT(*) >= 5  -- minimum aggregation threshold
ORDER BY 1 DESC, 3 DESC;
```

```sql
-- For local exploration: record-level is fine (stays on your machine)
SELECT company_name, deal_amount_cad, deal_date, investor_names
FROM shared_ecosystem.rc_schema.vc_deals
WHERE YEAR(deal_date) = 2024 AND sector_primary = 'AI';
```

### Minimum aggregation thresholds
- Group counts must be >= 5 records before committing
- If a group has < 5 records, combine with adjacent categories or label as "other"
- This prevents re-identification of individual deals from licensed data

## Common query patterns

### Ecosystem snapshot
```sql
-- Active startup count by sector
SELECT
    s.sector_primary,
    COUNT(DISTINCT s.company_id) AS startup_count
FROM shared_ecosystem.shared_views.company_master s
WHERE s.status = 'active'
    AND s.meets_startup_criteria = TRUE
GROUP BY 1
ORDER BY 2 DESC;
```

### Funding trends
```sql
-- Quarterly VC investment in Quebec
SELECT
    DATE_TRUNC('quarter', d.deal_date) AS quarter,
    COUNT(*) AS deal_count,
    SUM(d.deal_amount_cad) AS total_invested_cad
FROM shared_ecosystem.rc_schema.vc_deals d
WHERE d.geography = 'QC'
GROUP BY 1
ORDER BY 1;
```

### Cross-source joins
```sql
-- Combine Dealroom company data with RC deal data
SELECT
    c.company_name,
    c.sector_primary,
    COUNT(d.deal_id) AS total_deals,
    SUM(d.deal_amount_cad) AS total_raised_cad
FROM shared_ecosystem.qt_schema.companies c
LEFT JOIN shared_ecosystem.rc_schema.vc_deals d
    ON c.company_id = d.company_id
WHERE c.geography = 'QC'
GROUP BY 1, 2;
```

## Output rules
- **Local exploration (scratch/ branches):** query freely, no aggregation required
- **For committed insights:** aggregate and apply the 5-record minimum threshold
- **For pipeline scripts:** the script itself is committable; the data it produces stays local or in Snowflake
- **Never embed query results as raw data in committed files** — extract the aggregate finding and format as an insight

## The handoff loop (until MCP is wired)

A typical round-trip:

1. **Claude writes the query.** It lands in `pipelines/validation/diagnostics/Qn_<question>.sql` if it's a one-off investigation, or in `pipelines/transforms/` / `pipelines/enrichment/` if it's part of the pipeline. Commit the SQL file on your working branch so reviewers see the query that produced a finding.
2. **Analyst runs it in Snowsight.** Paste the SQL, check the warehouse, run each section, save each result grid as CSV to `data/outputs/<branch-slug>-YYYYMMDD/`.
3. **Claude reads the CSV.** Paste the CSV content into the chat (small files) or reference the path (`@data/outputs/.../file.csv`) and ask Claude to summarize or produce the insight.
4. **Promote the finding.** If it's worth keeping, Claude drafts the insight markdown following `skills/insight-extractor.md`. The insight commits; the CSV stays in `data/`.

Keep SQL files read-only when they're diagnostics (`pipelines/validation/diagnostics/`). Transforms are the only layer that writes tables.
