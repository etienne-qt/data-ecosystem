# Hardware & Deep Tech au Québec — Report Brief

## Scope
- **Période couverte:** 2017 – Q1 2026 (formation et dynamique historique), snapshot 2026 (portrait courant)
- **Géographie:** Québec (primaire), Ontario et Canada en benchmark, 2-3 pairs internationaux (Suède, Pays-Bas, Israël) en complément
- **Secteurs:** DEEPTECH complet par `taxonomy/sectors.yaml` — photonique, quantique, semi-conducteurs, robotique / systèmes autonomes, technologies spatiales, matériaux avancés, biotech avec plateforme hardware, MedTech. **Exclus:** pure software, AI/SaaS, fintech sans composante hardware.

## Data sources
- [x] REQ (Registraire des entreprises du Québec) — incorporations, codes CAE, secteurs
- [x] `SILVER.REQ_PRODUCT_CLASSIFICATION` — classification hybride (keywords + CAE)
- [x] `GOLD.STARTUP_REGISTRY` — univers consolidé (Dealroom + RC)
- [ ] PitchBook / RC — données de financement hard-tech (à solliciter de RC)
- [x] Rapports externes sous `insights/reports-external/` (GSER, StartupBlink, BDC, Deloitte, Stanford, MEIE, MTB)
- [ ] INO / MEDTEQ+ / Écotech Québec — listes de membres (à solliciter)
- [ ] StatCan — comptes provinciaux, R-D industrielle (public)
- [ ] US CHIPS Act + EU Chips Act — données comparatives publiques

## Questions centrales
1. **Combien et qui ?** Quel est l'univers de compagnies hard-tech / deep-tech au Québec aujourd'hui, et comment se compare-t-il au reste du Canada et à des pairs internationaux ?
2. **Qu'est-ce qui bouge ?** Y a-t-il un vrai momentum post-2024 dans le hard-tech québécois, ou est-ce du bruit statistique sur de petits volumes ? Les dynamiques diffèrent-elles entre photonique mature, quantique émergent, et matériel adjacent ?
3. **Où sont les lacunes ?** Formation vs. scaling, capital vs. talent, acteurs institutionnels vs. opérateurs — quel est le goulot d'étranglement le plus structurant pour la prochaine décennie ?
4. **Quoi faire ?** Quels instruments de politique publique, québécois ou fédéraux, pourraient déplacer les indicateurs ?

## Timeline
- **Branche créée:** 2026-04-17
- **Day Zero deck validé:** target fin avril 2026
- **Draft v1 (analyses + narratif):** target juin 2026
- **Review interne (QT + RC + CIQ si pertinent):** target juillet 2026
- **Livrable final (PDF FR/EN):** target septembre 2026 (avant campagne électorale provinciale)

## Contributors
- **Lead:** Étienne Bernard (QT — Data & Analytics)
- **Reviewers:** à identifier
- **Data partners:** Réseau Capital (financement), INO / MEDTEQ+ (acteurs institutionnels) si accord

## Deliverables merging to main
1. **Insights** → `insights/2026-h2/hardware-deeptech-*.md` (findings agrégés, format frontmatter)
2. **Scripts réutilisables** → `pipelines/` si applicables au-delà de ce rapport
3. **PDF final** → `reports/2026-h2/hardware-deeptech-quebec/hardware-deeptech-quebec-2026.pdf`
4. **Mise à jour** de `insights/index.yaml`

Scripts spécifiques au rapport (qui ne deviennent pas des pipelines généraux) restent dans l'historique de cette branche, pas sur main.

## Drafts
- `drafts/day-zero-deck.md` — planification slide-by-slide, placeholders visuels, questions analytiques par slide
