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

---

## Processing Internal Analyses

When Quebec Tech runs an internal analysis — SQL query results, REQ data extracts, Snowflake pipeline outputs, or any internally-generated dataset — the findings should flow into the knowledge base through a two-step process: first an `internal/` card, then promotion to the `messages/` layer.

### Step 1 — Create an `internal/` card

Create a file at `ecosystem/knowledge_base/internal/{id}.md` using this template:

```markdown
---
id: INTERNAL-{id}
title: "..."
type: internal-analysis
author: Data & Analytics, Quebec Tech
date: YYYY-MM-DD
data_sources: [REQ, Dealroom, PitchBook, Snowflake, ...]
topics: [funding, hard-tech, macro-trends, ecosystem-size, ...]
geography: quebec
status: draft | final
---

# {Title}

## TL;DR
2-3 sentences: the single most important takeaway.

## Key Findings
Numbered list of concrete findings with numbers. Each tagged [topic].

## Quebec-Specific Context
What this means specifically for Quebec.

## Methodology Notes
How data was collected, scope, caveats, script locations.

## Extracted Messages
Messages to promote to `messages/{theme}.md`. Format as MSG entries (see below).

## Limitations & Open Questions
What this analysis can't answer; what follow-up would strengthen the findings.
```

**Rules for internal cards:**
- Keep the raw findings in `Key Findings` without editorializing — tag each with `[topic]` in brackets.
- Methodology Notes must reference the actual script path and data source extract date.
- Status is `draft` until someone from the data team has reviewed the methodology; then `final`.
- Do not include raw individual company names or PII — aggregate-level findings only.

### Step 2 — Promote key findings to `messages/`

After writing the `internal/` card, identify the 2–5 strongest, most citable findings and promote them to the relevant `messages/{theme}.md` file using the MSG entry format:

```markdown
### MSG-{THEME}-{nn}: Short title
- **Claim:** One clear sentence with the number/finding
- **Confidence:** High | Medium | Low
- **Evidence:** INTERNAL-{id}
- **Implication:** One sentence on why this matters for QT's work
- **Last verified:** YYYY-MM-DD
```

**Promotion rules:**
- Only promote findings that are self-contained: the claim must be understandable without reading the full analysis.
- Every promoted claim must include the specific number or finding — no vague claims ("X has grown significantly").
- Set Confidence based on: High = primary data, documented methodology, clean signal; Medium = single internal analysis or known data quality caveats; Low = proxy data (CAE code fallback, small samples, preliminary).
- The `Evidence` field must point back to the `INTERNAL-{id}` card, not to the raw source directly.
- Assign the next sequential number (`nn`) within the theme — check existing entries in the theme file before assigning.
- Update the `msg_count` in the theme file's frontmatter.

### ID convention

Internal analysis IDs follow this pattern: `INTERNAL-{slug}-{year}`

- **{slug}** — a short, descriptive kebab-case identifier for the analysis (e.g., `sprint1-funding`, `hardware-photonics-req`, `genai-impact-req`, `registry-coverage-audit`). Should be unique and searchable.
- **{year}** — four-digit year of the analysis date.

Examples:
- `INTERNAL-sprint1-funding-2026` → `internal/sprint1-funding-2026.md`
- `INTERNAL-hardware-photonics-req-2026` → `internal/hardware-photonics-req-2026.md`
- `INTERNAL-registry-coverage-audit-2026` → `internal/registry-coverage-audit-2026.md`

The `id` field in the frontmatter must match the filename (without `.md`), prefixed with `INTERNAL-`.

### Updating the KB index

After creating a new `internal/` card, add it to the `Internal Analyses` section of `ecosystem/knowledge_base/index.md` and update the `updated:` date in the frontmatter.

---

## Hardware & Hard Tech — Additional Scope

The research pipeline should actively seek out reports covering Quebec and Canadian hard-tech sectors. These are currently underrepresented in the knowledge base relative to their strategic importance. Add these to the **Tier 2** and **Tier 3** research queues when ingesting external reports:

### Tier 2 additions — Hard Tech Context

- **Écotech Québec annual reports** — Quebec's cleantech cluster organization; covers hardware-heavy sectors including energy tech, water tech, and materials. Annual publication, available on their website.

- **MEDTEQ+ annual reports** — Consortium de recherche et d'innovation en technologies médicales du Québec; covers medical device and health hardware companies. Focus on Quebec.

- **adMare BioInnovations reports** — Canadian life sciences investment platform with a hardware-adjacent mandate (biotools, diagnostics equipment). Tracks spinoff and commercialization activity.

- **NSERC / FRQNT spinoff and commercialization reports** — Federal and provincial research council reports on commercialization outcomes from academic research grants. Include data on spinoff companies that may not appear in Dealroom or REQ at incorporation stage.

- **CB Insights hard tech trend reports** — Global context on deep tech investment flows; useful for benchmarking Quebec's sector against international hard tech trends. Note: secondary source, credibility = medium unless methodology appendix available.

- **Dealroom hard tech and deep tech ecosystem reports** — If publicly available editions exist, ingest for global/European benchmarks. The underlying data is available in DEV_QUEBECTECH but aggregate reports provide analyst interpretation.

### Tier 3 additions — Sector-Specific Hard Tech

- **INO (Institut national d'optique) annual reports** — If publicly available, INO's annual report would provide the most authoritative signal on Quebec's photonics commercialization pipeline. INO is the anchor institution of the Quebec City photonics cluster.

- **CHIPS Act impact reports (US and Canada's response)** — The US CHIPS and Science Act (August 2022) and Canada's semiconductor strategy responses. Relevant for understanding capital flows into hardware and whether any of that policy momentum is visible in Quebec incorporation data.

- **Scale AI reports (hardware/AI intersection)** — Scale AI is a Canadian AI supercluster with a mandate that intersects hardware and AI. Reports may cover embedded AI, edge computing, and robotics sectors that are adjacent to QT's hard-tech tracking mandate.

**Research note:** For hard-tech reports, pay particular attention to sections that include **spinoff counts**, **commercialization rates**, **laboratory-to-market timelines**, and **capital requirements per company** — these are the metrics most useful for calibrating QT's expectations about hard-tech company formation and funding relative to software startups.
