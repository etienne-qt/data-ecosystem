---
title: External Report Registry
type: registry
created: 2026-04-08
updated: 2026-04-15
---

# External Report Registry

Master index of all external reports ingested into the intelligence pipeline.

## How to Use
- Each row = one report edition (GSER 2024 and GSER 2025 are separate rows)
- `series_id` links editions of the same recurring report (see [_series.md](_series.md))
- `summary_path` points to the detailed summary in `summaries/`
- Tags use the controlled vocabulary in [_tags.md](_tags.md)

## Registry

| id | title | publisher | series_id | year | language | type | geography | topics | credibility | summary_path | date_ingested |
|----|-------|-----------|-----------|------|----------|------|-----------|--------|-------------|--------------|---------------|
| cvca-2025 | CVCA Year-End 2025 Canadian VC & PE Market Overview | CVCA | cvca-annual | 2025 | EN | industry-report | canada | funding,exits,macro-trends,ai-sector,cleantech-sector,healthtech-sector | high | summaries/cvca-2025.md | 2026-04-08 |
| gser-2025 | Startup Genome Global Startup Ecosystem Report 2025 | Startup Genome | gser | 2025 | EN | ecosystem-ranking | international | entrepreneurship,funding,exits,ai-sector,cleantech-sector,healthtech-sector,macro-trends,talent | high | summaries/gser-2025.md | 2026-04-08 |
| bdc-vc-2025 | BDC Canada's Venture Capital Landscape 2025 | BDC / BDC Capital | bdc-vc-landscape | 2025 | FR/EN | industry-report | canada | funding,entrepreneurship,exits,ai-sector,macro-trends,commercialization | high | summaries/bdc-vc-2025.md | 2026-04-08 |
| ieq-2024 | Indice entrepreneurial québécois 2024 | Réseau Mentorat & La sphère – HEC Montréal | ieq | 2024 | FR | survey | quebec | entrepreneurship,macro-trends | high | summaries/ieq-2024.md | 2026-04-08 |
| isq-innovation-2022 | ISQ Enquête sur l'innovation et les stratégies d'entreprise 2022 | Institut de la statistique du Québec | isq-innovation | 2024 | FR | government-report | quebec | macro-trends,commercialization,ip-research | high | summaries/isq-innovation-2022.md | 2026-04-08 |
| ised-ksbs-2025 | ISED Key Small Business Statistics 2025 | Innovation, Science and Economic Development Canada | ised-ksbs | 2025 | EN/FR | government-report | canada | entrepreneurship,funding,macro-trends | high | summaries/ised-ksbs-2025.md | 2026-04-08 |
| reseau-capital-2024 | Réseau Capital Overview of Quebec's VC and PE Market 2024 | Réseau Capital | reseau-capital-annual | 2024 | FR/EN | industry-report | quebec | funding,exits,entrepreneurship,ai-sector,healthtech-sector,cleantech-sector,macro-trends | high | summaries/reseau-capital-2024.md | 2026-04-08 |
| ciq-2024 | Conseil de l'innovation du Québec — Vers un Québec innovant | Conseil de l'innovation du Québec | ciq-innovation | 2024 | FR | policy-brief | quebec | policy,funding,commercialization | high | summaries/ciq-2024.md | 2026-04-08 |
| oecd-sti-2025 | OECD Science, Technology and Innovation Outlook 2025 | OECD | oecd-sti-outlook | 2025 | EN/FR | government-report | international | policy,funding,ai-sector,talent,commercialization,macro-trends,ip-research | high | summaries/oecd-sti-2025.md | 2026-04-08 |
| pitchbook-nvca-q4-2025 | PitchBook-NVCA Venture Monitor Q4 2025 | PitchBook / NVCA | pitchbook-nvca-monitor | 2025 | EN | industry-report | north-america | funding,entrepreneurship,exits,ai-sector,macro-trends | high | summaries/pitchbook-nvca-q4-2025.md | 2026-04-08 |
| dealroom-quebec-2024 | Dealroom — The Quebec Startup Ecosystem in Numbers 2024 | Dealroom.co / Quebec Tech | dealroom-quebec | 2024 | EN | ecosystem-ranking | quebec | entrepreneurship,funding,ai-sector,cleantech-sector,macro-trends,talent,exits | high | summaries/dealroom-quebec-2024.md | 2026-04-08 |
| naco-2025 | NACO 2025 Annual Report on Angel Investing in Canada | NACO | naco-annual | 2025 | EN | industry-report | canada | funding,entrepreneurship,ai-sector,cleantech-sector,healthtech-sector,policy | high | summaries/naco-2025.md | 2026-04-08 |
| conferenceboard-innovation-2024 | Conference Board of Canada — 2024 Innovation Report Card | Conference Board of Canada | conferenceboard-innovation | 2024 | EN/FR | ecosystem-ranking | international | commercialization,ip-research,entrepreneurship,funding,policy,macro-trends | high | summaries/conferenceboard-innovation-2024.md | 2026-04-08 |
| statcan-sfgs-2023 | StatCan Survey on Financing and Growth of SMEs 2023 | Statistics Canada | statcan-sfgs | 2023 | EN/FR | survey | canada | funding,entrepreneurship,commercialization,ip-research,macro-trends | high | summaries/statcan-sfgs-2023.md | 2026-04-08 |
| mila-impact-2025 | Mila Impact Report 2024-2025 | Mila – Quebec Artificial Intelligence Institute | mila-impact | 2025 | FR/EN | industry-report | quebec | ai-sector,talent,entrepreneurship,incubation,funding,commercialization,ip-research | high | summaries/mila-impact-2025.md | 2026-04-08 |
| ecotech-cleantech-2025 | Écotech Québec — Cartographie du financement des technologies propres | Écotech Québec | ecotech-cleantech | 2025 | FR | industry-report | quebec | cleantech-sector,funding,entrepreneurship,commercialization,policy | high | summaries/ecotech-cleantech-2025.md | 2026-04-08 |
| montreal-invivo-2024 | Montréal InVivo Rapport annuel 2024 | Montréal InVivo / adMare BioInnovations | montreal-invivo-annual | 2024 | FR | industry-report | quebec | healthtech-sector,talent,entrepreneurship,commercialization,funding,incubation | high | summaries/montreal-invivo-2024.md | 2026-04-08 |
| montreal-international-2025 | Montréal International — Greater Montréal, Launchpad for Emerging Ventures 2025 | Montréal International | montreal-international-tech | 2025 | EN/FR | industry-report | quebec | entrepreneurship,talent,funding,incubation,ai-sector,cleantech-sector,healthtech-sector,macro-trends | high | summaries/montreal-international-2025.md | 2026-04-08 |
| meie-portrait-entrepreneurs-2025 | Les entrepreneurs du Québec en chiffres: Portrait sociodémographique 2025 | MEIE | meie-portrait-entrepreneurs | 2025 | FR | government-report | quebec | entrepreneurship,macro-trends,talent | high | summaries/meie-portrait-entrepreneurs-2025.md | 2026-04-15 |
| mtb-ai-policy-2025 | The Calm Before the AI Storm: Global Innovation Ecosystems | Mind the Bridge & ICC | mtb-policy | 2025 | EN | policy-brief | international | policy,entrepreneurship,funding,commercialization,macro-trends | high | summaries/mtb-ai-policy-2025.md | 2026-04-15 |
| deloitte-bdc-cvc-canada | The State of Corporate Venture Capital (CVC) in Canada | Deloitte / BDC Capital | deloitte-bdc-cvc | 2024 | EN | industry-report | canada | funding,commercialization,macro-trends | high | summaries/deloitte-bdc-cvc-canada.md | 2026-04-15 |
| deloitte-innovation-scale-canada | Innovation at Scale: Establishing Canada as a Global Leader | Deloitte Canada | deloitte-catalyst-canada-2050 | 2022 | EN | policy-brief | canada | policy,commercialization,ip-research,funding,talent,macro-trends | high | summaries/deloitte-innovation-scale-canada.md | 2026-04-15 |
| stanford-unicorn-2024 | What It Takes to Build a Unicorn: 2024 Update | Stanford University | stanford-unicorn | 2024 | EN | academic-paper | international | funding,exits,entrepreneurship,macro-trends | high | summaries/stanford-unicorn-2024.md | 2026-04-15 |
| lapresse-sweden-innovation-2025 | Suède, État-providence: La création destructrice | La Presse | lapresse-analysis | 2025 | FR | news-synthesis | international | policy,entrepreneurship,macro-trends,commercialization | medium | summaries/lapresse-sweden-innovation-2025.md | 2026-04-15 |
| gser-2017 | Global Startup Ecosystem Report 2017 | Startup Genome | gser | 2017 | EN | ecosystem-ranking | international | entrepreneurship,funding,exits,macro-trends,talent,policy | high | summaries/gser-2017.md | 2026-04-15 |
| gser-2018 | Global Startup Ecosystem Report 2018 | Startup Genome | gser | 2018 | EN | ecosystem-ranking | international | entrepreneurship,funding,macro-trends,talent,incubation,policy | high | summaries/gser-2018.md | 2026-04-15 |
| gser-2019 | Global Startup Ecosystem Report 2019 | Startup Genome | gser | 2019 | EN | ecosystem-ranking | international | entrepreneurship,funding,exits,macro-trends,talent,policy,commercialization | high | summaries/gser-2019.md | 2026-04-15 |
| gser-2020 | Global Startup Ecosystem Report 2020 | Startup Genome | gser | 2020 | EN | ecosystem-ranking | international | entrepreneurship,funding,exits,macro-trends,talent,policy | high | summaries/gser-2020.md | 2026-04-15 |
| gser-2021 | Global Startup Ecosystem Report 2021 | Startup Genome | gser | 2021 | EN | ecosystem-ranking | international | entrepreneurship,funding,exits,macro-trends,talent,cleantech-sector | high | summaries/gser-2021.md | 2026-04-15 |
| gser-2022 | Global Startup Ecosystem Report 2022 | Startup Genome | gser | 2022 | EN | ecosystem-ranking | international | entrepreneurship,funding,macro-trends,talent,ai-sector,cleantech-sector,policy | high | summaries/gser-2022.md | 2026-04-15 |
| startupblink-2017 | StartupBlink Global Startup Ecosystem Report 2017 | StartupBlink | startupblink | 2017 | EN | ecosystem-ranking | international | entrepreneurship,macro-trends,funding,incubation | medium | summaries/startupblink-2017.md | 2026-04-15 |
| startupblink-2019 | StartupBlink Global Startup Ecosystem Report 2019 | StartupBlink | startupblink | 2019 | EN | ecosystem-ranking | international | entrepreneurship,macro-trends,funding,talent | medium | summaries/startupblink-2019.md | 2026-04-15 |
| startupblink-2020 | StartupBlink Global Startup Ecosystem Report 2020 | StartupBlink | startupblink | 2020 | EN | ecosystem-ranking | international | entrepreneurship,macro-trends,funding,talent,healthtech-sector,policy | medium | summaries/startupblink-2020.md | 2026-04-15 |
| startupblink-2022 | StartupBlink Global Startup Ecosystem Report 2022 | StartupBlink | startupblink | 2022 | EN | ecosystem-ranking | international | entrepreneurship,macro-trends,funding,ai-sector,cleantech-sector,healthtech-sector | medium | summaries/startupblink-2022.md | 2026-04-15 |
| startupblink-2023 | StartupBlink Global Startup Ecosystem Report 2023 | StartupBlink | startupblink | 2023 | EN | ecosystem-ranking | international | entrepreneurship,macro-trends,funding,ai-sector,cleantech-sector,healthtech-sector,exits,talent | medium | summaries/startupblink-2023.md | 2026-04-15 |
| startupblink-2025 | StartupBlink Global Startup Ecosystem Index 2025 | StartupBlink | startupblink | 2025 | EN | ecosystem-ranking | international | entrepreneurship,funding,macro-trends,policy,ai-sector,cleantech-sector,healthtech-sector | medium | summaries/startupblink-2025.md | 2026-04-15 |
| startup-genome-scaleup-2023 | The Scaleup Report 2023 | Startup Genome | startup-genome-scaleup | 2023 | EN | industry-report | international | entrepreneurship,funding,talent,exits,commercialization,policy,macro-trends | high | summaries/startup-genome-scaleup-2023.md | 2026-04-15 |
