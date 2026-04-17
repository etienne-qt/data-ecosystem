---
id: INTERNAL-sprint1-funding-2026
title: "Sprint 1: Quebec VC Funding — Key Findings from Internal Data"
type: internal-analysis
author: Data & Analytics, Quebec Tech
date: 2026-03-24
data_sources: [PitchBook, Dealroom]
topics: [funding, ecosystem-size, exits]
geography: quebec
status: final
---

# Sprint 1: Quebec VC Funding — Key Findings from Internal Data

## TL;DR

Quebec averages only ~21 VC deals per year (2020–2025), roughly 3x fewer than Ontario, but with the highest average deal size ($5.3M) among Canada's big-four provinces — consistent with a state-capital-dominated model where institutional investors write larger checks to fewer companies. The most actionable finding is the near-absence of Early Stage VC (Series A/B equivalent): Quebec recorded 0–3 such deals per year, compared to 5–13 in Ontario, creating a capital desert between Seed and Later Stage that strands most startups before they can scale.

## Key Findings

1. **[funding]** Quebec averages ~21 VC deals/year (2020–2025) vs. Ontario 76, BC 55, Alberta 26 — the fewest among Canada's four largest provinces. Average deal size is $5.3M CAD (the highest), suggesting concentration over breadth.

2. **[funding]** Quebec had 0–3 Early Stage VC deals per year from 2020–2025 (total: 12 deals, $91.9M over six years). In 2024, there were zero. Ontario had 5–13 per year over the same period.

3. **[funding]** Only 3 Quebec deals exceeded $50M CAD in the last decade: Xposure Music ($59.7M, 2025), Airex Energy ($175.9M, 2023), DalCor Pharmaceuticals ($72.4M, 2020). Ontario and BC would each have dozens of such deals.

4. **[funding]** Later Stage VC captures 59% of all Quebec VC capital (2020–2025): $433M of $733M total, from only 23 deals. The top 3 deals account for approximately $300M — remove them and the Quebec total collapses.

5. **[funding]** Quebec missed the 2021 VC boom entirely: only $43M raised vs. Ontario's $417M and BC's $436M in the same year.

6. **[funding]** The six most active VC investors in Quebec by deal count are all state/institutional: Investissement Québec (148 deals), Desjardins Capital (86), Anges Québec (65), BDC Capital (63), Fonds FTQ (44), Fondaction (43).

7. **[funding]** Quebec-based investors account for 43–55% of all deal participations in Quebec companies (2020–2025). US investors account for 14–21% — broadly confirming the CVCA finding of Quebec's structural isolation from US capital.

8. **[funding]** US capital participation dropped from ~36% of deployed capital in 2020 to ~1% in 2025 — a steeper decline than the national pullback, suggesting Quebec was more exposed to the US VC withdrawal.

9. **[funding]** The Seed → Later Stage VC transition takes a median of 38 months (n=5) — comparable to Israel's Seed → Series A benchmark of 35 months (IVC 2025). The Seed → Early Stage VC pipeline doesn't show up in the data at all (insufficient n).

10. **[ecosystem-size]** Website domain matching between PitchBook Quebec companies and Dealroom STARTUP_MASTER yields only a 3.8% match rate (13/343), indicating a significant normalization gap or different company universes — a data infrastructure problem requiring investigation.

## Quebec-Specific Context

Quebec's VC structure is a direct product of its institutional history. The dominant investors — IQ, Fonds FTQ, Fondaction, Desjardins — are all products of Quebec's social-economy model, created to channel worker and institutional capital toward Quebec companies. This architecture provides stability (Quebec did not experience the full volatility of the 2021 boom–bust cycle) but limits growth: institutional investors are risk-averse, prefer later-stage bets, and do not replicate the "spray and pray" Seed dynamics of Silicon Valley or even Toronto.

The implication is that Quebec's capital problem is structural, not cyclical. Adding more state capital to the existing institutions would likely worsen concentration. What is missing is an independent, risk-tolerant Series A/B tier — analogous to what Yozma provided in Israel in the 1990s, or what the Ontario government tried to catalyze with its fund-of-funds model. Quebec's path to a healthier VC ecosystem likely requires attracting or creating new private VC GPs, not scaling existing state-capital LPs.

## Methodology Notes

- **Data sources:** PitchBook via DEV_RESEAUCAPITAL (Quebec-filtered), Dealroom via DEV_QUEBECTECH. All figures in $M CAD unless noted.
- **Scope:** 2020–2025 (6 full years). Quebec means companies headquartered in Quebec.
- **Stage classification:** Uses PitchBook's stage taxonomy (Angel, Seed, Early Stage VC, Later Stage VC, Accelerator, Crowdfunding). "Early Stage VC" maps approximately to Series A/B.
- **Investor count:** Based on investor-deal participation pairs; one investor appearing in multiple deals is counted multiple times.
- **Capital deployed:** The `INVESTED_M_CAD` field contains NULLs for several major investors (notably BDC). Capital figures are directional, not complete.
- **Company count:** The match rate issue (3.8% cross-source) means PitchBook and Dealroom may represent different slices of the Quebec startup universe — reconciliation is pending.

## Extracted Messages

The following findings are promoted to `messages/funding-landscape.md`:

### MSG-FUNDING-01: Quebec deal count vs peer provinces
- **Claim:** Quebec averages ~21 VC deals per year (2020–2025), compared to Ontario (76), British Columbia (55), and Alberta (26).
- **Confidence:** High
- **Evidence:** INTERNAL-sprint1-funding-2026
- **Implication:** Quebec's thin deal pipeline is the single most important structural fact in the ecosystem.
- **Last verified:** 2026-03-24

### MSG-FUNDING-02: Quebec deal size — largest among big four
- **Claim:** Quebec's average VC deal size is $5.3M CAD (2020–2025), the highest among Canada's four largest provinces.
- **Confidence:** High
- **Evidence:** INTERNAL-sprint1-funding-2026
- **Implication:** High average deal size reflects concentration, not strength — fewer companies get larger, later-stage bets.
- **Last verified:** 2026-03-24

### MSG-FUNDING-04: Early Stage VC gap — near-absence of Series A
- **Claim:** Quebec had 0–3 Early Stage VC deals per year from 2020–2025, compared to Ontario's 5–13 per year.
- **Confidence:** High
- **Evidence:** INTERNAL-sprint1-funding-2026
- **Implication:** Series A/B equivalent funding is functionally unavailable for most Quebec startups — the most actionable policy finding.
- **Last verified:** 2026-03-24

## Limitations & Open Questions

1. **Match rate problem:** Only 3.8% of PitchBook Quebec companies match Dealroom records by domain. Until resolved, cross-source analysis is unreliable. Next step: examine sample mismatches, try LinkedIn slug as secondary key, use RC COMPANY_MATCH_RESULTS as bridge.
2. **NULL capital data:** BDC and several other investors have missing `INVESTED_M_CAD` values. Total capital deployed figures are underestimates.
3. **Stage taxonomy alignment:** PitchBook's "Early Stage VC" / "Later Stage VC" labels may not perfectly align with CVCA's definitions or with how Quebec companies self-describe their rounds.
4. **US withdrawal interpretation:** The steep drop in US capital (to ~1% in 2025) could reflect data completeness issues (recent deals may not yet be logged) rather than a genuine withdrawal. Needs validation against 2024–2025 CVCA data.
5. **Open question:** Is there evidence of Quebec companies bypassing domestic VC entirely and going direct to US or international rounds? PitchBook would capture this, but geographic filtering may exclude it.
