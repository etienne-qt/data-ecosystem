---
id: INTERNAL-hardware-photonics-req-2026
title: "Hardware & Photonics Company Creation in Quebec — REQ Analysis"
type: internal-analysis
author: Data & Analytics, Quebec Tech
date: 2026-03-26
data_sources: [REQ]
topics: [hard-tech, ecosystem-size, macro-trends]
geography: quebec
status: final
---

# Hardware & Photonics Company Creation in Quebec — REQ Analysis

## TL;DR

Quebec's hardware and photonics sector produces approximately 12–18 new company incorporations per quarter — a very small signal against the 464,211 total CIE in the REQ. A tentative 50% uptick is visible in 2025–early 2026 (18.2/quarter vs. 12.1/quarter pre-COVID baseline), but absolute numbers are small enough that this could be noise. The most important finding is methodological: 73% of classifications rely on CAE sector codes (not self-declared keywords), limiting confidence in any trend claims. Pure photonics company creation has been flat throughout — the recent uptick is driven by adjacent hardware (semiconductors, quantum, sensors) and optics/imaging.

## Key Findings

1. **[hard-tech]** 547 hardware/photonics companies incorporated in Quebec between January 2017 and March 2026, out of 464,211 total CIE — representing 0.12% of all corporations.

2. **[hard-tech]** Sub-category breakdown: 81 photonics core, 183 optics & imaging, 283 adjacent hardware.

3. **[hard-tech]** Formation rates by period: Pre-COVID (2017–2019): 12.1/quarter; COVID era (2020–2021): 15.1/quarter; Post-COVID/CHIPS (2022–2023): 11.3/quarter (dip); Recent (2024): 12.2/quarter; Latest (2025–early 2026): 18.2/quarter.

4. **[hard-tech]** Photonics core formation is flat across all periods: ~2.0–2.2/quarter from 2017–2026. All recent growth is in optics & imaging (7.0/quarter in 2025) and adjacent hardware (9.0/quarter in 2025).

5. **[macro-trends]** Hardware/photonics formation dipped in 2022–2023 (11.3/quarter) — the inverse of the AI/SaaS formation surge in the same period, consistent with higher capital barriers and supply chain disruption in hardware.

6. **[ecosystem-size]** The 3,757 false positives excluded before classification were predominantly beauty clinics (~2,500+) and laser cutting/engraving services — unfiltered REQ data would overstate the photonics sector by 7–8x.

7. **[hard-tech]** Only 149 of 547 classified companies (27%) provided self-described keyword matches. The remaining 398 (73%) were classified via CAE code fallback alone — a significant data quality limitation.

8. **[hard-tech]** Top keyword signals in self-described companies: "fibre(s) optique(s)" (50), imaging + thermal/infrared (20), quantum computing (12), photonics/photonique (14, the cleanest signal), precision machining with laser (11).

9. **[hard-tech]** The 2025 uptick is preliminary. The latest period includes only a partial window; the numbers are small enough that 3–4 additional incorporations per quarter would explain the entire apparent trend.

## Quebec-Specific Context

Quebec has a legitimate photonics heritage: INO (Institut national d'optique) in Quebec City, EXFO, II-VI (now Coherent), and a cluster of academic spinoffs from Laval, Concordia, and McGill. However, this analysis finds no evidence that the institutional base is generating a wave of new photonics startups — core photonics incorporation has been flat at ~2/quarter for nearly a decade.

This is striking in the context of global hard-tech policy momentum (US CHIPS Act 2022, Canada's semiconductor response). If Quebec's photonics sector is growing, it may be happening through channels not visible in REQ: federal CBCA incorporations, stealth pre-incorporation activity, or growth within existing companies rather than new formation. The most valuable next step would be cross-referencing this REQ cohort against INO, MEDTEQ+, and Écotech Québec membership lists to understand how much is missing.

The contrast with the GenAI/SaaS wave is instructive: while software company creation doubled in 2024–2025, hardware held flat or dipped in the same period. This confirms that the current tech formation acceleration is software-first — hard-tech requires dedicated policy instruments that cannot simply ride the GenAI tailwind.

## Methodology Notes

- **Source:** Registraire des entreprises du Québec (REQ) open data extract (Entreprise.csv + DomaineValeur.csv), same 464,211 CIE corpus as the GenAI analysis.
- **Legal form:** CIE (corporations) only. Excludes sole proprietorships, federal CBCA corporations, university spin-offs before incorporation.
- **Classification method:** Hybrid — keyword matching on `DESC_ACT_ECON_ASSUJ` (free-text business description) takes priority; CAE sector code fallback when description is empty or "-".
- **Keyword patterns:** 60+ bilingual (FR/EN) regex patterns covering photonics, lasers, optics, semiconductors, quantum, MEMS, LiDAR, sensors, etc.
- **Exclusion filters:** 3,757 companies removed as false positives (beauty clinics, laser cutting services, fiber optic installation, quantum wellness).
- **Temporal markers:** COVID (March 2020), CHIPS Act (August 2022) — used as period boundaries, not causal claims.
- **Script:** `analytics/scripts/req_hardware_photonics.py`

## Extracted Messages

The following findings are promoted to `messages/hard-tech.md` and `messages/ecosystem-size.md`:

### MSG-HARDTECH-01: Hard-tech incorporation rate — 2025 uptick
- **Claim:** Hardware/photonics company incorporations in Quebec have risen to approximately 18.2/quarter in 2025–early 2026, up ~50% from the pre-COVID baseline of 12.1/quarter (2017–2019), though the absolute numbers remain small.
- **Confidence:** Low
- **Evidence:** INTERNAL-hardware-photonics-req-2026
- **Implication:** Warrants monitoring over 2–3 more quarters before inclusion in public reports.
- **Last verified:** 2026-03-26

### MSG-HARDTECH-02: Photonics core is flat — growth is in adjacent hardware
- **Claim:** Pure photonics company creation has held flat at ~2.0–2.2/quarter throughout 2017–2026; all recent growth is in adjacent hardware and optics/imaging.
- **Confidence:** Medium
- **Evidence:** INTERNAL-hardware-photonics-req-2026
- **Implication:** Quebec's photonics institutional base is not generating a new wave of photonics startups visible in REQ data.
- **Last verified:** 2026-03-26

### MSG-HARDTECH-04: REQ hard-tech signal is noisy — 73% CAE fallback
- **Claim:** 73% of the 547 hardware/photonics companies identified in the REQ rely on CAE sector code classification, not self-described keywords — limiting analytical confidence.
- **Confidence:** High
- **Evidence:** INTERNAL-hardware-photonics-req-2026
- **Implication:** Any public claim about Quebec's hard-tech sector size should note the REQ data quality limitation; sector association data would be more reliable.
- **Last verified:** 2026-03-26

## Limitations & Open Questions

1. **Small sample sizes:** Quarterly counts in single digits for sub-categories. Statistical significance tests are not appropriate here.
2. **CAE bluntness:** Manufacturing (3699), optical instruments (3827), semiconductors (3674) are broad codes that include many non-startup entities.
3. **Federal corporations excluded:** CBCA-registered companies operating in Quebec that haven't registered provincially are not captured. Hard-tech companies are more likely to incorporate federally (IP protection, investor expectations).
4. **No viability signal:** REQ captures incorporation only — no revenue, funding, or survival data. We cannot distinguish an active photonics startup from a dormant shell company.
5. **Self-description gap:** Companies with institutional partners (INO, Mila, MEDTEQ) may use their own nomenclature rather than standard keyword terms — the REQ may be systematically undercounting the most sophisticated hard-tech startups.
6. **Open question:** How does Quebec's 547 hard-tech company count compare to Ontario or BC? REQ equivalent data may be available for other provinces via their respective registries.
7. **Open question:** Do the 149 keyword-matched companies (the higher-quality subset) show different survival rates or funding outcomes than the 398 CAE-only matched? This would require cross-referencing with Dealroom or PitchBook.
