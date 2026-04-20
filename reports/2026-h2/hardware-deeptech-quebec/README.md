# Hardware & Deep Tech au Québec — Report Brief

## Scope
- **Période couverte:** 2017 – Q1 2026 (formation et dynamique historique), snapshot 2026 (portrait courant)
- **Géographie:** Québec (primaire), avec 8 benchmarks externes (voir ci-dessous)
- **Secteurs:** DEEPTECH large — les 9 piliers décrits dans `analysis/taxonomy-and-definitions.md` : photonique/optique, quantique, semi-conducteurs, robotique / systèmes autonomes, technologies spatiales, matériaux avancés, MedTech et biotech-hardware, cleantech hardware, agri-tech avec hardware. **Exclus:** pure SaaS, IA sans hardware, fintech, consommation.
- **Audience cible:** **grand public**. Registre accessible, visuels dominants, jargon minimum, exemples concrets de compagnies québécoises tout au long.

## Benchmarks internationaux et domestiques

Huit régions comparatives groupées par archétype :

| Archétype | Régions | Pourquoi |
|-----------|---------|----------|
| Petits champions deep-tech | Suède, Israël, Singapour | Taille économique comparable au QC, succès documentés |
| Politique industrielle ciblée | Corée du Sud | Modèle de coordination état-industrie sur semi et matériaux |
| Grandes économies anchors | Allemagne, États-Unis | CHIPS Act (US), Mittelstand (DE), références de politique |
| Émergent / transitionnel | Pologne | Base post-2004 accélérée, leçons d'intégration EU |
| Domestique | Reste du Canada (Ontario + autres) | Baseline provincial-fédéral |

## Co-signature et partenaires

- **Co-signataires confirmés:** Quebec Tech + Réseau Capital
- **Co-signataire en discussion:** Conseil de l'Innovation du Québec (CIQ)
- **Implication des partenaires sur les données:**
  - RC : données PitchBook / CVCA pour les slides de financement (slides 18, 23, 31)
  - CIQ (si in): Baromètre de l'innovation, métriques de politique
  - QT : Dealroom/Radar, REQ, registre consolidé

## Data sources
- [x] REQ (Registraire des entreprises du Québec) — incorporations, codes CAE, secteurs
- [x] `SILVER.REQ_PRODUCT_CLASSIFICATION` — classification hybride (keywords + CAE)
- [x] `GOLD.STARTUP_REGISTRY` — univers consolidé (Dealroom + RC)
- [ ] PitchBook / RC — données de financement hard-tech (**critique, à solliciter formellement de RC**)
- [x] Rapports externes sous `insights/reports-external/` (GSER, StartupBlink, BDC, Deloitte, Stanford, MEIE, MTB)
- [ ] INO / MEDTEQ+ / Écotech Québec — listes de membres (à solliciter)
- [ ] StatCan — comptes provinciaux, R-D industrielle (public)
- [ ] US CHIPS Act + EU Chips Act + Stratégie quantique CA — données comparatives publiques
- [ ] Données comparatives internationales — GSER national reports, statistiques OCDE, rapports nationaux Suède/Israël/Singapour/Allemagne/États-Unis/Pologne/Corée

## Questions centrales

1. **Combien et qui ?** Quel est l'univers de compagnies deep-tech au Québec aujourd'hui, et comment se décompose-t-il entre les 9 piliers ?
2. **Qu'est-ce qui bouge ?** Le soubresaut post-2024 est-il réel ou statistique ? Les dynamiques diffèrent-elles par pilier ?
3. **Comment on se compare ?** Qu'apprend-on en mettant le QC côte-à-côte avec 8 pairs internationaux / domestiques ?
4. **Où sont les lacunes ?** Formation vs. scaling, capital vs. talent, acteurs institutionnels vs. opérateurs — quel est le goulot d'étranglement le plus structurant ?
5. **Quoi faire ?** Quels instruments de politique publique pourraient déplacer les indicateurs ? (Recommandations émergent de l'analyse)

## Timeline

- **Day Zero deck validé:** fin avril 2026 (~2 semaines)
- **Demande formelle à RC pour données PitchBook:** semaine du 21 avril
- **Analyses principales (sections 2–4):** mai 2026
- **Benchmarks internationaux:** mai–début juin 2026 (recherche documentaire)
- **Draft v1 (analyses + narratif):** mi-juin 2026
- **Review interne QT + RC + CIQ:** fin juin 2026
- **Révisions et ajustements:** début juillet 2026
- **Livrable final (PDF FR/EN):** **mi-juillet 2026**

**Tension temps/ambition:** 12 semaines pour un rapport de 50 slides grand public avec 8 benchmarks + production bilingue + review multi-orgs. Les slides bloquantes sur RC (18, 23, 31) doivent être débloquées dans les 2 premières semaines, sinon on bascule vers version "annonces publiques seulement" pour respecter la date.

## Contributors

- **Lead QT:** Étienne Bernard (Data & Analytics)
- **Lead RC:** à nommer
- **Lead CIQ (si in):** à nommer
- **Reviewers:** à identifier (au moins un par org co-signataire)
- **Visualisation et design final:** à identifier (interne QT ou prestataire)
- **Traduction FR/EN:** à identifier

## Deliverables merging to main

1. **Insights** → `insights/2026-h2/hardware-deeptech-*.md` (findings agrégés, format frontmatter)
2. **Taxonomie de référence** → `analysis/taxonomy-and-definitions.md` (peut être promu en skill ou en doc à terme)
3. **Scripts réutilisables** → `pipelines/` si applicables au-delà de ce rapport
4. **PDF final** → `reports/2026-h2/hardware-deeptech-quebec/hardware-deeptech-quebec-2026.pdf`
5. **Version .pptx éditable** → `reports/2026-h2/hardware-deeptech-quebec/hardware-deeptech-quebec-2026.pptx`
6. **Mise à jour** de `insights/index.yaml`

Scripts spécifiques au rapport (qui ne deviennent pas des pipelines généraux) restent dans l'historique de cette branche, pas sur main.

## Drafts et documents de travail

- `drafts/day-zero-deck.md` — planification slide-by-slide, placeholders visuels, questions analytiques par slide
- `analysis/taxonomy-and-definitions.md` — **document de référence taxonomique** (9 piliers définis, signaux, exemples publics, caveats)
- `analysis/` (à venir) — scripts d'analyse spécifiques au rapport
- `drafts/` (à venir) — drafts itératifs du narratif
