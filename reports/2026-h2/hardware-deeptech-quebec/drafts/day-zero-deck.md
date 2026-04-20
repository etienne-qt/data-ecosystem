# Day Zero Deck — Hardware & Deep Tech au Québec

**Statut:** Document de planification pré-analyse
**Auteur:** Étienne Bernard (QT — Data & Analytics)
**Version:** v0.2 (2026-04-17) — mise à jour post-cadrage
**Audience cible du rapport final:** **grand public**. Registre accessible, visuels dominants, jargon minimum, exemples concrets de compagnies québécoises tout au long. Les partenaires co-signataires et les décideurs publics forment l'audience secondaire.
**Co-signataires:** **Quebec Tech + Réseau Capital** (confirmés), **CIQ** (en discussion).
**Date cible:** **mi-juillet 2026** (avant la pause estivale).

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

**Document de référence associé:** `analysis/taxonomy-and-definitions.md` — décompose en 9 piliers le périmètre "deep tech large", définit chacun, liste les signaux de classification (mots-clés + CAE), les exemples publics québécois et les caveats. Le deck s'y réfère plutôt que de dupliquer.

**Cadrage arrêté (2026-04-17):**
- **Scope** = DEEPTECH large — 9 piliers (photonique, quantique, semi, robotique, spatial, matériaux, medtech/biotech-hw, cleantech-hw, agri-tech-hw). Voir `analysis/taxonomy-and-definitions.md`.
- **Audience primaire** = **grand public**. Ton accessible, story-first, densité visuelle élevée.
- **Benchmarks** = **8 régions** groupées par archétype (voir Section 5). Petits champions (SE, IL, SG), politique industrielle (KR), grandes économies (DE, US), émergent (PL), domestique (reste du Canada).
- **Co-signature** = QT + RC + possiblement CIQ.
- **Longueur cible** = ~45 slides (trim de 50 → 45 pour grand public — plus ciblé, moins dense).

---

## Structure en 8 sections

| Section | Slides | Focus |
|---------|--------|-------|
| 1. Cadrage | 1–5 | Cover, TL;DR, pourquoi maintenant, définitions (4 + 4bis), méthodo express |
| 2. Portrait | 6–12 | Combien, quoi, où, depuis quand, quelle taille, anchors |
| 3. Dynamiques | 13–20 | Taux de formation, cohorte post-2024, SW vs HW, financement, sorties, trajectoires |
| 4. Acteurs | 21–26 | Institutions, financement public, VC/PE, accélérateurs, universités, talent |
| 5. Benchmarks | 27–34 | Panorama 8 régions, petits champions, Corée, DE+US, Pologne, QC vs Canada, politique publique, capital |
| 6. Défis & lacunes | 35–39 | Scaling, capex, talent, supply chain, fragmentation |
| 7. Recommandations | 40–45 | Principes + 4 recos (placeholders) + roadmap |
| 8. Annexe | 46–52 | Sources, méthodo détaillée (3x), taxonomie, limites, reproductibilité, glossaire |

> **Note sur la numérotation:** les numéros ci-dessus sont **indicatifs** et seront resserrés en phase de production (`.pptx`). La renumérotation propre se fera une fois le contenu arrêté. Les titres de section sont stables.

---

# Section 1 — Cadrage

## Slide 1 — Couverture

**Contenu:** Titre du rapport, sous-titre, auteurs, logos QT / RC / CIQ (si co-signé), date de publication, version, mention "confidentiel — pré-publication" pendant la review.

**Titre de travail:** *Hardware et Deep Tech au Québec — État des lieux, dynamiques, et leviers pour la prochaine décennie*

**Status:** Placeholder — à finaliser avec direction QT.

---

## Slide 2 — Ce qu'il faut retenir (TL;DR grand public)

**Contenu:** 5 messages en phrases simples, ton accessible pour lecteur non-expert. Draft :

1. **Le Québec compte environ [X] compagnies deep-tech** — des entreprises qui fabriquent des technologies avancées (lasers, puces, robots, dispositifs médicaux, équipement spatial). C'est un bassin discret mais réel, ancré par des noms comme l'INO, EXFO, MDA, Kinova, Nord Quantique.

2. **Un réveil depuis 2024, mais modeste.** Environ 18 nouvelles compagnies par trimestre en 2025–début 2026, contre 12 avant la COVID. Un plus, mais les volumes absolus restent petits et la photonique traditionnelle n'a pas décollé — ce sont le quantique et le matériel adjacent qui bougent.

3. **Le vent GenAI n'a pas porté le matériel.** Depuis 2022, la création de compagnies logicielles-IA a doublé au Québec pendant que la création hardware restait plate. Les deux mondes suivent des trajectoires opposées.

4. **Le vrai problème n'est pas de créer, c'est de faire grandir.** Les compagnies naissent, peu atteignent 50+ employés ou 10M$ de revenus. Le capital patient manque, la demande domestique est diffuse, les opérateurs expérimentés sont rares.

5. **[Recommandation phare à formuler après analyse]** — des leviers existent : instruments de capital dédiés, programmes de procurement stratégique, immigration accélérée pour opérateurs, renforcement des anchors institutionnels.

**Source material:** Synthèse post-analyse. Seule slide qu'on finalise à la toute fin.

**Status:** Squelette pour cadrage; à réécrire après section 7. Ton délibérément grand-public : chaque message doit être compréhensible par un lecteur non-technique.

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

## Slide 4 — Deep tech, hard tech : de quoi parle-t-on ?

**Question analytique:** Qu'est-ce que ce rapport appelle "deep tech" et "hard tech" ? Comment distingue-t-on ces compagnies des autres start-ups technologiques ?

**Contenu (accessible grand public):**

Deux définitions à ancrer :

- **Deep tech** = entreprise bâtie sur une **avancée scientifique ou d'ingénierie substantielle** (souvent issue d'un laboratoire universitaire ou industriel). Cycles de R-D longs, forte intensité de capital, barrières à l'entrée défensives.
- **Hard tech** = sous-ensemble du deep tech avec un **produit physique au cœur** : hardware, dispositif, matériau, équipement. Exclut le deep tech purement logiciel.

**Ce rapport couvre le deep tech large** (hard tech + deep tech à composante matérielle forte), organisé en **9 piliers** détaillés slide 4bis.

**Ce qui est exclu:** pure SaaS, IA appliquée sans hardware, fintech, consommation, médias, consulting tech.

**Renvoi:** "Définitions détaillées par pilier en annexe, slide 45. Document complet : `analysis/taxonomy-and-definitions.md`."

**Visuel (placeholder):** un grand schéma en cercles concentriques (deep tech large → hard tech → 9 piliers dedans) avec, à côté, une liste courte "INCLUS / EXCLU" et 3 exemples publics québécois par colonne.

**Status:** Définitions arrêtées en v0.1; prêtes à visualiser.

---

## Slide 4bis — Les 9 piliers du deep tech québécois

**Question analytique:** Comment le deep tech québécois se décompose-t-il concrètement ?

**Contenu (grand public):**

Table en une slide, 9 lignes. Pour chaque pilier :

| Pilier | En une phrase | Un exemple public québécois |
|--------|---------------|------------------------------|
| Photonique et optique | Technologies de la lumière (fibre, laser, imagerie) | EXFO (instrumentation fibre) |
| Quantique | Ordinateurs, capteurs et communications fondés sur la physique quantique | Nord Quantique (Sherbrooke) |
| Semi-conducteurs | Conception et test de puces électroniques | IBM Bromont (ancre industrielle) |
| Robotique et systèmes autonomes | Robots, drones, véhicules autonomes | Kinova (bras robotiques) |
| Technologies spatiales | Satellites, propulsion, télédétection | MDA (robotique spatiale) |
| Matériaux avancés | Nanomatériaux, composites, alliages spéciaux | NanoXplore (graphène) |
| MedTech et biotech-hardware | Dispositifs médicaux, diagnostics, bioprocessing | Medtronic (site QC), Imagia |
| Cleantech hardware | Batteries, VE, captation carbone physique | Lion Electric (camions électriques) |
| Agri-tech avec hardware | Capteurs agricoles, drones, équipement précision | Semios (pièges intelligents) |

**Renvoi:** "Définitions opérationnelles et mots-clés en `analysis/taxonomy-and-definitions.md`."

**Visuel (placeholder):** grille 3×3 de 9 tuiles, chacune avec une icône représentative, le nom du pilier, 1 phrase-définition, et le logo/nom d'une compagnie publique.

**Takeaway attendu:** Le lecteur comprend en 30 secondes la diversité des piliers et peut associer chaque pilier à un nom concret — démystifie la notion de "deep tech" abstraite.

**Status:** Contenu prêt (du document taxonomie); viz à construire.

---

## Slide 5 — Comment on a fait (méthodologie en 30 secondes)

**Question analytique:** Comment les chiffres ont-ils été obtenus ? Quelle confiance peut-on y accorder ?

**Contenu (grand public, 4 lignes simples):**

1. **On part du registre des entreprises du Québec (REQ)** — toutes les compagnies incorporées, avec leur description d'activité et code économique.
2. **On classe en deep tech avec deux filets:** des mots-clés précis sur la description (haute confiance) + des codes économiques (confiance plus large). On accepte un peu de bruit pour ne pas manquer les compagnies qui n'ont pas rempli leur description.
3. **On croise avec Dealroom (Quebec Tech) et PitchBook (Réseau Capital)** pour rattraper les compagnies incorporées au fédéral et compléter les données de financement.
4. **Trois niveaux de confiance:** HAUTE (mots-clés validés + codes cohérents), MOYENNE (un des deux signaux), BASSE (code économique seul — on cite mais on flagge).

**Caveats-pédagogie:**
- Les compagnies **incorporées au fédéral** (CBCA) n'apparaissent pas dans le REQ — angle mort à combler via Dealroom et PitchBook.
- Environ **73 % des classifications historiques** dans nos analyses photonique/matériel reposaient sur le code économique seul — d'où l'importance d'annoncer les plages de confiance.

**Renvoi:** "Méthodologie détaillée en annexe, slides 44–47. Décomposition complète des piliers et signaux : `analysis/taxonomy-and-definitions.md`."

**Visuel (placeholder):** infographie horizontale en 4 étapes (REQ → classification hybride → croisement sources → fiabilité tiers) avec icônes.

**Status:** Texte prêt; viz à construire. Dépendance critique : accord formel avec RC pour données PitchBook — à obtenir dans les 2 premières semaines, sinon version dégradée.

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

# Section 5 — Benchmarks (8 régions, par archétypes)

> **Cadrage:** 8 régions de comparaison choisies pour leur diversité d'archétypes.
>
> | Archétype | Régions | Enseignement attendu |
> |-----------|---------|----------------------|
> | Petits champions deep-tech | Suède (SE), Israël (IL), Singapour (SG) | Ce qu'une petite économie peut accomplir avec focus |
> | Politique industrielle ciblée | Corée du Sud (KR) | Coordination état-industrie sur semi/matériaux |
> | Grandes économies anchors | Allemagne (DE), États-Unis (US) | CHIPS Act, Mittelstand, référentiels de politique |
> | Émergent / transitionnel | Pologne (PL) | Trajectoire de rattrapage post-intégration EU |
> | Domestique | Reste du Canada (ON + autres) | Baseline provincial-fédéral |
>
> Comparaisons normalisées par habitant quand pertinent. Comparaisons absolues quand l'échelle industrielle importe (semi-conducteurs, spatial).

---

## Slide 27 — Panorama des 8 benchmarks en une page

**Question analytique:** Comment le Québec se positionne-t-il globalement face à ces 8 régions ?

**Données / sources:**
- GSER 2024–2025 (`insights/reports-external/gser-2025.md`)
- StartupBlink Global 2025 (`insights/reports-external/startupblink-2025.md`)
- OCDE statistiques R-D et innovation
- Rapports nationaux : Vinnova (SE), Israel Innovation Authority (IL), A*STAR (SG), KISTEP (KR), BMWK (DE), NSF (US), Narodowe Centrum Badań (PL)
- ISED + StatCan pour le Canada

**Visuel (placeholder):** grand tableau/heatmap 8 régions + QC × 6 indicateurs-clés — PIB/habitant, R-D privée % PIB, compagnies deep-tech/million d'habitants, capital deep-tech levé par habitant, universités top-200 (ARWU), index politique industrielle (qualitatif).

**Takeaway attendu:** Le Québec a les **ressources institutionnelles** (universités, anchors) de rivaliser avec les petits champions, mais le **volume de formation et le capital** restent sous le seuil critique. Position structurellement intermédiaire.

**Caveats:**
- Comparabilité limitée par différences définitionnelles (qu'est-ce que "deep tech" selon chaque source).
- Certaines données nationales ont un recul de 1–2 ans.

**Status:** Collecte documentaire à lancer; architecture du tableau à finaliser.

---

## Slide 28 — Les petits champions deep-tech : Suède, Israël, Singapour

**Question analytique:** Que font ces trois petites économies que le Québec n'a pas encore fait, et qu'est-ce qu'elles ont en commun ?

**Données / sources:**
- **Suède:** Vinnova reports, RISE, SEK Deep Tech Fund, Chalmers Ventures — ancrage industriel (Ericsson, AstraZeneca) + spinoffs universitaires, capital de croissance public.
- **Israël:** Israel Innovation Authority, Technion spinoffs, Yozma model legacy, militarisation-to-civilian pipeline (8200, Rafael) — conversion recherche militaire → civil, corporate VC actifs.
- **Singapour:** A*STAR, NRF, SGInnovate, Temasek — délibération étatique top-down, ciblage sous-sectoriel explicite (semi, biotech).

**Visuel (placeholder):** trois colonnes parallèles — un "portrait" par pays (compagnies deep-tech, capital, instruments publics-phares, leçon tirée). En bas, ligne commune : "Ce que les 3 partagent."

**Takeaway attendu:** Les trois réussissent par **combinaison de 3 ingrédients** — (1) anchors industriels forts, (2) capital public de croissance (pas seulement seed), (3) demande domestique captive (défense, santé publique, fonds souverain). Le Québec a le premier, les autres restent à construire.

**Caveats:**
- Contextes politiques et sécuritaires très différents (Israël surtout) — pas tout est transposable.

**Status:** Recherche documentaire à faire; angle "3 ingrédients communs" à tester avec analyse.

---

## Slide 29 — Politique industrielle ciblée : Corée du Sud

**Question analytique:** Comment la Corée a-t-elle réussi à devenir une puissance semi/matériaux en une génération, et qu'est-ce qui est transposable à l'échelle québécoise ?

**Données / sources:**
- KISTEP, K-Chips Act (2023), Samsung/SK Hynix public disclosures, KDB reports
- Littérature sur le modèle des "chaebols" et l'évolution vers deep tech

**Visuel (placeholder):** timeline 1980–2025 des dépenses R-D publiques coréennes + événements-clés; encart "chiffres-clés" comparés au Canada.

**Takeaway attendu:** Le modèle coréen repose sur **coordination top-down massive + champions nationaux + éducation technique ciblée**. Transposable au Québec à échelle réduite : ciblage sous-sectoriel (quantique, photonique), partenariats publics-privés structurants, financement long-horizon dédié.

**Caveats:**
- Échelle et contexte culturel très différents.
- La composante "champion national" est controversée démocratiquement.

**Status:** Recherche documentaire à faire.

---

## Slide 30 — Grandes économies : Allemagne et États-Unis

**Question analytique:** Que retenir des deux plus gros modèles de politique deep-tech (US CHIPS Act, DE Mittelstand + SprunD/DTEC), et qu'est-ce qui survit à l'adaptation pour le QC ?

**Données / sources:**
- **US:** White House CHIPS implementation reports (2022–), NSF, NIST, état d'avancement des fabs annoncées, Inflation Reduction Act cleantech components.
- **DE:** BMWK programmes, SPRIND (Bundesagentur für Sprunginnovationen), DTEC.Bw, Mittelstand deep-tech (Carl Zeiss, Trumpf).

**Visuel (placeholder):** deux colonnes — US (approche "big bet subventions") et DE (approche "dense réseau mittelstand"). Tableau comparatif et, en bas, "Ce que le Québec peut importer à sa propre échelle."

**Takeaway attendu:** **Ni le modèle US (52B$ CHIPS) ni le Mittelstand allemand ne se reproduisent à l'identique**, mais deux leçons s'appliquent : (1) ciblage explicite d'infrastructures manquantes (US: fab domestique), (2) financement institutionnel de long-terme du réseau existant (DE: Fraunhofer). Le Québec peut faire les deux à échelle réduite — CRIQ et INO sont les Fraunhofer canadiens potentiels.

**Caveats:**
- US CHIPS Act n'a que 3 ans de recul — effets économiques encore débattus.
- Le Mittelstand est le produit d'un siècle — pas reproductible rapidement, mais la logique de long-termisme l'est.

**Status:** Recherche documentaire à faire; leçons transposables à raffiner avec section 7.

---

## Slide 31 — Émergent : Pologne (cas de rattrapage)

**Question analytique:** Une économie européenne de rattrapage post-intégration EU peut-elle inspirer une trajectoire d'accélération du Québec ?

**Données / sources:**
- Narodowe Centrum Badań i Rozwoju (NCBR) reports
- Polish Development Fund (PFR) deep-tech initiatives
- Données OCDE / Eurostat R-D

**Visuel (placeholder):** ligne de trajectoire 2004–2025 (dépenses R-D, compagnies deep-tech) avec annotations des inflexions politiques; courbe parallèle QC pour comparaison.

**Takeaway attendu:** La Pologne montre qu'une **décennie de politique industrielle cohérente** (~2015–2025) peut multiplier la base deep-tech par 3–5x. Le Québec est plus mature à la base mais a un déficit d'accélération similaire. **L'horizon temporel de transformation est une décennie, pas un mandat.**

**Caveats:**
- Fonds EU structurants (non-disponibles au Canada).
- Contexte post-soviétique spécifique.

**Status:** Recherche documentaire à faire — **angle inédit dans les rapports canadiens existants**, à traiter avec soin.

---

## Slide 32 — Domestique : Québec vs reste du Canada

**Question analytique:** Quelle est la place du Québec dans le deep tech canadien, et où souffre-t-il par rapport à l'Ontario et la Colombie-Britannique ?

**Données / sources:**
- StatCan (comptes R-D industrielle par province)
- ISED KSBS (`insights/reports-external/ised-ksbs-2025.md`)
- Ontario Business Registry (équivalent REQ, accès à confirmer)
- GSER / StartupBlink rankings nationaux
- Rapports MaRS, Communitech (ON), BC Tech (CB)

**Visuel (placeholder):** carte canadienne choroplèthe + tableau comparatif QC / ON / CB / Alberta / Atlantique sur 6 indicateurs deep-tech.

**Takeaway attendu:** **Ontario plus gros en volume absolu** (population 1.8x du QC) avec cluster semi Waterloo + biotech Toronto. **QC surreprésenté en photonique, quantique, cleantech, aérospatial** par habitant. **BC forte en IA-biotech.** Le Québec a une proposition complémentaire, pas concurrente, et devrait se positionner comme **la province hardware-centric du Canada**.

**Caveats:**
- Définitions provinciales asymétriques.
- Comparaison "toutes choses égales" difficile.

**Status:** Recherche à faire; Ontario Business Registry à explorer pour équivalent-REQ.

---

## Slide 33 — CHIPS Act, Chips Act EU, Stratégie quantique CA : la pause canadienne

**Question analytique:** Quels effets observés des grandes politiques industrielles récentes, et qu'est-ce qui manque côté canadien ?

**Données / sources:**
- White House CHIPS implementation reports + Congressional Research Service
- European Commission Chips Act dashboards
- Conseil consultatif canadien sur les semi-conducteurs (rapport 2023)
- Stratégie quantique CA (2023, 360M$)

**Visuel (placeholder):** timeline programmes 2020–2026 avec montants engagés et résultats à 3 ans; colonne "Canada" visiblement plus pâle et plus courte.

**Takeaway attendu:** **Le Canada n'a pas de CHIPS Act.** Les instruments existants (PARI, SIF, Stratégie quantique) sont utiles mais sous-dimensionnés et dispersés. Le Québec a les leviers pour **agir unilatéralement** sur photonique et quantique, deux piliers où il a déjà une ancre institutionnelle qui manque aux autres provinces.

**Caveats:**
- Effets CHIPS Act n'ont que 3 ans — appréciation préliminaire.

**Status:** Recherche documentaire à faire.

---

## Slide 34 — Capital par stade : QC vs pairs

**Question analytique:** À quels stades de financement le Québec souffre-t-il le plus en deep-tech vs pairs directement comparables ?

**Données / sources:**
- PitchBook / CVCA via RC — agrégats par stade (critique, bloquant)
- Stratification Seed / Série A / Série B / Growth pour deep-tech QC vs ON, US moyen, IL, SE

**Visuel (placeholder):** 4 barres par région (Seed, A, B, Growth) — QC vs 3-4 régions comparables. Une seule vue synthétique.

**Takeaway attendu:** **Seed correct, Série A correct, Séries B et Growth critiquement manquants** pour deep-tech au QC. Le goulot typique canadien, amplifié pour deep-tech vu l'intensité capitalistique. Le capital de croissance devient le levier-clé des recommandations.

**Caveats:**
- Stages Dealroom vs PitchBook peuvent différer — normaliser via `taxonomy/stages.yaml`.
- Source licenciée → agrégats seulement, pas de deals nommés.

**Status:** **Bloquant sur accord RC.**

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

## Slide 44 — Méthodologie détaillée (1/3) — Classification hybride

**Contenu:** Description de la classification hybride keywords + CAE au niveau opérationnel :

- **Signal 1 (haute confiance):** 40+ patterns keywords sur `DESC_LOWER` et `DESC_ALL` (SECTEUR_ACTIVITE_PRINCIPAL + SECONDAIRE). Mots-clés par pilier détaillés dans `analysis/taxonomy-and-definitions.md`.
- **Signal 2 (confiance variable):** codes CAE du REGISTRE_ADRESSES — boost pour codes ciblés (2851, 3361, 3674, 3827, 3740, etc.), pénalité pour services.
- **Filtre service:** regex d'exclusion pour "consulting", "services informatiques", "intégration", "maintenance" — 3,757 faux positifs historiques écartés.
- **Score produit agrégé → tier:** HIGH / MEDIUM / LOW / EXCLUDED_SERVICE / NONE selon combinaison des signaux.

Renvoi technique : `pipelines/transforms/silver/31_req_product_classification.sql`.
Renvoi lisible : `analysis/taxonomy-and-definitions.md` sections 2 et 4.

**Status:** Référentiel prêt. Besoin d'un visuel pédagogique "voyage d'une compagnie dans le classifier" pour grand public.

---

## Slide 45 — Méthodologie détaillée (2/3) — Définitions par pilier

**Contenu:** Table de synthèse — pour chacun des 9 piliers, définition d'une phrase, 2-3 mots-clés principaux, codes CAE dominants, 2 exemples publics, caveats-clés. Sert de "carte de route" pour le lecteur qui veut comprendre comment une compagnie-type est classifiée.

Renvoi complet : `analysis/taxonomy-and-definitions.md` section 2.

**Visuel (placeholder):** table dense 9 lignes × 5 colonnes; tu peux zoomer au lieu de feuilleter. Design clair avec codes CAE en petit.

**Status:** Contenu prêt dans le document taxonomie. Viz à construire.

---

## Slide 46 — Méthodologie détaillée (3/3) — Matching entre sources et gouvernance

**Contenu:** Deux parties brèves sur une slide :

**A. Matching cross-sources:** comment REQ, Dealroom et PitchBook sont unifiés — bridge NEQ quand disponible, fuzzy name matching ≥ 0.85, manual review whitelist pour near-misses. Taux de match observés (~X %, à confirmer après rafraîchissement).
Renvoi : `pipelines/transforms/entity_resolution/`.

**B. Gouvernance des données:** rappel des règles — agrégats seulement pour sources licenciées (Dealroom, PitchBook), seuil minimum 5 enregistrements par groupe, aucun nom de compagnie attribuable à une source licenciée, sources publiques (REQ, annonces médias, sites web) citables nominativement.
Renvoi : `DATA-GOVERNANCE.md`.

**Status:** Référentiel prêt. Section pédagogique à articuler.

---

## Slide 47 — Taxonomie employée (vue synthétique)

**Contenu:** Résumé visuel de la taxonomie ecosystem-wide (`taxonomy/sectors.yaml`) et des critères "startup" (`taxonomy/startup-criteria.yaml`). Met en évidence **quels codes** (AI exclu, DEEPTECH inclus, parties de HEALTHTECH et CLEANTECH incluses, AGRITECH partiellement inclus) **composent le périmètre de ce rapport**.

**Visuel (placeholder):** arbre taxonomique 2 niveaux (parent → enfants) avec codes colorés "inclus dans ce rapport / partiellement inclus / exclu".

**Status:** Données prêtes (YAML). Viz à construire.

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

# Cadrage arrêté — résumé des décisions (2026-04-17)

| Question | Décision |
|----------|----------|
| Scope | **DEEPTECH large**, 9 piliers — photonique, quantique, semi, robotique, spatial, matériaux avancés, medtech/biotech-hw, cleantech-hw, agri-tech-hw. Voir `analysis/taxonomy-and-definitions.md`. |
| Audience primaire | **Grand public.** Ton accessible, exemples concrets de compagnies publiques, visuel-dominant, jargon minimum. |
| Co-signature | **Quebec Tech + Réseau Capital** confirmés. **CIQ** en discussion. |
| Benchmarks | **8 régions** par archétypes : Suède, Israël, Singapour (petits champions); Corée (politique industrielle); Allemagne, États-Unis (grandes économies); Pologne (émergent); Reste du Canada (domestique). |
| Recommandations | **Placeholders** dans le deck; formulation finale émergera de l'analyse (sections 2–6). |
| Date cible | **Mi-juillet 2026.** Ambitieux compte tenu du scope — priorise le déblocage RC. |
| Définitions | Document dédié `analysis/taxonomy-and-definitions.md` — bâti sur `taxonomy/sectors.yaml` + stage 31 classifier + messages existants. |

---

# Prochains jalons immédiats

**Les points critiques à débloquer dans les 2 prochaines semaines:**

1. **Demande formelle à Réseau Capital** pour l'accès PitchBook/CVCA (agrégats). Slides 18, 23, 34 dépendent de cet accord. Sans celui-ci, version dégradée basée sur annonces publiques seulement.
2. **Invitation formelle au CIQ** pour co-signature et définition de l'apport (Baromètre, métriques politiques). Besoin de réponse avant publication publique du draft.
3. **Sollicitations aux anchors institutionnels** (INO, MEDTEQ+, Écotech Québec, IREQ) pour listes de membres et validation nominative. Idéalement réponses pour fin avril.
4. **Validation interne QT** du scope 9 piliers et du `analysis/taxonomy-and-definitions.md` — confirmer qu'on ne manque pas un pilier (ex. fusion/SMR) ou qu'on n'en inclut pas un qui n'a pas assez de masse critique.
5. **Production de la cohorte post-2024** via Q5 diagnostic dans Snowsight — alimente slides 16 et partiellement 4bis.

# Jalons phase par phase

- **Semaines 1–2 (fin avril):** déblocage partenariats, validation taxonomie, planification viz/design.
- **Semaines 3–6 (mai):** analyses principales (sections 2–4), cohorte post-2024, trajectoires par pilier.
- **Semaines 5–9 (fin mai–début juin):** benchmarks 8 régions — recherche documentaire, synthèse par archétype.
- **Semaines 7–10 (juin):** draft v1 narratif, visualisations, section 6 défis, premières hypothèses recommandations.
- **Semaines 10–11 (mi-juin):** review interne QT + RC + (CIQ si in), itérations.
- **Semaines 11–12 (début juillet):** finalisation, traduction FR/EN, production PDF + PPTX, validation légale/gouvernance.
- **Semaine 12 (mi-juillet):** **publication**.

# Questions ouvertes restantes

Les 7 questions originales ont été tranchées. Ce qui reste ouvert :

1. **CIQ co-signataire ou non ?** Impact sur le ton (plus policy-oriented si in) et sur la légitimité des recommandations de politique publique. Décision avant fin avril.
2. **Nommage des recommandations ?** 4 placeholders dans le deck. Leur formulation dépend du résultat des analyses — à trancher au mois de juin lors du draft v1.
3. **Design / identité visuelle ?** Avec la co-signature QT+RC, qui pilote le design final ? Budget visualisation externe ou interne ?
4. **Traduction EN:** bilingue à la publication ou FR d'abord, EN 2–4 semaines plus tard ? Décision avant fin juin.

Dis-moi quand tu veux :
- Que je produise une version **`.pptx`** (squelette navigable) à partir de ce Day Zero
- Que je rédige la **demande formelle à Réseau Capital** pour l'accès aux données
- Que je lance les **analyses manquantes** (Q5 à rouler, slides 7, 10, 13, 15, 20, 27)
- Qu'on valide ensemble le **document taxonomie** avant figement
