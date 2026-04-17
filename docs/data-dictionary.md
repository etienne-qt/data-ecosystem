# Data Dictionary

Shared definitions for fields, metrics, and terms used across QT, RC, and CIQ analyses.

## Company-level fields

| Field | Definition | Source(s) | Notes |
|-------|-----------|-----------|-------|
| `company_name` | Legal or operating name of the company | Dealroom, REQ, manual | Use operating name for reports, legal name for regulatory references |
| `neq` | Numéro d'entreprise du Québec | Registraire des entreprises | 10-digit identifier. Public record. |
| `dealroom_url` | Company profile URL on Dealroom | Dealroom | **Licensed field — do not commit to repo** |
| `sector_primary` | Primary sector classification | Taxonomy (`taxonomy/sectors.yaml`) | Use taxonomy codes only |
| `sector_secondary` | Secondary sector(s) if applicable | Taxonomy | Comma-separated codes |
| `stage` | Current funding stage | Taxonomy (`taxonomy/stages.yaml`) | Use taxonomy codes only |
| `founded_year` | Year the company was founded | Dealroom, REQ, public sources | Use earliest credible source |
| `city` | City of headquarters | Dealroom, REQ | Use taxonomy geography codes for aggregation |
| `total_funding_cad` | Total equity funding raised (CAD) | Dealroom, PitchBook | **Aggregate only in committed insights** |
| `employee_count` | Current headcount or range | Dealroom, LinkedIn | Point-in-time; note the date |
| `b2b_b2c` | Business model classification | Manual | Values: `B2B`, `B2C`, `B2B;B2C` |
| `status` | Company operating status | Dealroom, manual | Values: `active`, `acquired`, `closed`, `ipo` |

## Metric definitions

| Metric | Definition | Calculation | Unit |
|--------|-----------|-------------|------|
| `total_vc_invested` | Total venture capital invested in a period | Sum of all VC deal amounts in the period | CAD |
| `deal_count` | Number of deals in a period | Count of unique deals | count |
| `median_round_size` | Median deal size in a period | Median of deal amounts | CAD |
| `yoy_change_pct` | Year-over-year change | (current - previous) / previous | ratio (0.35 = 35% increase) |
| `startup_count` | Number of active startups | Count of companies meeting `startup-criteria.yaml` | count |
| `scaleup_count` | Number of scaleups | Companies with >$10M ARR or >50 employees, founded <15 years ago | count |

## Terms

| Term | Definition |
|------|-----------|
| **Startup** | A company meeting the criteria in `taxonomy/startup-criteria.yaml`. Generally: technology-driven, <15 years old, growth-oriented, independently operated. |
| **Scaleup** | A startup that has surpassed $10M ARR or 50 employees. |
| **Ecosystem** | The network of startups, investors, accelerators, universities, and support organizations in a defined geography. |
| **Deal** | A single funding transaction. A company may have multiple deals. |
| **Round** | Synonymous with deal in most contexts. When multiple closings occur, they are counted as one round. |
| **Dry powder** | Committed but undeployed capital in VC/PE funds. |

*(Expand this dictionary as new fields and metrics are introduced.)*
