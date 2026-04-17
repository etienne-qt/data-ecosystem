# Skill: Data Enrichment

## Purpose
This skill teaches you how to enrich startup and company datasets by cross-referencing multiple sources, while respecting data governance rules.

## When to use
- Filling gaps in a dataset (missing sectors, funding amounts, headcounts)
- Cross-referencing Dealroom, Snowflake, and public web sources
- Validating existing data against external sources
- Enriching partner-submitted datasets (e.g., university spinoff lists)

## Enrichment workflow

1. **Assess the dataset** — Identify which fields are missing or incomplete
2. **Prioritize by source** — Use this lookup order:
   - Snowflake shared tables (most reliable, already curated)
   - Dealroom / PitchBook via Snowflake (licensed, record-level ok locally)
   - Public web sources (company websites, LinkedIn, press releases, REQ)
   - Manual research (last resort)
3. **Enrich locally** — All enrichment work happens in `data/` (gitignored) or in memory
4. **Commit only the code** — The enrichment script goes to `pipelines/enrichment/`, the enriched dataset stays local or goes back to Snowflake
5. **Extract insights if valuable** — If the enrichment reveals aggregate findings, format as an insight

## What gets committed

| Committable | Not committable |
|------------|----------------|
| Enrichment Python script | The enriched CSV/Excel file |
| Methodology documentation | Raw data exports used as input |
| Aggregate findings as insights | Record-level enrichment results |
| Validation reports (pass/fail counts) | Lists of specific companies with licensed data |

## Enrichment script conventions

Scripts in `pipelines/enrichment/` should:
- Read input from `data/` (gitignored) or Snowflake
- Write output to `data/` (gitignored) or back to Snowflake
- Use taxonomy codes for any sector/stage classification
- Log enrichment statistics (how many records filled, from which source)
- Be idempotent — running twice produces the same result

## Public source attribution

When enriching from public sources, track the source per field:
- Add a `_source` column for each enriched field (e.g., `city_source: "company_website"`)
- This helps reviewers verify that public claims are genuinely public

## Quality checks

After enrichment, validate:
- Sector codes match `taxonomy/sectors.yaml`
- Stage codes match `taxonomy/stages.yaml`
- Funding amounts are in the expected currency
- No duplicate records introduced
- Completeness improved (compare before/after fill rates)
