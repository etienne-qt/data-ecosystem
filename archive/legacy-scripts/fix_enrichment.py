"""Fix enrichment issues in the enriched CSV.

1. Fix known incorrect websites
2. Fill missing domains from descriptions
3. Remove clearly wrong websites (generic/unrelated domains)
"""

import csv
import json
import re
from pathlib import Path

INPUT_CSV = Path("tmp_gs_files/data_corpo_mouvement_enriched.csv")
OUTPUT_CSV = Path("tmp_gs_files/data_corpo_mouvement_enriched.csv")  # overwrite
PROGRESS_FILE = Path("tmp_gs_files/enrich_progress.json")

# Domains that should never appear as company websites
BAD_DOMAINS = {
    "edsheeran.com", "zhihu.com", "answers.microsoft.com", "microsoft.com",
    "apple.com", "google.com", "bing.com", "amazon.com", "netflix.com",
    "stackoverflow.com", "reddit.com", "quora.com", "pinterest.com",
    "tiktok.com", "instagram.com", "x.com", "twitter.com",
    "support.microsoft.com", "en.m.wikipedia.org", "fr.m.wikipedia.org",
    "play.google.com", "apps.apple.com", "store.steampowered.com",
    "mapquest.com", "yellowpages.ca", "pagesjaunes.ca",
    "canada.ca", "quebec.ca", "gouv.qc.ca",
    "lesaffaires.com", "lapresse.ca", "ledevoir.com",
    "journaldemontreal.com", "journaldequebec.com",
    "bdc.ca", "investquebec.com",
    "sadaqah.io", "emirates.com", "facebook.com", "linkedin.com",
    "youtube.com", "glassdoor.com", "indeed.com", "crunchbase.com",
    "bloomberg.com", "reuters.com", "wikipedia.org", "wikimedia.org",
    "ici.radio-canada.ca", "tvanouvelles.ca", "infopresse.com",
    "groupeinvestors.com", "sbisecurities.in", "outlook.com",
    "live.com", "yahoo.com", "msn.com",
    "douban.com", "teacherspayteachers.com", "web.whatsapp.com",
    "whatsapp.com", "premierleague.com", "lowyat.net",
    "alloprof.qc.ca", "tinhte.vn", "excelhome.net",
    "uniboard.ch", "club.excelhome.net", "forum.lowyat.net",
    "pfrbrands.com",
    # Round 3 bad domains
    "britishairways.com", "dogsbestlife.com", "wwe.com", "uesb.br",
    "bestrecipes.com.au", "br.ccm.net", "unad.edu.co", "okmusi.com",
    "spanish.stackexchange.com", "es.pornhub.com", "apa.org",
    "us.etrade.com", "xvideos.com", "meta.com", "bibliaon.com",
    "supportyourtech.com", "thes-traditions.com", "ivyhoopsonline.com",
    "workana.com", "stackexchange.com", "pornhub.com", "etrade.com",
    "ccm.net", "mymemory.translated.net", "translated.net",
    "signalstart.com", "komoot.com", "avito.ru", "otto.de",
    "coupang.com", "booking.com", "airbnb.com", "expedia.com",
    "tripadvisor.com", "yelp.com", "zomato.com", "ubereats.com",
    "doordash.com", "grubhub.com", "postmates.com",
    "shopify.com", "wix.com", "squarespace.com",
    "ebay.com", "alibaba.com", "aliexpress.com",
    "walmart.com", "target.com", "costco.com",
    "homedepot.com", "lowes.com",
    "nytimes.com", "washingtonpost.com", "bbc.com",
    "theguardian.com", "cnn.com", "foxnews.com",
    "springer.com", "elsevier.com", "nature.com",
    "ieee.org", "acm.org", "researchgate.net",
    "academia.edu", "sciencedirect.com",
    "w3schools.com", "geeksforgeeks.org", "tutorialspoint.com",
    "medium.com", "substack.com", "wordpress.com",
    "github.com", "gitlab.com", "bitbucket.org",
    "npm.js.com", "pypi.org", "crates.io",
}

# Known correct websites
FIXES = {
    "Sollio Groupe Coopératif": "https://www.sollio.coop",
    "UAP": "https://www.uapinc.com",
    "Canac": "https://www.canac.ca",
    "GardaWorld": "https://www.garda.com",
    "Foodtastic": "https://foodtastic.ca",
    "Alcoa Canada": "https://www.alcoa.com/canada",
    "Roxboro Bauval (Groupe)": "https://www.roxborobauval.com",
    "ArcelorMittal Produits longs Canada": "https://longs.arcelormittal.com",
    "Canam (Groupe)": "https://www.canam.com",
    "Benny & Co.": "https://www.bfranchisegroup.com",
    "St-Hubert (Groupe)": "https://www.st-hubert.com",
    "L'Oréal Canada": "https://www.loreal.com/fr-ca",
    "Keurig Dr Pepper Canada": "https://www.keurigdrpepper.com",
    "Pfizer Canada": "https://www.pfizer.ca",
    "Aluminerie Alouette": "https://www.alouette.com",
    "Metro Supply Chain (Metro chaîne d\u2019approvisionnement)": "https://www.metrosupplychain.com",
    "Trévi": "https://www.trevi.com",
    "Quincaillerie Richelieu": "https://www.richelieu.com",
    "Patrick Morin": "https://www.patrickmorin.com",
    "Fenplast": "https://www.fenplast.com",
    "Canatal (Industries)": "https://www.canatal.com",
    "Lantic": "https://www.lantic.ca",
    "Chocolats Favoris": "https://www.chocolatsfavoris.com",
    "Souris Mini (Groupe)": "https://www.sourismini.com",
    "Laiterie de Coaticook": "https://www.laiteriedecoaticook.com",
    "Béton Provincial": "https://www.betonprovincial.com",
    "Eurovia Québec": "https://www.eurovia.ca",
    "Coffrages Synergy": "https://www.coffragessynergy.com",
    "Deschênes (Groupe)": "https://www.dfrgroup.com",
    "EBC": "https://www.ebcinc.com",
    "Jamp Pharma (Groupe)": "https://www.jamppharma.com",
    "Lou-Tec (Groupe)": "https://www.lou-tec.com",
    "CMC Électronique": "https://www.cmcelectronics.ca",
    "Artopex": "https://www.artopex.com",
    "Prelco (Groupe)": "https://www.prelco.ca",
    "Forage Orbit Garant": "https://www.forageorbitgarant.com",
    "Constructions Proco": "https://www.proco.ca",
    "Smurfit WestRock Canada": "https://www.smurfitwestrock.com",
    "Tristan": "https://www.tristanstyle.com",
    "Cambli (Groupe)": "https://www.cambli.com",
    "Premier Aviation": "https://www.premieraviation.com",
    "QSL International": "https://www.qsl.com",
    "EBI": "https://www.ebi.com",
    "Courchesne Larose": "https://www.courchesnelarose.com",
    "Omega II": "https://www.omegaii.com",
    "Atwill-Morin (Groupe)": "https://www.atwillmorin.com",
    "Alex Coulombe": "https://www.alexcoulombe.com",
    "Matériaux Blanchet": "https://www.materiauxblanchet.com",
    "AGF (Groupe)": "https://www.agfrebar.com",
    "ABS (Groupe)": "https://www.groupeabs.com",
    "TC Transcontinental": "https://www.tc.tc",
    "Pharmascience": "https://www.pharmascience.com",
    "Vêtements Peerless": "https://www.pfrbrands.com",
    "Lebel (Groupe)": "https://www.groupelebel.com",
    "Emballages Mitchel Lincoln": "https://www.mitchellincoln.com",
    "Océan (Groupe)": "https://www.groupeocean.com",
    "Manac": "https://www.manac.ca",
    "Excelpro": "https://www.excelpro.ca",
    "Uniboard Canada": "https://www.uniboard.com",
    "Benny & Co.": "https://www.bennyco.com",
    "Avantis Coopérative": "https://www.avantis.coop",
    "L. Fournier & Fils": "https://www.lfournier.com",
    "Moreau": "https://www.groupemoreau.com",
    "Commonwealth Plywood": "https://www.commonwealthplywood.com",
    "Pro-B (Groupe)": "https://www.groupeprob.com",
    "Transport Bourassa": "https://www.transportbourassa.com",
    "MG Construction": "https://www.mgconstruction.ca",
    "Grimard": "https://www.grimard.ca",
    "Transport Bourret": "https://www.transportbourret.com",
    "duBreton": "https://www.dubreton.com",
    "Chantier Davie Canada": "https://www.davie.ca",
    "Logistec": "https://www.logistec.com",
    "Riverin (Groupe)": "https://www.grouperiverin.com",
    "Biscuits Leclerc": "https://www.leclerc.ca",
    "Nutrinor coopérative": "https://www.nutrinor.com",
    "Navada": "https://www.navada.ca",
    "Duroking (Groupe)": "https://www.duroking.com",
    "Guay": "https://www.guay.com",
    "Armatures Bois-Francs": "https://www.abf.ca",
    "Trans-West (Groupe)": "https://www.groupetranswest.com",
    "Meloche (Groupe)": "https://www.groupemeloche.com",
    "Aliments Asta": "https://www.alimentsasta.com",
    "Béton préfabriqué du Lac": "https://www.betonprefabriquedulac.com",
    "Honco (Groupe)": "https://www.honco.ca",
    "Lepage Millwork": "https://www.lepagemillwork.com",
    "Bellemare (Groupe)": "https://www.bellemare.ca",
    "Camnor (Groupe)": "https://www.groupecamnor.com",
    "Abbatiello (Groupe)": "https://www.abbatiello.com",
    "Garaga (Groupe)": "https://www.garaga.com",
    "Emballages Winpak Heat Seal (Les)": "https://www.winpak.com",
    "Innovair Solutions": "https://www.innovairsolutions.com",
    "Aliments Fontaine Santé": "https://www.fontainesante.com",
    "Simplex": "https://www.simplex-grinnell.com",
    "Canmec (Groupe)": "https://www.canmec.com",
    "Forget (Groupe)": "https://www.groupeforget.com",
    "Boire & Frères": "https://www.boirefreres.com",
    "Goodfellow": "https://www.goodfellowinc.com",
    "Contrôles Laurentide": "https://www.laurentide.com",
    "TBC Constructions": "https://www.tbcconstructions.com",
    "Umano Medical": "https://www.umanomedical.com",
    "Lambert Somec": "https://www.lambertsomec.com",
    "Stelpro": "https://www.stelpro.com",
    "Logistik Unicorp": "https://www.logistikunicorp.com",
    "Alfred Boivin (Groupe)": "https://www.groupealfredboivin.com",
    "Etalex": "https://www.etalex.com",
    "Canadel": "https://www.?"  # placeholder
}
FIXES.pop("Canadel", None)  # Remove placeholder

# Domain classifications for companies that were missed
DOMAIN_FIXES = {
    "BRP": "Manufacturier / Sports motorisés",
    "Airbus Canada": "Aérospatiale",
    "TFI International": "Transport / Logistique",
    "Couche-Tard": "Commerce de détail / Distribution",
    "Dollarama": "Commerce de détail / Distribution",
    "CGI": "Technologies de l'information",
    "WSP": "Services-conseils / Ingénierie",
    "CAE": "Aérospatiale / Simulation",
    "Bombardier": "Aérospatiale",
    "Bell": "Télécommunications / Médias",
    "Desjardins": "Services financiers / Assurances",
    "Hydro-Québec": "Énergie",
    "Loto-Québec": "Divertissement / Jeux",
    "SAQ": "Commerce de détail / Distribution",
    "National Bank": "Services financiers / Assurances",
    "Banque Nationale": "Services financiers / Assurances",
    "Québecor": "Télécommunications / Médias",
    "Vidéotron": "Télécommunications / Médias",
    "Metro Supply Chain (Metro chaîne d\u2019approvisionnement)": "Transport / Logistique",
}


def is_bad_website(url: str) -> bool:
    """Check if URL is clearly not a company website."""
    if not url:
        return False
    domain = re.sub(r"^https?://(?:www\.)?", "", url).split("/")[0].lower()
    return any(bad in domain for bad in BAD_DOMAINS)


def classify_domain(description: str) -> str:
    """Classify business domain from description."""
    if not description:
        return ""
    desc_lower = description.lower()

    mappings = [
        (["alimentaire", "laitier", "agroalimentaire", "épicerie", "boulangerie",
          "brasserie", "boisson", "café", "restaurant", "traiteur", "biscuit",
          "chocolat", "confiserie", "viande", "porc", "volaille", "sucr",
          "crème glacée", "fromage", "pain"], "Agroalimentaire"),
        (["pharmaceut", "santé", "médic", "biotech", "clinique", "hôpital",
          "lit d'hôpital", "médical"], "Santé / Sciences de la vie"),
        (["aéronaut", "aérospatial", "aviation", "avion"], "Aérospatiale"),
        (["construct", "bâtiment", "génie civil", "béton", "charpente",
          "entrepreneur général", "infrastructure", "coffrage", "toiture",
          "couverture", "plomberie", "électri", "mécanique du bâtiment",
          "chauffage", "ventilation", "climatisation"], "Construction / Génie civil"),
        (["transport", "logistique", "camionnage", "ferroviaire", "autobus",
          "déménagement", "entreposage", "manutention"], "Transport / Logistique"),
        (["technologi", "informatique", "logiciel", "numérique", "intelligence artificielle",
          "cloud", "saas", "cybersécurit", "électronique", "robotique",
          "automatisation", "capteur"], "Technologies de l'information"),
        (["télécommun", "câblodistri", "média", "diffusion", "impression",
          "imprimerie"], "Télécommunications / Médias"),
        (["énergie", "hydroélectri", "pétroli", "gaz naturel",
          "renouvelable", "solaire", "éolien", "chaudière", "combustion"], "Énergie"),
        (["minier", "mine", "aluminium", "métallurg", "acier", "fonderie",
          "métal", "granit", "pierre"], "Mines / Métallurgie"),
        (["forestier", "papier", "bois", "pâte", "carton", "emballage",
          "scierie", "plancher", "bardeau"], "Foresterie / Pâtes et papiers"),
        (["financ", "banque", "assurance", "comptab", "investiss",
          "gestion de patrimoine", "fonds", "courtage"], "Services financiers / Assurances"),
        (["sécurité", "surveillance", "gardiennage", "protection",
          "blindé", "véhicule blindé"], "Sécurité"),
        (["quincailler", "matériaux", "rénovation", "peinture",
          "outillage", "location d'outils"], "Quincaillerie / Rénovation"),
        (["détail", "commerce", "vente au détail", "magasin",
          "distribution"], "Commerce de détail / Distribution"),
        (["immobili", "gestion immobilière", "développement immobilier"], "Immobilier"),
        (["jeu", "loterie", "divertissement", "casino", "hôtel",
          "tourisme", "hébergement"], "Divertissement / Jeux"),
        (["agri", "ferme", "coopérative agricole", "culture", "élevage",
          "serre", "horticulture", "acéricole", "sirop d'érable"], "Agriculture"),
        (["manufactur", "fabrication", "industriel", "usinage",
          "moulage", "plastique", "caoutchouc", "composite",
          "fibre de verre"], "Manufacturier"),
        (["conseil", "consultant", "ingénierie"], "Services-conseils / Ingénierie"),
        (["environnement", "recyclage", "résidu", "déchet", "assainissement",
          "traitement des eaux", "épuration"], "Environnement / Recyclage"),
        (["textile", "vêtement", "mode", "chaussure", "botte"], "Textile / Mode"),
        (["automobile", "véhicule", "concessionnaire", "remorque",
          "semi-remorque"], "Automobile"),
        (["chimie", "chimique", "produits chimiques", "adhésif",
          "scellant", "colle"], "Chimie"),
        (["optique", "optométri", "lunette"], "Optique"),
        (["fenêtre", "porte", "vitre", "vitrage", "menuiserie"], "Portes et fenêtres"),
        (["meuble", "mobilier", "armoire", "cuisine", "ameublement"], "Ameublement"),
        (["naval", "chantier maritime", "navire", "construction navale"], "Construction navale"),
        (["grue", "levage", "excavation", "forage"], "Équipements lourds"),
    ]

    for keywords, domain in mappings:
        if any(kw in desc_lower for kw in keywords):
            return domain

    return ""


def main():
    with open(INPUT_CSV, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        headers = next(reader)
        rows = list(reader)

    domaine_idx = headers.index("Domaine d'activité")
    siteweb_idx = headers.index("Site Web")
    neq_idx = headers.index("NEQ")
    name_idx = 1
    desc_idx = 3

    fixed_web = 0
    fixed_dom = 0

    for row in rows:
        while len(row) < len(headers):
            row.append("")

        name = row[name_idx].strip()
        desc = row[desc_idx].strip()

        # Fix known websites
        if name in FIXES:
            row[siteweb_idx] = FIXES[name]
            fixed_web += 1
        elif is_bad_website(row[siteweb_idx]):
            row[siteweb_idx] = ""
            fixed_web += 1

        # Fix domain classifications
        if name in DOMAIN_FIXES:
            row[domaine_idx] = DOMAIN_FIXES[name]
            fixed_dom += 1
        elif not row[domaine_idx].strip() and desc:
            domain = classify_domain(desc)
            if domain:
                row[domaine_idx] = domain
                fixed_dom += 1

    # Write fixed CSV
    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    # Stats
    filled_web = sum(1 for r in rows if r[siteweb_idx].strip())
    filled_dom = sum(1 for r in rows if r[domaine_idx].strip())
    filled_neq = sum(1 for r in rows if r[neq_idx].strip())
    print(f"Fixed {fixed_web} websites, {fixed_dom} domains")
    print(f"Final fill rates: Site Web={filled_web}/{len(rows)}, Domaine={filled_dom}/{len(rows)}, NEQ={filled_neq}/{len(rows)}")

    # Also update progress file
    progress = json.loads(PROGRESS_FILE.read_text()) if PROGRESS_FILE.exists() else {}
    for row in rows:
        name = row[name_idx].strip()
        if name and name in progress:
            progress[name]["site_web"] = row[siteweb_idx]
            progress[name]["domaine"] = row[domaine_idx]
    PROGRESS_FILE.write_text(json.dumps(progress, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
