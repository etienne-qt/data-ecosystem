---
theme: ecosystem-size
updated: 2026-04-15
msg_count: 5
---

# Messages — Ecosystem Size

Validated claims about the total size of Quebec's tech startup universe: registry counts, source breakdown, and what the numbers mean.

See `_README.md` for the entry format and confidence guide.

---

## Registry Universe

### MSG-SIZE-01: Quebec startup registry — defensible universe
- **Claim:** Quebec Tech's unified registry (Dealroom outer-joined with Réseau Capital) contains 7,607 raw rows; after applying the startup filter (pre-1990 cutoff, non-tech name veto, blacklist), 6,507 survive — of which roughly 5,100–5,500 are clearly tech startups by conservative estimate.
- **Confidence:** High
- **Evidence:** INTERNAL-sprint1-funding-2026 (registry context); ecosystem pipeline docs
- **Implication:** Any public claim about "the size of Quebec's tech ecosystem" should use the range 5,100–5,500, not a single round number, to remain defensible.
- **Last verified:** 2026-04-15

### MSG-SIZE-02: REQ corporate registry — incorporations scale
- **Claim:** Quebec's Registraire des entreprises du Québec (REQ) contains 464,211 corporations (CIE) as of February 2026; of these, approximately 0.94–1.62% are classifiable as tech product companies depending on the era.
- **Confidence:** High
- **Evidence:** INTERNAL-genai-impact-req-2026
- **Implication:** Tech startups are a small but growing share of all Quebec corporations — their ecosystem significance exceeds their raw count.
- **Last verified:** 2026-04-15

---

## Source Breakdown

### MSG-SIZE-03: Dealroom vs Réseau Capital coverage split
- **Claim:** In QT's unified registry, entity provenance splits across three types: MATCHED (in both Dealroom and Réseau Capital), QT_ONLY (Dealroom only), and RC_ONLY (RC only) — with RC_ONLY rows representing a substantial "dark matter" layer of startups not captured in Dealroom's global database.
- **Confidence:** High
- **Evidence:** INTERNAL-sprint1-funding-2026
- **Implication:** Any analysis using only Dealroom data systematically undercounts the Quebec ecosystem; the RC_ONLY layer must be included in any public-facing ecosystem count.
- **Last verified:** 2026-04-15

---

## Company Creation Rates

### MSG-SIZE-04: Tech product company creation — 2025 rate
- **Claim:** Quebec is incorporating approximately 76 tech product companies per month as of early 2026, up from a baseline of 34/month in 2017–2019 — a 2.2x increase.
- **Confidence:** Medium
- **Evidence:** INTERNAL-genai-impact-req-2026
- **Implication:** The raw pipeline of new tech ventures is growing fast; QT's registry methodology must be updated regularly to capture these cohorts before they seek funding or become newsworthy.
- **Last verified:** 2026-04-15

### MSG-SIZE-05: Hardware/photonics company count — small sector
- **Claim:** Approximately 547 hardware/photonics companies were incorporated in Quebec between 2017 and early 2026, representing 0.12% of all CIE registrations — a sector roughly 6x smaller by volume than tech product/software.
- **Confidence:** Low
- **Evidence:** INTERNAL-hardware-photonics-req-2026
- **Implication:** Hard-tech is a niche within Quebec's startup universe; absolute counts are too small for statistical inference — ecosystem narratives should foreground relative trends and sector density rather than raw counts.
- **Last verified:** 2026-04-15
