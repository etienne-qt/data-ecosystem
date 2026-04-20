# Day Zero Deck — Hardware & Deep Tech au Québec

**Statut:** Document de planification pré-analyse
**Auteur:** Étienne Bernard (QT — Data & Analytics)
**Version:** v0.1 (2026-04-17)
**Audience cible du rapport final:** décideurs publics (politiciens, conseillers), équipes de politique innovation, avec les orgs partenaires (QT / RC / CIQ) comme audience secondaire.

---

## À quoi sert ce document

Ce Day Zero deck identifie **toutes les slides envisagées** pour le rapport final, avec pour chacune :

- La **question analytique** à laquelle elle cherche à répondre
- Les **données et sources** pressenties
- Un **placeholder visuel** (type de chart, structure)
- Le **takeaway attendu** (la phrase-en-or que le lecteur devrait retenir)
- Les **caveats connus** (incertitudes, petits échantillons, biais)
- Le **statut** (données en main / à chercher / analyse à faire / viz à construire)

Pas de données finales ni de visuels à ce stade. L'objectif est d'aligner la structure et de repérer les trous à combler avant de lancer l'analyse en profondeur.

**Hypothèses de cadrage** (à valider) :
- **Scope** = DEEPTECH complet par `taxonomy/sectors.yaml`. Inclut photonique, quantique, semi-conducteurs, robotique, spatial, matériaux avancés, biotech-avec-hardware, MedTech. Exclut pure SaaS/AI.
- **Audience primaire** = décideurs publics avant cycle électoral (fenêtre automne 2026).
- **Benchmarks** = QC vs Ontario principalement; international en appoint (Suède, Pays-Bas, Israël).
- **Longueur cible** = ~50 slides (exécutif + détaillé).

---

## Structure en 8 sections

| Section | Slides | Focus |
|---------|--------|-------|
| 1. Cadrage | 1–5 | Cover, TL;DR, pourquoi maintenant, scope, méthodo en un clin d'œil |
| 2. Portrait | 6–12 | Combien, quoi, où, depuis quand, quelle taille |
| 3. Dynamiques | 13–20 | Taux de formation, cohortes récentes, financement, sorties |
| 4. Acteurs | 21–26 | Institutions, capital, accélérateurs, universités, talent |
| 5. Benchmarks | 27–31 | QC vs ON, Canada, pairs internationaux |
| 6. Défis & lacunes | 32–36 | Scaling, capital, talent, supply chain, gouvernance |
| 7. Recommandations | 37–42 | Instruments de politique (placeholders) |
| 8. Annexe | 43–50 | Sources, méthodo détaillée, taxonomie, limites, glossaire |

---

# Section 1 — Cadrage

## Slide 1 — Couverture

**Contenu:** Titre du rapport, sous-titre, auteurs, logos QT / RC / CIQ (si co-signé), date de publication, version, mention "confidentiel — pré-publication" pendant la review.

**Titre de travail:** *Hardware et Deep Tech au Québec — État des lieux, dynamiques, et leviers pour la prochaine décennie*

**Status:** Placeholder — à finaliser avec direction QT.

---

## Slide 2 — TL;DR

**Contenu:** 5 bullets clés (les "messages" du rapport). Draft à itérer :

1. Environ **[X] compagnies hard-tech / deep-tech** actives au Québec en 2026, dont **[Y]** incorporées depuis 2024.
2. **Soubresaut de formation 2025** (~18/trimestre vs ~12 pré-COVID), mais **photonique pure reste plate** — la croissance vient du matériel adjacent et quantique émergent.
3. **Contraste marqué avec le SaaS/AI** post-GenAI : création software 2.2x vs création hardware stagnante. Le vent GenAI ne porte pas le hard-tech.
4. **Goulot d'étranglement principal = scaling**, pas la formation. Les capacités d'incorporation existent; le passage à l'échelle manque de capital long-horizon et de demande domestique.
5. **[Recommandation phare]** — à formuler après analyse.

**Source material:** Synthèse post-analyse. Seule slide qu'on finalise à la toute fin.

**Status:** Squelette — à réécrire après section 7.

---

## Slide 3 — Pourquoi ce rapport, pourquoi maintenant

**Question analytique:** Quelle est la fenêtre de pertinence de ce rapport ?

**Contenu (narratif):**
- **Contexte global:** CHIPS Act américain (2022), Chips Act européen (2023), réponse canadienne limitée. La souveraineté technologique matérielle est redevenue un sujet politique majeur.
- **Contexte québécois:** héritage photonique profond (INO, EXFO, Coherent / ex-II-VI, MDA), pôle quantique émergent (IQ, PINQ², Nord Quantique), cluster aérospatial, présence MedTech substantielle. Base institutionnelle solide mais création de nouvelles compagnies hard-tech contrastée avec le boom AI/SaaS.
- **Contexte politique:** cycle électoral provincial fin 2026 — fenêtre pour des annonces de politique industrielle documentées.
- **Contraste structurel post-GenAI:** le tsunami de nouvelles SaaS/AI depuis 2024 risque d'occulter le fait que le hard-tech, qui demande capital patient et infrastructure, suit une trajectoire différente et mérite ses propres instruments.

**Visuel (placeholder):** timeline horizontale 2017–2026 avec événements clés (COVID, CHIPS Act, IRAs, vague GenAI, élections QC) superposée à une courbe de formation hard-tech.

**Status:** Narratif prêt; viz à construire.

---

## Slide 4 — Scope et définitions

**Question analytique:** Qu'est-ce qu'on appelle "hard tech" et "deep tech" dans ce rapport ?

**Contenu:**
- **Deep tech** = compagnies bâties sur une avancée scientifique ou d'ingénierie substantielle (par `taxonomy/sectors.yaml`, code `DEEPTECH`).
- **Inclus:**
  - Photonique, optique et imagerie (fibre optique, lasers, capteurs optiques, thermal/infrared)
  - Quantique (calcul, communications, capteurs)
  - Semi-conducteurs (conception, fabrication, test)
  - Robotique et systèmes autonomes
  - Technologies spatiales
  - Matériaux avancés (nanotech, composites, 2D)
  - Biotech avec plateforme hardware (dispositifs médicaux logiciel+hardware, diagnostics)
  - MedTech
- **Exclus explicitement:**
  - Pure SaaS / plateformes software
  - AI/ML appliquée sans composante hardware (classée `AI` dans la taxonomie)
  - Fintech, consommation, contenu
  - Consulting technologique

**Visuel (placeholder):** diagramme de Venn ou tableau 2-colonnes "Inclus / Exclus" avec exemples de compagnies publiques de chaque côté.

**Status:** Définition stabilisée. Besoin d'exemples publics de compagnies à lister.

---

## Slide 5 — Méthodologie en un clin d'œil

**Question analytique:** Comment les chiffres ont-ils été obtenus ? Quelle confiance peut-on y accorder ?

**Contenu:** 3-4 lignes pour l'audience non-technique :

1. **Univers principal:** REQ (entreprises en fonction) + registre startup QT (`GOLD.STARTUP_REGISTRY`).
2. **Classification hybride:** mots-clés sur description d'activité (haute confiance) + codes CAE (confiance plus basse). **~73 % des classifications historiques reposent sur le code CAE seul**, ce qui mérite prudence sur les trajectoires fines.
3. **Financement:** données PitchBook via Réseau Capital (si accord obtenu) + annonces publiques.
4. **Bases nominatives non accessibles:** INO, MEDTEQ+, Écotech Québec — demandes en cours.

**Renvoi:** "Méthodologie détaillée en annexe, slides 43–47."

**Visuel (placeholder):** infographie simple en 4 boîtes (Sources → Classification → Agrégats → Rapport).

**Status:** Texte prêt; besoin de confirmer accès PitchBook.

---

# Section 2 — Portrait

## Slide 6 — Combien de compagnies hard-tech au Québec

**Question analytique:** Combien d'entreprises correspondent au périmètre deep-tech / hard-tech au Québec en 2026, et comment cette estimation a-t-elle été bornée ?

**Données / sources:**
- `SILVER.REQ_PRODUCT_CLASSIFICATION` filtré sur signaux deep-tech (Q5 diagnostic + extension à tous les signaux DEEPTECH)
- `GOLD.STARTUP_REGISTRY` — cross-référence pour distinguer deep-tech "startup" de deep-tech "entreprise établie"
- Analyse existante `INTERNAL-hardware-photonics-req-2026` (~547 compagnies photonique/hardware adjacent 2017–2026 — à élargir au DEEPTECH complet)

**Visuel (placeholder):** grand chiffre en en-tête avec fourchette (ex: "~X,XXX compagnies deep-tech actives"), sous-titré par décomposition "dont ~YYY photonique, ~YYY quantique, ..."

**Takeaway attendu:** Offrir le chiffre-référence que tout le monde citera, avec une fourchette honnête plutôt qu'un nombre précis. Précédent de l'équipe : décomposer plutôt qu'un chiffre unique (voir `memory/feedback_registry_narrative`).

**Caveats:**
- Le **registre `GOLD.STARTUP_REGISTRY`** contient ~6,507 compagnies tech startup Québec; seule une fraction est deep-tech.
- Les compagnies incorporées **au fédéral (CBCA)** ne sont pas dans REQ — angle mort systématique.
- Les compagnies sans site web déclaré ou avec description vide sont sous-détectées.

**Status:** Analyse à étendre — le fichier existant couvre photonique+hardware adjacent; besoin d'inclure quantique, robotique, spatial, matériaux, biotech-hardware.

---

## Slide 7 — Répartition par sous-secteur

**Question analytique:** Comment se répartit cet univers entre les sous-secteurs deep-tech ?

**Données / sources:**
- `SILVER.REQ_PRODUCT_CLASSIFICATION.MATCHED_SIGNALS` — compter par token (photonics, quantum, semiconductor, robotics, aerospace, nanotech, medtech, pharma, biotech, cleantech)
- Validation manuelle sur un échantillon pour chaque bucket (l'analyse existante suggère ~27 % ont validation keyword directe)

**Visuel (placeholder):** graphique en barres horizontales trié décroissant, ou treemap si la hiérarchie mère-fille de la taxonomie sert.

**Takeaway attendu:** La photonique et les technologies adjacentes dominent historiquement; quantique et robotique sont petits en volume mais croissent; matériaux avancés et spatial sous-représentés en volume malgré des phares médiatisés.

**Caveats:**
- Un même NEQ peut matcher plusieurs tokens (biotech + medtech typique) — traiter distinctement "DISTINCT NEQ" vs "total occurrences".
- Section 4 (Q5 diagnostic) déjà donne le décompte par sous-catégorie post-2024.

**Status:** Analyse partielle — Q5 couvre post-2024; besoin du rétrospectif long.

---

## Slide 8 — Concentration géographique

**Question analytique:** Où sont concentrées ces compagnies au Québec ?

**Données / sources:**
- `SILVER.REQ_PRODUCT_CLASSIFICATION.HQ_CITY` (extrait par regex de l'adresse REQ)
- Agrégation par régions métropolitaines via `taxonomy/geographies.yaml` (MTL, QCC, SHE, GAT, SAG, TR)

**Visuel (placeholder):** carte choroplèthe du Québec colorée par densité, ou barres par RMR. Overlay des institutions-phares (INO à Québec, universités à MTL/SHE).

**Takeaway attendu:** Grand Montréal domine en volume absolu; Grand Québec a probablement la **plus forte densité relative** en photonique/optique grâce à l'INO et à l'Université Laval; le cluster aérospatial est Montréalais.

**Caveats:**
- Extraction d'HQ_CITY par regex = bruitée; une ville non-extraite tombe dans "unknown".
- Compagnies avec bureaux dans plusieurs RMR comptent à leur siège REQ seulement.

**Status:** Données prêtes; viz à construire.

---

## Slide 9 — Pyramide d'âge

**Question analytique:** La population deep-tech québécoise est-elle principalement neuve, mature, ou mixte ?

**Données / sources:**
- `SILVER.REQ_PRODUCT_CLASSIFICATION.INCORPORATION_YEAR` avec buckets 2026, 2020–2025, 2010–2019, 2000–2009, <2000.

**Visuel (placeholder):** histogramme par année d'incorporation, ligne moyenne/médiane; optionnellement superposé avec le même histo pour software/AI pour contraste.

**Takeaway attendu:** Deep-tech a probablement une **pyramide plus "aplatie"** que software — moins de création annuelle mais plus de maturité historique. À vérifier si la tendance 2024–2025 remonte.

**Caveats:**
- INCORPORATION_YEAR = année d'incorporation légale, pas nécessairement de début d'activité commerciale.
- Pas d'info de cessation d'activité en REQ (ENTREPRISES_EN_FONCTION = actives seulement).

**Status:** Données prêtes; analyse simple à lancer.

---

## Slide 10 — Distribution par taille d'employés

**Question analytique:** Quelle est la taille typique d'une compagnie deep-tech québécoise ?

**Données / sources:**
- `SILVER.REQ_PRODUCT_CLASSIFICATION.N_EMPLOYES` et `EMP_MIN` numérique.
- Buckets REQ : 1–5, 6–10, 11–20, 21–50, 51–100, 101–250, 251–500, 501+.

**Visuel (placeholder):** pyramide ou bar chart des tranches d'employés, couleur par sous-secteur si lisible.

**Takeaway attendu:** Très probablement **queue longue à droite** — beaucoup de petites (1–20), quelques moyennes, très peu au-dessus de 250. Hypothèse : scaling gap visible dès les données d'employés, pas seulement dans le financement.

**Caveats:**
- Les tranches N_EMPLOYES sont des bandes autodéclarées à l'inscription, pas mises à jour en temps réel.
- "Non déclaré" / "Aucun" = bucket significatif; ne pas l'écraser.

**Status:** Données prêtes.

---

## Slide 11 — Modèle d'affaires (B2B / B2C / B2G)

**Question analytique:** Quelle est la distribution B2B / B2C / B2G chez les deep-tech québécoises ?

**Données / sources:**
- `shared_ecosystem.qt_schema.companies.b2b_b2c` (via Dealroom)
- Compléments manuels sur top 50 via websites / LinkedIn

**Visuel (placeholder):** donut chart 3 segments, ou 100 % stacked bar par sous-secteur.

**Takeaway attendu:** Hard-tech est massivement **B2B ou B2G** — très peu de B2C pur. Slide surtout pour contraster avec software consumer et documenter les cycles de vente longs.

**Caveats:**
- Couverture Dealroom variable sur deep-tech (sous-secteurs émergents moins bien classifiés).
- Beaucoup de compagnies small-scale n'ont pas de champ b2b_b2c renseigné.

**Status:** Données partielles; **analyse dépend de couverture Dealroom à quantifier**.

---

## Slide 12 — Phares établis (anchors)

**Question analytique:** Quelles compagnies établies servent de "bordure" à l'écosystème et autour desquelles gravite la formation neuve ?

**Données / sources:**
- Listes publiques : EXFO, Coherent/II-VI (ex), MDA, CAE, Lion Electric, Nord Quantique (early), Kitco, AddÉnergie, GHGSat, etc.
- Seulement compagnies avec info publique — **pas de contenu licencié Dealroom/PitchBook**.
- Annonces médiatisées, sites web.

**Visuel (placeholder):** tableau ou logos mosaïque, organisé par sous-secteur, avec année de fondation, HQ, statut (private / public / acquis).

**Takeaway attendu:** Documenter la "gravité" institutionnelle — le Québec a des anchors crédibles dans plusieurs verticales, ce qui est un atout pour la formation de spinoffs.

**Caveats:**
- Inclure uniquement ce qui est vérifiable publiquement.
- Garder la liste restreinte (15–25 noms) et justifier les choix de sélection.

**Status:** Liste à construire — demander validation à l'équipe QT sur qui inclure.

---

# Section 3 — Dynamiques

## Slide 13 — Taux de formation trimestriel 2017–2026

**Question analytique:** Comment a évolué le rythme d'incorporation de compagnies hard-tech au Québec sur une décennie ?

**Données / sources:**
- `SILVER.REQ_PRODUCT_CLASSIFICATION` filtré DEEPTECH, grouped by `DATE_TRUNC('quarter', DATE_IMMATRICULATION)`.
- L'analyse existante `INTERNAL-hardware-photonics-req-2026` donne : pré-COVID 12.1/q → COVID 15.1/q → post-CHIPS 11.3/q → 2024 12.2/q → 2025–2026 18.2/q (photonique + hardware adjacent seulement).

**Visuel (placeholder):** ligne trimestrielle avec 4 zones ombrées (pré-COVID, COVID, post-CHIPS, récent) et annotations d'événements clés.

**Takeaway attendu:** **Un soubresaut récent (~50 % au-dessus de la baseline pré-COVID)**, mais petits volumes absolus donc à prendre avec des pincettes (confidence: Low, per MSG-HARDTECH-01). Mérite de monitorer 2–3 trimestres de plus.

**Caveats:**
- Échantillons trimestriels à un chiffre pour sous-secteurs — pas de tests statistiques significatifs applicables.
- 73 % de classifications via CAE seulement (MSG-HARDTECH-04) = bruit de fond.

**Status:** Viz existante en draft (dans l'analyse existante), à élargir au DEEPTECH complet.

---

## Slide 14 — Le soubresaut 2025 — signal ou bruit ?

**Question analytique:** Le pic apparent 2025–début 2026 est-il statistiquement robuste ou un artéfact de petit échantillon ?

**Données / sources:**
- Même source que slide 13.
- Test : retirer 3–4 incorporations du trimestre pic et voir si la tendance tient.
- Cross-référence avec les membres récents de MEDTEQ+, INO si accès aux listes.

**Visuel (placeholder):** zoom sur 2024–2026 avec bandes de confiance (bootstrap rough), annotation "en l'absence de X incorporations, la tendance disparaît".

**Takeaway attendu:** Honnêteté: **à monitorer, pas à publier comme fait**. Le soubresaut est probable mais requiert 3–4 trimestres de données additionnelles pour passer de "hypothèse" à "tendance".

**Caveats:**
- Reprendre mot à mot la mise en garde de MSG-HARDTECH-01 ("absolute numbers remain small").

**Status:** Analyse à faire; simple calcul de sensibilité.

---

## Slide 15 — Photonique pure vs matériel adjacent

**Question analytique:** La photonique québécoise, qui a une base institutionnelle solide (INO), génère-t-elle proportionnellement de nouvelles compagnies, ou la croissance récente vient-elle d'ailleurs ?

**Données / sources:**
- Analyse existante : photonique pure flat ~2.0–2.2/q 2017–2026; croissance dans optique/imagerie (7/q en 2025) et matériel adjacent (9/q en 2025).
- Décomposition MATCHED_SIGNALS par sous-catégorie.

**Visuel (placeholder):** 3 lignes superposées : photonique core, optique/imagerie, matériel adjacent (semi, quantique, sensors). Temps sur X, formation/trimestre sur Y.

**Takeaway attendu:** **La photonique pure est plate malgré l'INO, EXFO, etc.** La base institutionnelle ne génère PAS la vague de spinoffs qu'on attendrait. À creuser : sont-ils incorporés au fédéral ? Restent-ils au sein des institutions avant spin-off ? (voir slide 25 sur liens universités-industrie).

**Caveats:**
- MSG-HARDTECH-02 (confidence: Medium).
- Classification de sous-catégorie repose sur MATCHED_SIGNALS — peut mal séparer "photonique core" de "optique imagerie".

**Status:** Analyse existante; à élargir DEEPTECH complet.

---

## Slide 16 — La cohorte post-2024

**Question analytique:** Qui sont les nouveaux entrants hard-tech post-2024, et sont-ils prometteurs (classification haute-confiance) ou bruit (CAE-seulement) ?

**Données / sources:**
- **Q5 diagnostic** (`pipelines/validation/diagnostics/Q5_req_post2024_hardtech.sql`) déjà écrit.
- Sections 4–5 du Q5 : décomposition par sous-catégorie et par tier de confiance.

**Visuel (placeholder):** tableau des nouveaux entrants par sous-secteur × confiance (HIGH / MEDIUM / LOW), avec top 10 HIGH listés nommément si publiquement visibles.

**Takeaway attendu:** **La cohorte post-2024 penche fortement vers HIGH-confidence quantique et robotique**, le reste étant du bruit CAE-seulement qu'il faudrait filtrer. Donner un chiffre "propre" et un chiffre "brut" pour montrer la marge d'incertitude.

**Caveats:**
- Q5 dépend de `SILVER.REQ_PRODUCT_CLASSIFICATION` étant rafraîchi dans Snowflake.
- Les 50 candidats HIGH du Q5 doivent passer un check manuel avant citation nominative.

**Status:** SQL prêt; besoin de rouler dans Snowsight et trier les CSV.

---

## Slide 17 — Contraste software vs hard-tech post-GenAI

**Question analytique:** Le boom GenAI de 2023–2025 a-t-il entraîné le hard-tech, ou a-t-il au contraire creusé l'écart ?

**Données / sources:**
- Comparaison taux de formation `MATCHED_SIGNALS ILIKE '%genai%' OR '%saas%' OR '%ai%'` (software-AI) vs deep-tech.
- Analyse existante `INTERNAL-genai-impact-req-2026` : création tech-product x2.2 depuis 2022 (software), vs hardware plat.

**Visuel (placeholder):** 2 lignes indexées à 100 en 2017, l'une software-AI, l'autre hard-tech. Évolution claire de l'écart.

**Takeaway attendu:** **Le vent GenAI n'a pas porté le hard-tech.** Divergence structurelle qui justifie des instruments de politique publique **dédiés** plutôt que des programmes "tech" génériques. C'est le message-pivot du rapport.

**Caveats:**
- Classification software-AI a ses propres bruits (signaux SaaS ne sont pas tous des startups scalables).

**Status:** Analyse existante en partie; à formuler clairement la comparaison.

---

## Slide 18 — Financement hard-tech au Québec

**Question analytique:** Quel volume et quels montants de capital vont au hard-tech québécois, et comment cela se compare-t-il au software ?

**Données / sources:**
- **PitchBook / CVCA via Réseau Capital** — **à solliciter** (agrégats seulement, per gouvernance).
- Dealroom funding data pour compagnies QC classifiées DEEPTECH.
- Annonces publiques cross-référencées.

**Visuel (placeholder):** deux histogrammes empilés côte-à-côte : "Software-AI" vs "Hard-tech" pour deals et montants. Timeline 2020–2025.

**Takeaway attendu:** Hard-tech reçoit une fraction disproportionnellement petite du capital levé, avec des deals **plus rares mais plus gros en moyenne** (capital patient, peu d'acteurs).

**Caveats:**
- Source licenciée → **agrégats seulement**, pas de compagnie nommée sans source publique.
- Accès PitchBook via RC requiert accord formel — **bloquant** pour cette slide tant que non obtenu.

**Status:** **Bloquant sur accord RC.** Écrire la demande formelle.

---

## Slide 19 — Sorties notables

**Question analytique:** Quelles acquisitions et IPOs ont marqué le hard-tech québécois sur la dernière décennie ?

**Données / sources:**
- Annonces publiques (Bloomberg, communiqués, presse spécialisée) — **sources publiques uniquement**.
- PitchBook `exits` pour vérification si accord RC obtenu.
- Liste historique: II-VI acquisition de l'unité MPB (2021), activités Coherent, etc.

**Visuel (placeholder):** timeline horizontal avec 8–15 sorties marquantes, taille des bulles = valeur si publique.

**Takeaway attendu:** **Quelques sorties significatives** sur la décennie, dominées par acquisitions par stratégiques US. Peu d'IPOs. La sortie canadienne/québécoise reste rare → implication pour l'écosystème de risque.

**Caveats:**
- Sorties privées non annoncées publiquement ne sont pas dans le tableau.
- Valeurs de transactions souvent non divulguées.

**Status:** Liste à bâtir depuis sources publiques.

---

## Slide 20 — Trajectoires par sous-secteur

**Question analytique:** Quels sous-secteurs deep-tech montent, stagnent, ou reculent ?

**Données / sources:**
- Time-series de formation par sous-secteur de la taxonomie (photonique, quantique, semi, robotique, spatial, matériaux, biotech-hw, medtech).
- Optionnel : croisement avec données de financement quand disponible.

**Visuel (placeholder):** small multiples — 8 mini-lignes disposées en grille 4×2, normalisées, avec badge "↑ / → / ↓" de tendance.

**Takeaway attendu:** Carte synthétique des dynamiques — **quantique et robotique montent**, **photonique plate**, **semi quasi-inexistant** (problème de chaîne de valeur), **spatial stable grâce aux anchors**. Orienter Section 6 et 7 sur les sous-secteurs à lever.

**Caveats:**
- Petits échantillons par sous-secteur — traiter comme qualitatif plutôt que précis.

**Status:** Analyse à faire.

---

# Section 4 — Acteurs

## Slide 21 — Institutions de recherche et de transfert

**Question analytique:** Quelle est la base institutionnelle sur laquelle s'appuie le hard-tech québécois ?

**Données / sources:**
- Publiques : INO (Québec), MEDTEQ+ (MTL), Écotech Québec, IVADO (AI-adjacent), Mila, Institut Quantique (Sherbrooke), PINQ² (Bromont), Prompt, CRIQ, CNRC lab Boucherville, NéoMed.
- **Listes de membres si accord obtenu** → précieuses pour cross-ref avec REQ.

**Visuel (placeholder):** carte géographique du QC avec les institutions positionnées, taille proportionnelle à budget / effectifs publics.

**Takeaway attendu:** Base institutionnelle **dense et géographiquement distribuée** (Québec-MTL-Sherbrooke-Bromont). Peu d'écosystèmes canadiens ont autant d'infrastructures de recherche appliquée hard-tech.

**Caveats:**
- Budget / effectifs publics quand divulgués; sinon qualitatif.

**Status:** Texte prêt; viz carte à construire.

---

## Slide 22 — Financement public et non-dilutif

**Question analytique:** Quels instruments publics canadiens et québécois soutiennent le hard-tech ? Lesquels sont lisibles par des opérateurs hard-tech ?

**Données / sources:**
- **Publiques:** SR&ED, PARI/IRAP, Programmes du Québec (MEIE, MITACS, FRQNT, Investissement Québec programmes), Canada SIF, Stratégie quantique, CanExport.
- Rapports MEIE (`insights/reports-external/meie-portrait-entrepreneurs-2025.md`).

**Visuel (placeholder):** tableau matriciel "instrument × stade × sous-secteur applicable", avec codage couleur lisibilité/pertinence.

**Takeaway attendu:** Beaucoup d'instruments existent, mais **lisibilité et coordination déficientes** pour un fondateur hard-tech. **Pas d'équivalent CHIPS Act** au niveau fédéral ou provincial — lacune structurelle à documenter.

**Caveats:**
- Informations peuvent dater vite (budgets fédéraux changent) — dater la slide.

**Status:** Inventaire à construire depuis sources publiques + MEIE.

---

## Slide 23 — Investisseurs privés actifs en hard-tech

**Question analytique:** Quels fonds VC / PE / corporate investissent dans le hard-tech québécois ? Sont-ils suffisants, manquent-ils à certains stades ?

**Données / sources:**
- PitchBook / CVCA via RC — agrégats seulement.
- Sites des fonds : Inovia, Real Ventures, Amplitude, Framework Venture Partners, BDC Capital, Investissement Québec, Fonds FTQ, Fondaction, Caisse de dépôt (IA-focus), Cycle Capital, Cycle Capital Clean, Amorchem.
- Listes d'investisseurs dans annonces publiques.

**Visuel (placeholder):** bar chart des top 15 investisseurs par # deals hard-tech QC 2020–2025; annotation du stade (seed/A/B/growth).

**Takeaway attendu:** **Capital seed disponible, capital scale-up (Série B+) rare et souvent étranger**. Goulot classique canadien, particulièrement aigu en hard-tech vu l'intensité capitalistique.

**Caveats:**
- Toutes les données licensed → agrégats seulement.
- "Actif en hard-tech" = au moins N deals dans la période — choix de seuil à justifier.

**Status:** Bloquant sur accord RC.

---

## Slide 24 — Accélérateurs et incubateurs à orientation hard-tech

**Question analytique:** Quels programmes québécois ont une spécialisation ou une ouverture réelle au hard-tech ?

**Données / sources:**
- Listes publiques : Centech (Polytechnique), District 3 (Concordia), TandemLaunch (spinoffs universitaires deep-tech), Cycle Momentum (cleantech), MEDTEQ+ accelerator programs, Prompt AI-hardware intersection.
- Cohortes récentes des programmes (sites web).

**Visuel (placeholder):** tableau : nom / affiliation / cohorte/an / verticale / stade / exemple de diplômé hard-tech.

**Takeaway attendu:** Quelques programmes solides (Centech, TandemLaunch, MEDTEQ+) mais **écosystème accélération plus tourné vers software**. Opportunité de renforcer.

**Caveats:**
- Cohortes varient; données 2024–2025 peuvent être partielles.

**Status:** Inventaire à construire.

---

## Slide 25 — Liens universités-industrie et spinoffs

**Question analytique:** Les universités québécoises (McGill, Polytechnique, UdeM, Concordia, Laval, Sherbrooke) génèrent-elles des spinoffs hard-tech à un rythme compétitif ?

**Données / sources:**
- Bureaux de transfert (Gestion Univalor, SOVAR, Aligo) — rapports annuels quand publics.
- Listes de spinoffs universitaires (Sherbrooke a une liste publique; autres à collecter).
- Cross-ref avec REQ via nom / adresse / fondateur si possible.

**Visuel (placeholder):** barres horizontales par université : spinoffs hard-tech créés 2015–2025, avec ratio sur le total (contexte budget recherche).

**Takeaway attendu:** **Sherbrooke punches above its weight en quantique.** McGill forte en photonique/semi. Polytechnique + UdeM forts en robotique/aéro. **Conversion recherche → compagnies sous-optimale** comparé à ETH Zurich, Stanford, MIT.

**Caveats:**
- Données spinoffs pas normalisées entre universités.
- Federal CBCA spinoffs sous-détectés.

**Status:** Données à collecter; lourd mais important.

---

## Slide 26 — Talent : ingénieurs, PhDs, opérateurs

**Question analytique:** Le bassin de talent hard-tech québécois est-il suffisant pour soutenir une accélération ?

**Données / sources:**
- StatCan ESCM, EAMT — diplômés STEM par année.
- Tableau MEIE sur talent (`insights/reports-external/meie-portrait-entrepreneurs-2025.md`).
- LinkedIn data (coûteux, non-licensé) → benchmark international seulement.
- Rapports GSER / StartupBlink sur rang de talent Québec.

**Visuel (placeholder):** 3 indicateurs : (1) nouveaux diplômés STEM, (2) PhDs par an, (3) "operators avec expérience scale-up hard-tech" (qualitatif).

**Takeaway attendu:** **Pool de diplômés solide**, mais **opérateurs expérimentés (C-level hard-tech ayant vécu un scale-up) rares** — importation nécessaire, enjeu immigration.

**Caveats:**
- Qualité qualitative pour la 3e métrique — reconnaître la limite.

**Status:** Données publiques prêtes; qualitatif à argumenter.

---

# Section 5 — Benchmarks

## Slide 27 — Québec vs Ontario

**Question analytique:** Comment l'écosystème hard-tech québécois se compare-t-il à celui de l'Ontario (Toronto + Waterloo) en taille, composition, financement ?

**Données / sources:**
- Ontario Business Registry si accessible (équivalent REQ) — à vérifier.
- Rapports Toronto Global, MaRS, Communitech.
- Dealroom / PitchBook Ontario si accès RC.

**Visuel (placeholder):** tableau comparatif : compagnies, financement, sorties, universités, anchors, instruments publics.

**Takeaway attendu:** **Ontario plus gros en volume absolu** (population 1.8x), mais **densité Québec comparable ou supérieure** dans plusieurs verticales (photonique, quantique, cleantech). Ontario avance plus vite sur semi (WaterlooFabX, potentiel).

**Caveats:**
- Bases de données provinciales asymétriques.
- Comparaison "toutes choses égales" difficile.

**Status:** Recherche à faire.

---

## Slide 28 — Québec vs Canada (total)

**Question analytique:** Quelle part du hard-tech canadien est québécoise ?

**Données / sources:**
- StatCan (comptes R-D industrielle par province).
- ISED Key Small Business Statistics (`insights/reports-external/ised-ksbs-2025.md`).
- GSER / StartupBlink rankings.

**Visuel (placeholder):** diagramme en donut "parts de marché" des provinces dans le hard-tech canadien par indicateurs-clés.

**Takeaway attendu:** Québec = ~20–25 % du PIB canadien mais **surreprésentation en photonique, quantique, cleantech, aérospatial**.

**Caveats:**
- Définitions StatCan peuvent différer de nos définitions taxonomiques.

**Status:** Données publiques prêtes.

---

## Slide 29 — Québec vs pairs internationaux

**Question analytique:** Comment le Québec se compare-t-il à d'autres juridictions de taille comparable avec fort focus deep-tech (Suède, Pays-Bas, Israël, Singapour) ?

**Données / sources:**
- GSER 2024–2025, StartupBlink Global 2025 (`insights/reports-external/gser-2025.md`, `startupblink-2025.md`).
- Rapports nationaux de chaque pays quand accessibles.

**Visuel (placeholder):** radar chart ou tableau normalisé par habitant : compagnies deep-tech, capital levé, universités top-100, exits.

**Takeaway attendu:** **Québec comparable à Pays-Bas / Suède en photonique**, **loin derrière Israël en quantique/semi**, **loin derrière Singapour en politiques industrielles délibérées**.

**Caveats:**
- Comparabilité limitée par différences définitionnelles.
- Rapports internationaux ont leurs propres biais.

**Status:** Lectures à synthétiser.

---

## Slide 30 — CHIPS Act et équivalents

**Question analytique:** Quels effets observés des grandes politiques industrielles récentes (US CHIPS Act 2022, EU Chips Act 2023, stratégie quantique CA 2023) ? Qu'est-ce qui manque au Canada/Québec ?

**Données / sources:**
- Publications publiques : White House CHIPS implementation reports, European Commission dashboards, Conseil consultatif canadien sur les semiconducteurs.

**Visuel (placeholder):** timeline des programmes + montants engagés + effets mesurés après 3 ans; colonne "Canada" en grande partie vide.

**Takeaway attendu:** **Le Canada n'a pas de CHIPS Act.** La Stratégie quantique canadienne (2023, 360M$) est insuffisante en taille et en ciblage matériel. Le Québec pourrait aller plus loin unilatéralement en semi/photonique.

**Caveats:**
- Effets économiques des Acts n'ont que 3 ans de recul.

**Status:** Recherche documentaire à faire.

---

## Slide 31 — Capital availability par stade

**Question analytique:** À quels stades de financement le Québec souffre-t-il le plus en hard-tech vs pairs ?

**Données / sources:**
- PitchBook / CVCA via RC — agrégats par stade.
- Stratification seed / A / B / growth pour hard-tech QC, compared to ON et US benchmark.

**Visuel (placeholder):** 4 barres par région (Seed, A, B, Growth) — QC vs ON vs US moyen.

**Takeaway attendu:** **Seed correct, A correct, B et Growth critiquement manquants** pour hard-tech. Point structurel déjà connu pour tech en général; hard-tech l'amplifie.

**Caveats:**
- Stages Dealroom vs PitchBook peuvent différer — normaliser via `taxonomy/stages.yaml`.

**Status:** Bloquant sur accord RC.

---

# Section 6 — Défis et lacunes

## Slide 32 — Le gap de scaling

**Question analytique:** Combien de compagnies hard-tech québécoises passent du stade seed au stade scaleup ($10M+ ARR / 50+ employés) ?

**Données / sources:**
- Compter dans `GOLD.STARTUP_REGISTRY` + données financement les compagnies franchissant les seuils.
- Comparer ratio formation → scaleup au software.

**Visuel (placeholder):** funnel — formation / premier tour / Série A / scaleup — pour hard-tech vs software.

**Takeaway attendu:** **Funnel hard-tech beaucoup plus étroit au sommet.** Les cohortes atteignent difficilement la maturité; capital patient et demande domestique manquent.

**Caveats:**
- Cohortes petites → valeurs bruitées.

**Status:** Analyse à faire.

---

## Slide 33 — Intensité capitalistique et capex

**Question analytique:** Le capital disponible au Québec est-il adapté à l'intensité capex du hard-tech (équipements, fab, certifications) ?

**Données / sources:**
- Estimations capex par sous-secteur (littérature publique, comparables).
- Taille moyenne des rounds Series A hard-tech vs software au Québec.

**Visuel (placeholder):** barres "capex requis pour atteindre break-even" par sous-secteur vs "taille moyenne Series A au Québec".

**Takeaway attendu:** **Écart structurel** — les rounds typiques QC ne suffisent pas pour MVP hardware dans la moitié des sous-secteurs deep-tech. Rationale pour instruments publics ou programmes MatchCap.

**Caveats:**
- Estimations capex varient énormément intra-sous-secteur.

**Status:** Recherche + analyse à faire.

---

## Slide 34 — Pénurie de talents-clés

**Question analytique:** Quels profils manquent le plus, et comment ça bloque la croissance ?

**Données / sources:**
- Enquêtes MEIE / Emploi-Québec sur pénurie STEM.
- Témoignages (entretiens qualitatifs à conduire).

**Visuel (placeholder):** matrix 2x2 — profil × sévérité de pénurie (qualitatif).

**Takeaway attendu:** VP Engineering ayant scaled un hard-tech, ingénieurs process semi, PhDs quantique appliqué, operators EU/US avec réseaux — **les plus rares et difficiles à recruter**.

**Caveats:**
- Qualitatif; à valider par entretiens.

**Status:** Entretiens à planifier.

---

## Slide 35 — Capacité manufacturière et supply chain

**Question analytique:** Le Québec peut-il faire scale ses compagnies hard-tech localement, ou dépend-il entièrement de la sous-traitance externe (US, Asie) ?

**Données / sources:**
- Inventaire des foundries / ateliers propres (INO fab, CMC Microsystems, AAC, etc.).
- Rapports stratégie quantique CA + semi.

**Visuel (placeholder):** carte des capacités manufacturières au Canada, heatmap par sous-secteur.

**Takeaway attendu:** **Foundry quantique (Bromont — IBM/PINQ²) remarquable**, mais globalement dépendance forte hors-QC pour fab semi, assembly hardware, certification. Vulnérabilité géopolitique.

**Caveats:**
- Ne pas surestimer "faiblesse" — certains choix dépendance sont rationnels (scale).

**Status:** Inventaire à construire.

---

## Slide 36 — Fragmentation fédéral-provincial

**Question analytique:** Les instruments fédéraux et provinciaux s'articulent-ils en ensemble cohérent, ou créent-ils confusion ?

**Données / sources:**
- Cartographie des programmes (slide 22) remixée par niveau de gouvernement.
- Entretiens qualitatifs avec opérateurs.

**Visuel (placeholder):** diagramme en flux montrant la trajectoire d'un opérateur cherchant financement / support — nombre de portes d'entrée, temps moyen.

**Takeaway attendu:** **Fragmentation crée friction** — un fondateur typique consulte 4–6 programmes avant de faire le tri. Opportunité pour guichet unique (Québec) ou au moins matrice de navigation.

**Caveats:**
- Qualitatif à l'appui d'entretiens.

**Status:** Entretiens à planifier.

---

# Section 7 — Recommandations

> **Note:** Les recommandations finales doivent émerger de l'analyse, pas la précéder. Ci-dessous, les hypothèses de travail — à confirmer, amender, ou rejeter après sections 2–6.

## Slide 37 — Principes directeurs

**Placeholder.** Principes qui guideront les recommandations :

1. **Ciblage sous-sectoriel**, pas soutien générique "tech".
2. **Capital patient + demande domestique**, les deux simultanés.
3. **Miser sur les anchors existants** (INO, MEDTEQ+, IQ) plutôt que recréer.
4. **Coordonner fédéral-provincial**, pas rivaliser.

**Status:** À débattre.

---

## Slide 38 — Rec 1 (placeholder) — Capital matériel

**Hypothèse:** Créer un fonds spécifique hard-tech (matching provincial + Investissement Québec + BDC) avec ticket-size alignés sur intensité capex du secteur (Séries B 25–75M$).

**Status:** À confirmer post-analyse section 6.

---

## Slide 39 — Rec 2 (placeholder) — Talent / immigration

**Hypothèse:** Programme d'immigration accéléré pour opérateurs hard-tech expérimentés (scale-up operators, VP Eng hardware), avec partenariats avec anchors.

**Status:** À confirmer.

---

## Slide 40 — Rec 3 (placeholder) — Institutions-phares

**Hypothèse:** Financement accru des bureaux de transfert universitaires QC avec mandat spécifique spinoffs hard-tech; fonds de "proof-of-concept" pré-incorporation.

**Status:** À confirmer.

---

## Slide 41 — Rec 4 (placeholder) — Demande domestique / procurement

**Hypothèse:** Programmes de procurement stratégique (Hydro-Québec, Santé publique, transport) cadrés pour sourcer auprès de fournisseurs hard-tech locaux — inspiré modèles Israël / Singapour.

**Status:** À confirmer.

---

## Slide 42 — Roadmap et suivi

**Placeholder.** Priorisation 3-3-3 : 3 actions sur 12 mois, 3 sur 36 mois, 3 sur 5 ans. Indicateurs de suivi quantitatifs.

**Status:** À remplir fin de draft.

---

# Section 8 — Annexe

## Slide 43 — Sources de données

**Contenu:** Liste détaillée de toutes les sources avec provenance, date de coupure, licensing, et notes de qualité.

- REQ (public, 2026-04)
- `SILVER.REQ_PRODUCT_CLASSIFICATION` (dérivé, 2026-04)
- Dealroom via QT (licencié, agrégats seulement)
- PitchBook via RC (licencié, agrégats seulement) — pending accord
- StatCan, ISED, MEIE (public)
- Rapports externes recensés dans `insights/reports-external/`

**Status:** Prêt à écrire.

---

## Slide 44 — Méthodologie détaillée (1/3) — Classification

**Contenu:** Description de la classification hybride keywords + CAE (stage 31), listes de signaux utilisés, scores et seuils.

Renvoi vers `pipelines/transforms/silver/31_req_product_classification.sql`.

**Status:** Référentiel prêt.

---

## Slide 45 — Méthodologie détaillée (2/3) — Matching entre sources

**Contenu:** Comment les sources (REQ / Dealroom / Réseau Capital) ont été unifiées : bridge NEQ, fuzzy name matching ≥ 0.85, manual review whitelist. Taux de match observés.

Renvoi vers `pipelines/transforms/entity_resolution/`.

**Status:** Référentiel prêt.

---

## Slide 46 — Méthodologie détaillée (3/3) — Agrégats et gouvernance

**Contenu:** Règles de gouvernance : agrégats seulement pour données licenciées, seuil minimum 5 enregistrements, pas de noms de compagnies depuis sources licensées.

Renvoi vers `DATA-GOVERNANCE.md`.

**Status:** Référentiel prêt.

---

## Slide 47 — Taxonomie employée

**Contenu:** Résumé visuel de `taxonomy/sectors.yaml` et `taxonomy/startup-criteria.yaml` — codes, labels, hiérarchie. Rendre explicite quels codes sont dans le périmètre "deep tech" de ce rapport.

**Status:** Texte prêt.

---

## Slide 48 — Limitations connues

**Contenu:** Liste complète des caveats :

- 73 % des classifications REQ hard-tech reposent sur CAE seul (MSG-HARDTECH-04)
- Compagnies incorporées fédéralement (CBCA) manquantes dans REQ
- REQ capte l'incorporation, pas l'activité commerciale
- Small sample sizes par sous-secteur → pas de tests statistiques fins
- Absence de données financement RC (pending accord) pour plusieurs slides
- Classification de sous-catégorie repose sur tokens keyword — biais connus

**Status:** Prêt à finaliser.

---

## Slide 49 — Reproductibilité

**Contenu:** Pointers vers le code et les données :

- Branche : `report/hardware-deeptech-quebec`
- Code : `reports/2026-h2/hardware-deeptech-quebec/analysis/` + `pipelines/`
- Diagnostics Q5 : `pipelines/validation/diagnostics/Q5_req_post2024_hardtech.sql`
- Classification silver : `pipelines/transforms/silver/31_req_product_classification.sql`
- Insights agrégés : `insights/2026-h2/hardware-deeptech-*.md`

**Status:** Prêt à finaliser au moment du livrable.

---

## Slide 50 — Équipe, remerciements, glossaire, versioning

**Contenu:**
- Équipe projet (lead, reviewers, contributeurs data)
- Remerciements (partenaires ayant partagé listes / données)
- Glossaire : deep tech, hard tech, photonique, quantique, scale-up, CAE, NEQ, etc.
- Version et data cutoff; contact pour questions.

**Status:** Placeholder; à remplir en fin de projet.

---

# Questions ouvertes — à trancher avant que je passe de Day 0 à analyse détaillée

Avant de lancer la production des slides, voici ce que j'aimerais confirmer avec toi :

1. **Scope DEEPTECH large OU focus hardware/photonique seulement ?**
   J'ai proposé large (inclut quantique, robotique, biotech-hardware, spatial, matériaux). L'analyse existante `INTERNAL-hardware-photonics-req-2026` est plus étroite. Si tu veux rester cohérent avec l'analyse existante, on restreint. Si tu veux faire un rapport plus ambitieux, on élargit (mais volume de travail plus grand).

2. **Audience primaire confirmée ?**
   J'ai présumé décideurs publics avant élections QC 2026. Si c'est plutôt pour un conseil d'administration, les partenaires internes, ou un public industriel, je reformule le ton et la densité.

3. **Accord Réseau Capital sur les données de financement ?**
   Les slides 18, 23, 31 en dépendent. Si pas d'accord RC, je dois soit les abandonner, soit les rebâtir sur annonces publiques seulement (version allégée). Je dois savoir avant de m'y engager.

4. **Benchmarks internationaux — quels pays ?**
   Proposition : Suède, Pays-Bas, Israël. Pourquoi ces trois-là : taille d'économie comparable + deep-tech fort + données publiques disponibles. Si tu préfères un set différent (ex. Singapour, Corée du Sud, Danemark), dis-moi.

5. **Recommandations — démarrer avec hypothèses ou attendre l'analyse ?**
   J'ai mis 4 placeholders (capital / talent / institutions / demande) comme hypothèses de travail. Si tu veux des recos plus spécifiques avant l'analyse (ex. lié à un programme gouvernemental précis), nomme-le et je le bâtis dedans. Sinon, on laisse émerger.

6. **Co-signature QT + RC + CIQ ou QT seul ?**
   Impact sur le ton, le processus de review, et les data partners qu'on peut solliciter. Si co-signé, il faut engager RC/CIQ dès maintenant sur leur apport.

7. **Date cible de publication ?**
   J'ai mis **septembre 2026** (avant campagne électorale provinciale). Confirme ou ajuste — ça conditionne le tempo de toutes les slides "data à aller chercher".

Une fois ces 7 points clarifiés, je peux :
- Finaliser les slides en version française "quasi-finale"
- Générer une version `.pptx` ou Google Slides
- Lancer les analyses manquantes (slides marqués "Status: À faire")
- Rédiger les demandes formelles aux partenaires pour les données bloquantes
