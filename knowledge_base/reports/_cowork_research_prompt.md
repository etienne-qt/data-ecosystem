# Deep Research Prompt — Intelligence Pipeline

> Copy-paste this into a Claude Code cowork session.
> The prompt is self-contained — the cowork agent has no prior context.

---

## Prompt

You are helping build a research intelligence pipeline for Quebec Tech (QT), an organization that tracks and reports on Quebec's startup ecosystem. Your job is to **find, classify, and summarize external reports** about the Quebec/Canadian startup and tech ecosystem, then populate our structured knowledge base.

### Your mission

1. **Search the web** for the most important recurring reports about the Quebec and Canadian startup/tech/VC ecosystem. Think: annual VC reports, ecosystem rankings, government statistics, industry surveys, policy briefs.

2. For each report you find, **create a structured summary** in `ecosystem/knowledge_base/reports/summaries/{id}.md` following the template below.

3. **Update the registry** at `ecosystem/knowledge_base/reports/_registry.md` — append one row per report.

4. **Update the series tracker** at `ecosystem/knowledge_base/reports/_series.md` — group editions of recurring reports.

5. **Extract insights** and append them to:
   - `ecosystem/knowledge_base/insights/_index.csv` (one row per insight)
   - The relevant `ecosystem/knowledge_base/insights/by-topic/{topic}.md` files (add to "Key Themes" and "All Insights" table)
   - The relevant `ecosystem/knowledge_base/insights/by-geography/{geo}.md` files

### What reports to look for

Search for the latest available edition of each. Prioritize reports that contain **data** (not just opinion). Target 10-15 reports across these categories:

**Tier 1 — Must find (directly relevant to Quebec ecosystem)**
- CVCA annual VC & PE reports (Canadian VC landscape)
- Startup Genome GSER (Global Startup Ecosystem Report — Montreal ranking)
- BDC studies on Canadian entrepreneurship/VC
- Indice entrepreneurial québécois (IEQ) — Réseau Mentorat
- ISQ / Statistique Québec reports on innovation or tech sector
- Innovation, Science and Economic Development Canada (ISED) — Key Small Business Statistics or innovation indicators
- Réseau Capital annual survey or reports
- Quebec government innovation/startup reports (MEI, Investissement Québec)

**Tier 2 — Important context**
- OECD Entrepreneurship at a Glance or Science, Technology and Innovation Outlook
- PitchBook / Crunchbase annual VC reports (global context, Canada sections)
- Dealroom ecosystem reports (if publicly available)
- National Angel Capital Organization (NACO) reports
- Conference Board of Canada innovation reports
- StatCan Business Dynamics in Canada / SME reports

**Tier 3 — Sector-specific**
- CIFAR or Mila AI ecosystem reports
- Écotech Québec cleantech reports
- Life sciences / biotech Quebec reports (MEDTEQ, adMare, etc.)
- Montréal International tech talent reports

### Summary template

Each summary file must follow this exact structure. The frontmatter fields are critical for indexing.

```markdown
---
title: "Full Report Title"
report_id: publisher-year            # e.g., cvca-2024, gser-2025, ieq-2024
series_id: series-slug               # e.g., cvca-annual, gser, ieq
publisher: Organization Name
year: 2024
language: EN                         # EN, FR, or FR/EN
type: industry-report                # industry-report | government-report | academic-paper | ecosystem-ranking | survey | policy-brief
geography: canada                    # quebec | canada | north-america | international
topics: [funding, exits]             # from controlled vocabulary below
credibility: high                    # high | medium | low
date_ingested: 2026-04-08
pages: 0                             # approximate if unknown
url: "https://..."                   # direct link to report or landing page
---

# Full Report Title

## TL;DR
<!-- 2-3 sentences: the single most important takeaway for our work -->

## Key Data Points
<!-- Numbered list. Each tagged with [topic]. Be specific — include numbers. -->
1. **[funding]** Canadian VC investment totaled $X.XB in 2024

## Quebec-Specific Findings
<!-- Anything directly about Quebec or directly comparable -->
- Quebec captured X% of national VC

## Methodology & Limitations
- Data source and collection method
- What is excluded or not covered

## Relevance to Our Work
<!-- Map to analytical framework Q-codes if possible -->
- **Q5.1** (VC per capita): this report provides...

## Extracted Insights
<!-- 3-10 standalone insights per report. Each must be self-contained. -->

### INS-{report_id}-01: Short descriptive title
- **Claim:** One factual sentence with enough context to be useful in isolation
- **Topics:** funding, policy
- **Geography:** quebec, canada
- **Time:** 2024
- **Implication:** What this means for Quebec's ecosystem
- **Confidence:** high | medium | low
- **Source:** Page/section reference or "web summary" if working from abstract
```

### Controlled vocabulary for tags

**Topics (use only these):**
`ip-research`, `entrepreneurship`, `talent`, `incubation`, `funding`, `commercialization`, `exits`, `policy`, `ai-sector`, `cleantech-sector`, `healthtech-sector`, `macro-trends`

**Geography:**
`quebec`, `canada`, `north-america`, `international`

### Registry format

Append rows to the markdown table in `_registry.md`:

```
| cvca-2024 | CVCA 2024 VC Report | CVCA | cvca-annual | 2024 | EN | industry-report | canada | funding,exits | high | summaries/cvca-2024.md | 2026-04-08 |
```

### Insight index CSV format

Append rows to `insights/_index.csv`:

```
INS-cvca-2024-01,cvca-2024,"QC captured 25% of national VC dollars",funding,quebec;canada,2024,high,Q5.1
```

Use semicolons within multi-value fields (topics, geography). Keep `claim_short` under 80 characters.

### Series tracker format

In `_series.md`, add a section per series:

```markdown
### cvca-annual
- **Publisher:** CVCA
- **Frequency:** annual
- **Key metrics tracked:** Total VC ($), deal count, provincial split, stage mix
- **Editions ingested:**
  - [x] 2024 → [summary](summaries/cvca-2024.md)
  - [ ] 2023 (not yet ingested)
```

### Topic file updates

When adding insights to `insights/by-topic/{topic}.md`:
1. Add a row to the "All Insights" table
2. If a new theme emerges from multiple insights, add it under "Key Themes" with source references
3. Update the `sources_count` in frontmatter
4. Update the `updated` date in frontmatter

### Important rules

- **Summaries are always in English**, even for French-language reports. Keep French organization names and program names in French.
- **Be honest about depth.** If you can only find the report abstract or press release (not the full PDF), say so in the TL;DR and mark data points with "(from abstract)" or "(from press release)". Don't fabricate specific numbers.
- **Credibility matters.** `high` = you found primary data with methodology. `medium` = you found secondary reporting or summaries. `low` = you're working from a press mention.
- **Don't duplicate.** Check `_registry.md` before creating a summary — if the report is already there, skip it.
- **Prioritize Quebec relevance.** When a global/national report exists, focus the summary on what it says about Quebec specifically. Put national/global context in Key Data Points but lead with Quebec in the TL;DR.

### When you're done

1. Run `cat ecosystem/knowledge_base/reports/_registry.md` to show the populated registry
2. Run `wc -l ecosystem/knowledge_base/insights/_index.csv` to show insight count
3. Summarize: how many reports ingested, how many insights extracted, which topics have the most coverage, and which topics have gaps
