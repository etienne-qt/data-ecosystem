---
id: INTERNAL-genai-impact-req-2026
title: "Impact of Generative AI on Company Creation in Quebec — REQ Analysis"
type: internal-analysis
author: Data & Analytics, Quebec Tech
date: 2026-03-17
data_sources: [REQ]
topics: [macro-trends, ecosystem-size]
geography: quebec
status: final
---

# Impact of Generative AI on Company Creation in Quebec — REQ Analysis

## TL;DR

Tech product company incorporations in Quebec more than doubled from a 2017–2019 baseline of 34/month to 76/month in early 2026, with the acceleration arriving in 2024–2025 rather than immediately following ChatGPT's launch — suggesting an ~18-month lag between GenAI tool availability and measurable founder behavior change. AI/ML-specific companies quadrupled (10–28/quarter in 2019 to 50–71/quarter in 2025). However, this remains a correlation, not a proven causal link, and the absolute numbers are modest (~76 tech product companies/month out of ~4,700 total monthly incorporations) — the vast majority of new Quebec corporations are in non-tech sectors.

## Key Findings

1. **[macro-trends]** Tech product company creation rate: 34/month (2017–2019 baseline) → 42/month (COVID) → 39/month (Early GenAI, H2 2022–2023, essentially flat) → 44/month (2024) → 76/month (2025–early 2026). A 2.2x increase from baseline.

2. **[macro-trends]** Difference-in-Differences analysis shows +27.7 percentage points of excess growth in tech product creation relative to the non-tech economy — the strongest signal in the dataset.

3. **[macro-trends]** AI/ML company creation (companies explicitly mentioning AI/ML in REQ description): 10–28/quarter (2019) → 9–19/quarter (2020–2021) → 8–14/quarter (2022) → 14–24/quarter (2023) → 27–29/quarter (2024) → 50–71/quarter (2025) → 54/quarter (2026 Q1). Roughly 4x from pre-GenAI levels.

4. **[macro-trends]** SaaS-specific companies grew from ~3/quarter before 2023 to 19–26/quarter in late 2025–early 2026.

5. **[macro-trends]** The GenAI effect was delayed: creation rates were flat in H2 2022–2023. Inflection came in 2024, with a sharp acceleration in 2025. Estimated ~18-month lag between tool availability and incorporation behavior.

6. **[macro-trends]** Software development firms (76–89/month throughout) and tech-adjacent consultancies (90–106/month throughout) show no meaningful formation growth — DiD shows both underperforming non-tech by 6–7 percentage points.

7. **[macro-trends]** Among tech product companies, 0-employee share at registration rose from 88% (baseline) to 97% (post-GenAI), consistent with GenAI enabling solo founders or very small teams.

8. **[ecosystem-size]** Total corporation creation in Quebec rose from ~3,600/month (2017–2019) to ~4,700/month (2025). The fastest-growing sectors are non-tech: staffing (+78%), pharmacies (+84%), personal care (+79%), sports clubs (+91%), restaurants (+49%).

9. **[ecosystem-size]** Tech product companies represent 0.94–1.62% of all new CIE incorporations (baseline to 2025). This small share has grown meaningfully but tech is still a niche of the overall Quebec corporate formation landscape.

10. **[macro-trends]** 44% of IT-sector (CAE 7721) companies have empty or "-" descriptions — likely understating the tech product category, as these are classified as "Software Dev" by fallback.

## Quebec-Specific Context

The GenAI formation wave is real in Quebec, but its scale needs appropriate calibration. At 76 tech product companies per month, Quebec is producing roughly 900 new tech product incorporations per year — a number that, if even 10–15% reach meaningful activity, represents a significant pipeline addition to the ecosystem. For QT's registry methodology, this means the annual cohort of new companies entering the system is growing and should be systematically tracked.

The composition shift is strategically important: AI-native and SaaS companies are growing as a share of new incorporations while traditional IT consulting and software development shops are flat. This implies that Quebec's next wave of startups will be AI-first by default — a cohort very different from the enterprise SaaS and e-commerce companies that defined the 2015–2020 era.

The 18-month lag finding is directly relevant to QT's annual report timing. If the current 2025 acceleration is the leading edge of a formation wave catalyzed by tools available since late 2022, the full effect is likely not yet visible — the strongest cohort of GenAI-native Quebec startups may be incorporated but pre-traction in 2026, making 2026–2027 the likely window for the first funding and exit signals from this cohort.

## Methodology Notes

- **Source:** REQ open data (Entreprise.csv + DomaineValeur.csv), extracted 2026-02-02, data through ~March 14, 2026.
- **Legal form:** CIE only (464,211 corporations). Excludes sole proprietorships, partnerships, non-profits.
- **Date range:** January 2017 – February 2026 (110 months), providing 5+ years of pre-GenAI baseline.
- **Classification taxonomy:** Four categories — Tech Product, Software Development, Tech Adjacent, Non-Tech. Priority: Tech Product > Software Dev > Tech Adjacent > Non-Tech.
- **Classification method:** Hybrid CAE + keyword (v2). Keyword match on `DESC_ACT_ECON_ASSUJ` takes priority when description is available; CAE fallback when description is empty.
- **GenAI inflection point:** July 2022 (GitHub Copilot GA); secondary marker November 2022 (ChatGPT launch).
- **Analytical methods:** Period comparison, 12-month trailing moving average, indexed quarterly trend (Q1 2019 = 100), Difference-in-Differences.
- **Scripts:** `analytics/scripts/req_genai_impact_v2.py` (primary); `req_genai_impact_analysis.py` (v1, CAE-only)
- **License note:** REQ data is CC BY-NC-SA 4.0 — non-commercial attribution required if published.

## Extracted Messages

The following findings are promoted to `messages/macro-trends.md` and `messages/ecosystem-size.md`:

### MSG-MACRO-01: Tech product creation has doubled post-GenAI
- **Claim:** Tech product company incorporations in Quebec rose from 34/month (2017–2019) to 76/month in 2025–early 2026 — a 2.2x increase with +27.7 pp excess growth vs. non-tech (DiD).
- **Confidence:** High
- **Evidence:** INTERNAL-genai-impact-req-2026
- **Implication:** The GenAI era has materially changed the rate at which Quebec founders incorporate product companies.
- **Last verified:** 2026-03-17

### MSG-MACRO-02: GenAI effect was delayed 18 months
- **Claim:** Tech product creation was flat in Early GenAI period (H2 2022–2023) before accelerating sharply in 2024–2025, suggesting an ~18-month lag.
- **Confidence:** Medium
- **Evidence:** INTERNAL-genai-impact-req-2026
- **Implication:** The current acceleration is likely the leading edge of a sustained wave, not a peak.
- **Last verified:** 2026-03-17

### MSG-MACRO-03: AI/ML companies have quadrupled since pre-GenAI
- **Claim:** Quebec companies explicitly mentioning AI/ML in REQ descriptions grew from 10–28/quarter (2019) to 50–71/quarter (2025), approximately 4x.
- **Confidence:** Medium
- **Evidence:** INTERNAL-genai-impact-req-2026
- **Implication:** AI/ML is the dominant growth vector in new Quebec tech incorporation.
- **Last verified:** 2026-03-17

### MSG-MACRO-05: Micro-companies dominate — 97% zero-employee post-GenAI
- **Claim:** Among post-GenAI tech product companies, 97% report zero employees at registration, up from 88% in the 2017–2019 baseline.
- **Confidence:** Medium
- **Evidence:** INTERNAL-genai-impact-req-2026
- **Implication:** The new generation of Quebec tech startups skews heavily toward micro-ventures; support programs should adapt accordingly.
- **Last verified:** 2026-03-17

## Limitations & Open Questions

1. **Correlation, not causation.** Many confounding factors (post-COVID normalization, interest rate environment, immigration, federal startup incentives) changed simultaneously with GenAI tool availability. The DiD approach using non-tech as a control partially addresses this but does not resolve it.
2. **Classification uncertainty.** 44% of CAE 7721 companies have empty descriptions. Hybrid classification v2 improves on v1 but still misses companies with vague descriptions or non-standard self-classification.
3. **Incorporation ≠ startup.** We cannot distinguish serious ventures from shell companies, holding companies, or weekend projects. No revenue, funding, or survival data is available from REQ.
4. **Fashionable terminology.** Companies incorporating in 2025 are more likely to mention "AI" regardless of centrality — some AI/ML count inflation is expected from term popularity.
5. **Federal CBCA exclusion.** Tech companies are more likely to incorporate federally. The REQ-only lens may systematically undercount the most sophisticated startups.
6. **Open question:** What fraction of the 2024–2025 tech product cohort will seek VC within 12–24 months? Linking this REQ cohort to Dealroom or PitchBook in 2026–2027 would validate whether the formation wave translates to fundable companies.
7. **Open question:** Is the micro-company dominance (97% zero-employee) driven by genuine solo founders, or by professionals incorporating for contractual reasons (tax optimization, liability)? Survival rate tracking over 3 years would help distinguish these.
