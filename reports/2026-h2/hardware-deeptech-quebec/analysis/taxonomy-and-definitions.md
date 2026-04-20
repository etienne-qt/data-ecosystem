# Taxonomie et définitions — Hardware & Deep Tech au Québec

**Document de référence pour le rapport.**
**Version:** v0.1 (2026-04-17)
**Audience:** équipe de production du rapport (QT + RC + CIQ). Un condensé grand public en sera extrait pour l'annexe du deck.

Ce document décompose explicitement ce que nous appelons **deep tech** et **hard tech** dans le périmètre du rapport, en bâtissant sur :

- `taxonomy/sectors.yaml` — la taxonomie canonique partagée du repo
- `pipelines/transforms/silver/31_req_product_classification.sql` — la classification hybride keywords + CAE opérationnelle
- `insights/internal/hardware-photonics-req-2026.md` — l'analyse interne existante (mars 2026)
- Les messages validés dans `data/messages/hard-tech.md` (local) — MSG-HARDTECH-01 à 05

L'objectif : que chaque chiffre cité dans le rapport puisse être rattaché à une définition opérationnelle sans ambiguïté, et que le lecteur grand public comprenne les frontières entre sous-secteurs.

---

## 1. Deep tech vs hard tech — la distinction structurante

**Deep tech** (concept large) : entreprise dont le produit ou le service repose sur une **avancée scientifique ou d'ingénierie substantielle**, généralement issue de la recherche universitaire ou de laboratoires industriels, avec des cycles R-D longs (3–10 ans), une intensité capitalistique élevée, et des barrières à l'entrée défensives.

**Hard tech** (sous-ensemble) : deep tech dont le cœur de la proposition de valeur est un **produit physique** — hardware, dispositif, matériau, équipement. Exclut les compagnies deep tech purement logicielles (ex. algorithmie quantique en mode service, modèles d'IA avancés).

Dans ce rapport, le **périmètre principal est le deep tech large** (hard tech + deep tech logiciel à composante matérielle forte, comme la conception de puces sans fabrication). Nous distinguerons "hard tech pur" quand la donnée le permet.

### Ce qui est INCLUS

| Pilier | Description courte | Exclut |
|--------|--------------------|--------|
| Photonique et optique | Technologies de la lumière | Éclairage LED grand public |
| Quantique | Calcul, communications et capteurs quantiques | Cryptographie classique |
| Semi-conducteurs | Conception, fabrication, test de puces | Distribution d'électronique |
| Robotique et systèmes autonomes | Robots, drones, véhicules autonomes | Automatisation logicielle pure (RPA) |
| Technologies spatiales | Satellites, propulsion, télédétection | Astronomie amateur |
| Matériaux avancés | Nanomatériaux, composites, 2D | Matériaux de construction standards |
| MedTech et biotech-hardware | Dispositifs médicaux, diagnostics, bioprocessing | Services cliniques, pharma sans dispositif |
| Cleantech hardware | Batteries, stockage, VE, captation physique | Compensation carbone financière |
| Agri-tech avec hardware | Capteurs agricoles, drones, équipement précision | Plateformes d'e-commerce agricole |

### Ce qui est EXCLU

- SaaS et plateformes logicielles sans composante matérielle
- IA/ML appliquée **sans** hardware spécialisé (classée `AI` dans la taxonomie)
- Fintech, consommation, médias, contenu
- Consulting technologique
- Services d'installation, maintenance, intégration
- Entreprises utilisant la tech sans la produire (ex. Agence marketing "AI-powered")

---

## 2. Les neuf piliers du deep tech québécois

Chaque pilier ci-dessous se décompose en : **définition opérationnelle**, **signaux clés** (mots-clés + codes CAE utilisés dans la classification), **exemples publics québécois**, **ancres institutionnelles**.

### 2.1 Photonique et optique

**Définition:** Entreprises dont le produit central exploite ou manipule la lumière pour des applications industrielles, médicales, télécoms ou de mesure. Inclut fibre optique, lasers, optoélectronique, imagerie thermique/infrarouge, systèmes de détection optique.

**Signaux de classification:**
- Mots-clés: `photoniq`, `fibre optique`, `laser`, `optoélectronique`, `thermal imaging`, `infrared imaging`
- Codes CAE primaires: **3827** (instruments optiques et de précision)
- Codes CAE adjacents: 3674 (semi-conducteurs intégrant optoélectronique), 3699 (fabrication diverse — bruit)

**Exemples publics québécois:**
- INO — institut public d'optique-photonique, Québec
- EXFO — instrumentation télécoms fibre optique
- Coherent (ex-II-VI / MPB Communications) — amplification optique, acquis par II-VI en 2021
- LeddarTech — LiDAR automobile
- Optel Group — traçabilité par imagerie

**Ancres institutionnelles:** INO (Québec), Centre d'optique, photonique et laser (COPL) à l'Université Laval, chaires de recherche McGill et Polytechnique.

**Caveats classification:**
- **CAE 3827 inclut aussi beaucoup de services d'installation fibre optique** — ~50 de ces 3,757 faux positifs identifiés dans l'analyse existante (`INTERNAL-hardware-photonics-req-2026`). Filtre d'exclusion "service" (regex dans stage 31) essentiel.
- Cabines de bronzage, cliniques d'épilation laser, services de gravure laser → pollution classique du signal "laser".

---

### 2.2 Quantique

**Définition:** Entreprises dont le produit central exploite les phénomènes quantiques (superposition, intrication) pour le calcul, la communication ou la mesure. Inclut calcul quantique (hardware et software de contrôle), communications quantiques, capteurs quantiques, cryptographie post-quantique ayant une ancre hardware.

**Signaux de classification:**
- Mots-clés: `quantum computing`, `quantique`, `qubits`, `quantum communications`, `quantum sensing`
- Patterns composés : `quantiq[a-z]+.{0,20}(ordinateur|comput|informatique)` (pour éviter "bien-être quantique" etc.)
- Codes CAE: 3674 (si fab locale), 3827 (capteurs quantiques ont souvent cette classification)

**Exemples publics québécois:**
- Nord Quantique — calcul quantique basé à Sherbrooke
- PINQ² (IBM Bromont) — plateforme d'innovation et de nœud quantique, partenariat public-privé
- Anyon Systems — matériel quantique, Dorval
- Photonic Inc — basée en CB mais labs et équipe au QC
- Multiver — communications quantiques

**Ancres institutionnelles:** Institut quantique (IQ) Université de Sherbrooke, PINQ², CIFAR quantique, IBM Bromont.

**Caveats classification:**
- **Pilier émergent, petits volumes** — même les signaux haute-confiance peuvent ne représenter que 3–8 compagnies totales. Statistique peu significative mais cas nominatifs importants.
- Certaines compagnies "quantum" font en réalité du classique avancé — validation manuelle cruciale avant citation.
- "Mots-clés marketing" (ex. "quantum-inspired" en ML) à exclure.

---

### 2.3 Semi-conducteurs

**Définition:** Entreprises dont le produit central est la conception, la fabrication, l'emballage ou le test de composants semi-conducteurs (puces, circuits intégrés, modules de puissance). Au Québec, majoritairement du design (fabless) et du test plutôt que de la fabrication de volume.

**Signaux de classification:**
- Mots-clés: `semi-conducteur`, `semiconductor`, `puce électronique`, `circuit intégré`, `chip design`, `IC design`
- Codes CAE primaires: **3674** (semi-conducteurs)
- Adjacents: 3827 (capteurs sur puce), 3359 (équipement fabrication)

**Exemples publics québécois:**
- CMC Microsystems — consortium de partage d'outils de conception (à but non lucratif, mais écosystème anchor)
- IBM Bromont — packaging et test hérités, part de l'ancre
- Reinvent — conception microélectronique (Montréal)
- Teledyne Dalsa — capteurs CMOS, Waterloo mais ancrages QC
- AOMS Technologies — capteurs intégrés

**Ancres institutionnelles:** CMC Microsystems, IBM Bromont, chaires McGill (Integrated Electronics), Polytechnique Montréal.

**Caveats classification:**
- **Dépendance critique à la fabrication étrangère** — très peu de foundries au Canada. La "chaîne de valeur" locale s'arrête souvent au design.
- Beaucoup de compagnies québécoises de design comptent 5–15 employés — difficiles à détecter en REQ si description vague.
- CAE 3674 capture aussi beaucoup de distributeurs d'électronique (non-startups).

---

### 2.4 Robotique et systèmes autonomes

**Définition:** Entreprises dont le produit central est un robot (industriel, collaboratif, chirurgical, domestique), un drone, un véhicule autonome, ou un composant-clé de ces systèmes. Inclut logiciel de contrôle et perception **si vendu avec du hardware**.

**Signaux de classification:**
- Mots-clés: `robotiq`, `drone`, `véhicule autonome`, `autonomous vehicle`, `collaborative robot`, `cobot`
- Patterns: `robot.{0,20}(industriel|collaborat|autonom|mobile|chirurg)`
- Codes CAE: 3361 (véhicules et carrosseries spécialisées), 3740 (instrumentation), 3359 (équipement industriel)

**Exemples publics québécois:**
- Kinova — bras robotiques, Boisbriand
- OMNIRobotic — robotique industrielle
- Exonetik — actuateurs magnétorhéologiques
- Flyscan — drones d'inspection
- Dynautics — véhicules autonomes maritimes
- Element AI (ex, acquis ServiceNow 2020) — perception pour robotique autonome

**Ancres institutionnelles:** Institut de recherche Hydro-Québec (IREQ), REPARTI (Laval), Centech, Polytechnique Robotics Lab.

**Caveats classification:**
- Chevauchement fort avec **logiciel "automation"** qui n'est PAS hard tech. Le filtre s'appuie sur la présence conjointe de "robot" et d'un marqueur hardware-spécifique.
- Compagnies "AI + drones" tombent entre deux chaises — décider au cas par cas selon proposition de valeur principale.

---

### 2.5 Technologies spatiales

**Définition:** Entreprises concevant, fabriquant ou opérant des systèmes spatiaux : satellites, propulsion, instruments de télédétection, services d'imagerie satellitaire, plateformes au sol liées.

**Signaux de classification:**
- Mots-clés: `aérospatial`, `spatial`, `satellite`, `télédétection`, `geospatial`, `remote sensing`
- Codes CAE primaires: **3740, 3741** (aérospatiale et précision)

**Exemples publics québécois:**
- MDA — robotique spatiale, ex-filiale Maxar, siège BC mais importantes opérations QC
- GHGSat — détection des gaz à effet de serre par satellite
- NorthStar Earth & Space — situational awareness spatiale
- MacDonald, Dettwiler and Associates (via MDA) — héritage
- C-COM — antennes satcom

**Ancres institutionnelles:** Agence spatiale canadienne (Saint-Hubert), Aerospace Industries Association of Canada, clusters aérospatiaux MTL.

**Caveats classification:**
- **Confusion fréquente avec aéronautique traditionnelle** (CAE, Bombardier, Bell). Nous distinguons aérospatial = spatial civil/commercial du pur aéronautique.
- Beaucoup d'entreprises spatiales sont incorporées fédéralement (CBCA) — sous-détectées en REQ.

---

### 2.6 Matériaux avancés

**Définition:** Entreprises dont le produit central est un matériau nouveau ou radicalement amélioré : nanomatériaux (graphène, nanotubes), composites hautes performances, matériaux 2D, alliages spéciaux, polymères fonctionnels. Exclut matériaux de construction standards.

**Signaux de classification:**
- Mots-clés: `nanotechnolog`, `nanomatériaux`, `graphène`, `composites avancés`, `2D materials`
- Codes CAE: 2851 (produits chimiques industriels), 3910 (fabrication diverse — haute variance)

**Exemples publics québécois:**
- NanoXplore — graphène, Boisbriand
- Nemaska Lithium — hydroxyde de lithium (en restructuration)
- ArcelorMittal — alliages (anchor industriel, pas startup)
- Polytech — fibres techniques
- Pyrogenesis — plasma pour poudres métalliques

**Ancres institutionnelles:** Centre de recherche industrielle du Québec (CRIQ), Institut national de la recherche scientifique — Énergie, Matériaux et Télécommunications.

**Caveats classification:**
- **CAE 2851 et 3910 sont très larges** — beaucoup de "fabrication de produits chimiques" qui n'a rien d'avancé. 80 %+ de bruit estimé sur ces codes seuls. Besoin de mots-clés pour valider.
- Pilier le plus difficile à chiffrer rigoureusement.

---

### 2.7 MedTech et biotech-hardware

**Définition:** Entreprises dont le produit est un dispositif médical (matériel + logiciel embarqué), un outil de diagnostic in vitro, un équipement de bioprocessing, ou une plateforme biotech avec composante hardware substantielle. Exclut pharma pure (molécules), services cliniques.

**Signaux de classification:**
- Mots-clés: `dispositif médical`, `medical device`, `medtech`, `digital health` + hardware, `diagnostics`, `in vitro`, `bioprocessing`
- Codes CAE: mixte, souvent 3827 (dispositifs médicaux-optiques), 3674 (électronique médicale)

**Exemples publics québécois:**
- Imagia — imagerie médicale + IA
- Optina Diagnostics — diagnostic oculaire
- Bioxcel — fabrication biopharma
- Medtronic (site QC) — ancre industrielle
- AxoSim — organoïdes de nerfs pour tests médicaux

**Ancres institutionnelles:** MEDTEQ+ (consortium sectoriel), CHU Sainte-Justine, IRCM, CHUM, Mila (santé).

**Caveats classification:**
- **Frontière floue avec biotech pure** (molécules) — inclure seulement si composante hardware validée.
- "Digital health" sans hardware (télémédecine pure, plateformes RDV) → **exclu**.
- MEDTEQ+ list potentiellement décisive pour validation.

---

### 2.8 Cleantech hardware

**Définition:** Entreprises dont le produit est un équipement ou système physique adressant un défi environnemental : batteries, stockage d'énergie, véhicules électriques, captation de carbone physique, bornes de recharge, systèmes photovoltaïques avancés. Exclut services conseil, compensation carbone financière, plateformes logicielles vertes.

**Signaux de classification:**
- Mots-clés: `cleantech`, `véhicule électrique`, `batterie`, `stockage d'énergie`, `cleantech propre`, `captation carbone` + hardware
- Codes CAE: 3350-3352 (équipement électrique), 3910 (diverse), 3361 (VE)

**Exemples publics québécois:**
- Lion Electric — autobus et camions électriques
- AddÉnergie — bornes de recharge
- Cycle Capital (fonds, pas startup mais anchor)
- Pyrogenesis — procédés plasma
- Enerkem — production d'éthanol cellulosique
- Recyclage Lithion — recyclage batteries

**Ancres institutionnelles:** Écotech Québec (cluster), Fonds de développement économique régional, Hydro-Québec IREQ.

**Caveats classification:**
- Chevauchement avec automobile traditionnelle (CAE 3361) — distinguer "VE et mobilité électrique" de "pièces automobiles génériques".
- Greenwashing sémantique : nombreuses compagnies marketent "cleantech" sans hardware. Filtrer sur présence de hardware.

---

### 2.9 Agri-tech avec hardware

**Définition:** Entreprises dont le produit est un équipement ou système physique pour l'agriculture : capteurs de champ, drones agricoles, équipement de précision, systèmes d'irrigation intelligents, bioréacteurs. Exclut plateformes e-commerce agricoles, SaaS de gestion d'exploitation pure.

**Signaux de classification:**
- Mots-clés: `agritech`, `agrotech`, `agriculture de précision` + hardware
- Codes CAE: 3352 (équipement agricole), 3827 (capteurs)

**Exemples publics québécois:**
- Ecofixe — systèmes de filtration pour aquaculture
- Semios — pièges intelligents
- Nanuk Technologies — drones agricoles
- GEM Systems (ex) — instrumentation géophysique adjacente
- Productivité BioLM — bio-procédés agricoles

**Caveats classification:**
- **Pilier très petit en volume au QC** — peut-être groupé avec "matériaux avancés" ou "cleantech" selon les résultats de l'analyse.
- Distinguer ag-hardware du ag-SaaS (ce dernier étant exclu).

---

## 3. Distinctions de catégorie importantes pour le rapport

### "Hard tech pur" vs "Deep tech avec composante logicielle dominante"

Quand les données le permettent, nous distinguerons :

- **Hard tech pur:** ≥50 % de la proposition de valeur dans le hardware physique. Exemples: Lion Electric (batteries + véhicule), LeddarTech (capteurs LiDAR).
- **Deep tech mixte:** hardware + logiciel à parts comparables. Exemples: Kinova (robotique = mécanique + contrôle), Imagia (imagerie + IA).
- **Deep tech logiciel:** logiciel-dominant mais exige expertise scientifique profonde. Exemples: conception de puces fabless sans fab, algorithmes quantiques en SaaS.

Le rapport se concentre sur les deux premières catégories, avec mention explicite quand une compagnie "glisse" vers logiciel.

### Startup vs entreprise établie

Nous appliquons `taxonomy/startup-criteria.yaml` :

- **Startup:** ≤15 ans, indépendante, orientée croissance, techno-centrée.
- **Entreprise établie (anchor):** >15 ans OU acquise/absorbée OU filiale d'un groupe.

Les anchors ne comptent PAS dans nos statistiques de formation. Ils apparaissent dans la section "phares établis" du rapport (slide 12) pour documenter la "gravité" de l'écosystème.

### Provincial (REQ) vs fédéral (CBCA)

**Limite structurelle majeure:** les entreprises incorporées sous la Loi canadienne sur les sociétés par actions (CBCA) n'apparaissent **pas** dans REQ. Beaucoup de compagnies deep-tech choisissent CBCA pour des raisons de propriété intellectuelle et d'attentes investisseurs.

Dans ce rapport, nous utilisons :
- **REQ** pour les tendances de formation locales (recul longitudinal riche).
- **Dealroom + PitchBook** pour combler l'angle mort CBCA (via `GOLD.STARTUP_REGISTRY` et données RC).
- Triangulation quand possible; mention explicite d'incertitude quand impossible.

---

## 4. Niveaux de confiance des classifications

Repris du Q5 diagnostic (`pipelines/validation/diagnostics/Q5_req_post2024_hardtech.sql`) et étendus à tout le périmètre.

| Tier | Critère | Usage dans le rapport |
|------|---------|----------------------|
| HIGH | Mot-clé hard/deep-tech hit ET `PRODUCT_TIER` ∈ {HIGH, MEDIUM} ET non-service | Citations nominatives possibles; chiffres primaires |
| MEDIUM | Mot-clé hit seul OU (CAE hit ET non-service ET HIGH/MEDIUM) | Chiffres secondaires, avec caveat |
| LOW | CAE hit seul | Plage d'incertitude "X à Y" |
| NONE | Aucun signal | Exclu |

Règle de publication : **aucun chiffre primaire ne repose sur LOW-seul**. Quand LOW est inclus (pour transparence), il est explicitement marqué "estimation élargie".

---

## 5. Alignement avec la littérature existante

Dans la mesure du possible, nous alignons nos définitions avec :

- **GSER / Startup Genome** — "deep tech" dans leurs rapports inclut AI, biotech, advanced robotics, quantum, blockchain. Nous sommes **plus stricts** en excluant l'IA pure et la blockchain.
- **BDC / Deloitte (Canada)** — rapports similaires classent cleantech + medtech comme silos distincts. Nous les gardons sous le parapluie "deep tech" pour éviter la fragmentation.
- **Dealroom "deep tech"** — classification cross-sectorielle. Nous l'adoptons mais vérifions contre notre taxonomie locale.
- **Commission européenne / Chips Act** — focus strict sur semi, photonique, quantique. Plus étroit que nous; citer quand pertinent pour comparaison de politique.

---

## 6. Ouverture à la révision

Cette taxonomie est une **v0.1**. Des révisions attendues à mesure que l'analyse progresse :

- Un 10e pilier pourrait émerger (ex. "systèmes d'énergie fondamentaux" couvrant fusion / fission SMR) si les données en montrent une masse critique.
- MedTech et biotech-hardware pourraient se scinder si les dynamiques diffèrent.
- Agri-tech pourrait être reclassé sous cleantech si volumes trop faibles.

Les révisions de taxonomie qui affecteraient les chiffres du rapport déclenchent une **branche `taxonomy/`** et une PR cross-org, per convention du repo (voir `skills/branch-conventions.md`).

---

## Annexes

- `taxonomy/sectors.yaml` — taxonomie canonique du repo
- `pipelines/transforms/silver/31_req_product_classification.sql` — classifier opérationnel
- `insights/internal/hardware-photonics-req-2026.md` — analyse historique narrower
- `pipelines/validation/diagnostics/Q5_req_post2024_hardtech.sql` — diagnostic post-2024
