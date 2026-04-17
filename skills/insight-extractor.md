# Skill: Insight Extractor

## Purpose
This skill teaches you how to extract findings from analyses and reports and structure them as committable insight files that respect data governance rules.

## When to use
- After completing an analysis on a `report/` or `scratch/` branch
- When extracting key findings from a published report (PDF or web)
- When a Snowflake query produces a finding worth preserving
- When promoting a scratch branch discovery to main

## Output format

Every insight is a markdown file with YAML frontmatter, saved to `insights/{period}/`:

```yaml
---
id: "{period}-{topic}-{sequence}"       # e.g., "2026-q2-vc-001"
source: "Human-readable source name"
source_type: licensed | public | derived
date_extracted: YYYY-MM-DD
report_branch: "report/branch-name"      # if applicable, null otherwise
topics:                                   # use taxonomy codes
  - funding
  - seed-stage
geography: quebec                         # use taxonomy geography codes
period: "2024"                            # the period the data describes
confidence: high | medium | low
data_points:
  - metric: metric_name                  # snake_case, descriptive
    value: 2000000000
    unit: CAD | USD | ratio | percent | count
    period: "2024"
---

Narrative summary of the finding in plain language. This should be
self-contained — a reader should understand the insight without
looking at the structured data above.
```

## Data governance checks — apply before every commit

Before structuring any finding as an insight, verify:

### Source type classification
- **`licensed`**: Data derived from Dealroom, PitchBook, CVCA Intelligence, or other commercially licensed platforms. **Only aggregate numbers are permitted.** No company names, deal IDs, or record-level attributes from these sources.
- **`public`**: Data from freely available sources — Statistics Canada, OECD, published press releases, company websites, government registries. Record-level references are permitted with attribution.
- **`derived`**: Computed from a combination of sources or from your own analysis. Apply the most restrictive source rule — if any input is licensed, the output follows licensed rules.

### Aggregation test
For `source_type: licensed` or `source_type: derived` with licensed inputs, every `data_point` must pass this test:

> Could this number be traced back to a specific record in the licensed database?

- **"39 seed deals in Quebec"** → passes (aggregate count)
- **"Company X raised $5M Series A"** → fails if sourced from PitchBook (record-level)
- **"Company X raised $5M Series A"** → passes if sourced from a public press release (set `source_type: public` and cite the source)
- **"Median seed round: $2.5M"** → passes (statistical aggregate)
- **"Top 5 largest deals"** → borderline — if this effectively identifies specific companies from licensed data, it fails. If the companies are publicly known, cite public sources instead.

### Minimum aggregation thresholds
- Counts: minimum 5 records in the group (to prevent re-identification)
- Breakdowns: if a category has fewer than 5 entries, combine it with adjacent categories or report as "other"

## Naming conventions
- File name: `{topic-slug}.md` (e.g., `vc-overview.md`, `ai-index.md`, `scaleup-gaps.md`)
- ID format: `{year}-{quarter}-{topic}-{sequence}` (e.g., `2026-q2-vc-001`)
- Metrics use snake_case: `total_vc_invested`, `seed_deal_count`, `yoy_change_pct`
- Topics use taxonomy codes from `taxonomy/sectors.yaml` and `taxonomy/labels.yaml`

## Updating the index

After creating new insight files, update `insights/index.yaml` to include the new entries:

```yaml
insights:
  - id: "2026-q2-vc-001"
    file: "2026-q2/vc-overview.md"
    title: "Q2 2026 Quebec VC overview"
    topics: [funding, quebec-vc]
    date_extracted: 2026-04-17
```

This index is what Claude Code reads to search across all insights efficiently.

## In practice

When asked to "extract the key findings from this analysis":
1. Identify each distinct finding
2. Classify the source type for each
3. Verify aggregation compliance for licensed sources
4. Structure each as a separate data point in the frontmatter
5. Write a narrative summary that stands alone
6. Save to the appropriate `insights/{period}/` directory
7. Update `insights/index.yaml`
