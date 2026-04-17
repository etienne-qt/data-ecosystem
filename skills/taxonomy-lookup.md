# Skill: Taxonomy Lookup

## Purpose
This skill teaches you how to reference and apply the shared taxonomy definitions used across Quebec Tech, Réseau Capital, and CIQ.

## When to use
- Classifying a company by sector, stage, or geography
- Filtering or grouping Snowflake queries by category
- Validating that an analysis uses canonical codes
- Checking whether a company qualifies as a "startup" under the shared criteria

## Key files
- `taxonomy/sectors.yaml` — Sector and industry codes with hierarchical parent-child relationships
- `taxonomy/stages.yaml` — Funding stage definitions (pre-seed, seed, series A, etc.) with criteria
- `taxonomy/startup-criteria.yaml` — What qualifies a company as a startup for ecosystem metrics
- `taxonomy/geographies.yaml` — Region and city codes for Quebec and comparison regions
- `taxonomy/labels.yaml` — Tags, flags, and categorical labels

## Rules
1. **Always use taxonomy codes, never free text.** If you're writing a query that filters by sector, use the code from `sectors.yaml`, not an ad-hoc string.
2. **Check the `excludes` field.** Many categories have explicit exclusion rules. For example, a company that uses AI as a feature but sells a SaaS product is classified under its primary product sector, not AI.
3. **Hierarchical codes roll up.** If a company is coded `AI`, it also counts under its parent `ICT`. Queries at the parent level should include all children.
4. **When a company doesn't fit any existing code**, flag it rather than inventing a new one. Taxonomy changes require a `taxonomy/` branch and cross-org PR review.
5. **Stage definitions have quantitative thresholds** (e.g., revenue ranges, employee counts, funding amounts). Apply them consistently — don't classify by gut feeling.

## How to read the YAML
```yaml
sectors:
  - code: AI                          # Use this in queries and insights
    label_en: "Artificial intelligence"
    label_fr: "Intelligence artificielle"
    parent: ICT                        # Rolls up to this parent
    description: "Core product relies on AI/ML"
    includes:                          # Positive examples
      - "Machine learning platforms"
    excludes:                          # What does NOT count
      - "Companies that merely use AI as a feature"
```

## In practice
When Claude Code is asked to classify a company or build a sector breakdown:
1. Read the relevant taxonomy YAML file
2. Match against the `description`, `includes`, and `excludes` fields
3. Use the `code` value in any output (insights, queries, reports)
4. If multiple codes apply, use the primary product/service to determine the lead code, and list secondary codes if relevant
