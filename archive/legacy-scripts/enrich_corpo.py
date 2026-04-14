"""Enrich Quebec corporate leads with website, domain, and NEQ.

Reads data_corpo_mouvement_to_enrich.csv, searches DuckDuckGo for each company,
and fills in Site Web, Domaine d'activité, and NEQ columns.
"""

from __future__ import annotations

import csv
import json
import logging
import re
import time
from pathlib import Path

from duckduckgo_search import DDGS

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger(__name__)

INPUT_CSV = Path("tmp_gs_files/data_corpo_mouvement_to_enrich.csv")
OUTPUT_CSV = Path("tmp_gs_files/data_corpo_mouvement_enriched.csv")
PROGRESS_FILE = Path("tmp_gs_files/enrich_progress.json")

# Known domain mappings for well-known companies (saves searches)
KNOWN_WEBSITES: dict[str, str] = {
    "Metro": "https://www.metro.ca",
    "GardaWorld": "https://www.garda.com",
    "BRP": "https://www.brp.com",
    "Cascades": "https://www.cascades.com",
    "Saputo": "https://www.saputo.com",
    "Agropur coopérative": "https://www.agropur.com",
    "Pomerleau": "https://www.pomerleau.ca",
    "TFI International": "https://www.tfiintl.com",
    "Kruger": "https://www.kruger.com",
    "Domtar": "https://www.domtar.com",
    "Airbus Canada": "https://www.airbus.com",
    "CGI": "https://www.cgi.com",
    "WSP": "https://www.wsp.com",
    "SNC-Lavalin": "https://www.snclavalin.com",
    "Bombardier": "https://www.bombardier.com",
    "CAE": "https://www.cae.com",
    "Bell": "https://www.bell.ca",
    "Desjardins": "https://www.desjardins.com",
    "Hydro-Québec": "https://www.hydroquebec.com",
    "Loto-Québec": "https://www.lotoquebec.com",
    "SAQ": "https://www.saq.com",
    "Couche-Tard": "https://www.couche-tard.com",
    "Dollarama": "https://www.dollarama.com",
    "Intact": "https://www.intact.ca",
    "Power Corporation": "https://www.powercorporation.com",
    "National Bank": "https://www.nbc.ca",
    "Banque Nationale": "https://www.bnc.ca",
    "Transcontinental": "https://www.tc.tc",
    "Québecor": "https://www.quebecor.com",
    "Vidéotron": "https://www.videotron.com",
}


def load_progress() -> dict:
    """Load previously processed companies."""
    if PROGRESS_FILE.exists():
        return json.loads(PROGRESS_FILE.read_text())
    return {}


def save_progress(progress: dict) -> None:
    PROGRESS_FILE.write_text(json.dumps(progress, ensure_ascii=False, indent=2))


def extract_website(results: list[dict], company_name: str) -> str:
    """Extract the most likely official website from search results."""
    if not results:
        return ""

    # Skip known non-company domains
    skip_domains = {
        "wikipedia.org", "linkedin.com", "facebook.com", "twitter.com",
        "youtube.com", "glassdoor.com", "indeed.com", "crunchbase.com",
        "bloomberg.com", "reuters.com", "lesaffaires.com", "lapresse.ca",
        "journaldemontreal.com", "ledevoir.com", "ici.radio-canada.ca",
        "registreentreprises.gouv.qc.ca", "canada.ca", "quebec.ca",
        "zonecours.hec.ca", "bdc.ca", "yellowpages.ca",
    }

    for r in results:
        href = r.get("href", "") or r.get("link", "")
        if not href:
            continue
        # Extract domain
        domain = re.sub(r"^https?://(?:www\.)?", "", href).split("/")[0].lower()
        if any(skip in domain for skip in skip_domains):
            continue
        # Likely the official site
        scheme_url = href.split("?")[0].rstrip("/")
        if not scheme_url.startswith("http"):
            scheme_url = "https://" + scheme_url
        # Return just the base URL
        parts = scheme_url.split("/")
        if len(parts) >= 3:
            return "/".join(parts[:3])
        return scheme_url

    return ""


def extract_neq(results: list[dict]) -> str:
    """Try to extract NEQ from search results about Quebec registry."""
    neq_pattern = re.compile(r"\b(11\d{8})\b")
    for r in results:
        body = r.get("body", "") or r.get("snippet", "")
        title = r.get("title", "")
        text = f"{title} {body}"
        m = neq_pattern.search(text)
        if m:
            return m.group(1)
    return ""


def classify_domain(description: str) -> str:
    """Classify the business domain from the description."""
    if not description:
        return ""
    desc_lower = description.lower()

    mappings = [
        (["alimentaire", "laitier", "agroalimentaire", "épicerie", "boulangerie",
          "brasserie", "boisson", "café", "restaurant", "traiteur"], "Agroalimentaire"),
        (["pharmaceut", "santé", "médic", "biotech", "clinique", "hôpital"], "Santé / Sciences de la vie"),
        (["aéronaut", "aérospatial", "aviation", "avion"], "Aérospatiale"),
        (["construct", "bâtiment", "génie civil", "béton", "charpente",
          "entrepreneur général", "infrastructure"], "Construction / Génie civil"),
        (["transport", "logistique", "camionnage", "ferroviaire", "autobus"], "Transport / Logistique"),
        (["technologi", "informatique", "logiciel", "numérique", "intelligence artificielle",
          "cloud", "saas", "cybersécurit"], "Technologies de l'information"),
        (["télécommun", "câblodistri", "média", "diffusion"], "Télécommunications / Médias"),
        (["énergie", "électri", "hydroélectri", "pétroli", "gaz naturel",
          "renouvelable", "solaire", "éolien"], "Énergie"),
        (["minier", "mine", "aluminium", "métallurg", "acier", "fonderie"], "Mines / Métallurgie"),
        (["forestier", "papier", "bois", "pâte", "carton", "emballage"], "Foresterie / Pâtes et papiers"),
        (["financ", "banque", "assurance", "comptab", "investiss", "gestion de patrimoine",
          "fonds", "courtage"], "Services financiers / Assurances"),
        (["sécurité", "surveillance", "gardiennage", "protection"], "Sécurité"),
        (["quincailler", "matériaux", "rénovation", "peinture"], "Quincaillerie / Rénovation"),
        (["détail", "commerce", "vente au détail", "magasin", "distribution"], "Commerce de détail / Distribution"),
        (["immobili", "gestion immobilière", "développement immobilier"], "Immobilier"),
        (["jeu", "loterie", "divertissement", "casino"], "Divertissement / Jeux"),
        (["agri", "ferme", "coopérative agricole", "culture", "élevage"], "Agriculture"),
        (["manufactur", "fabrication", "industriel", "usinage"], "Manufacturier"),
        (["conseil", "consultant", "ingénierie"], "Services-conseils / Ingénierie"),
        (["environnement", "recyclage", "résidu", "déchet", "assainissement"], "Environnement / Recyclage"),
        (["textile", "vêtement", "mode"], "Textile / Mode"),
        (["automobile", "véhicule", "concessionnaire"], "Automobile"),
        (["chimie", "chimique", "produits chimiques"], "Chimie"),
        (["optique", "optométri", "lunette"], "Optique"),
    ]

    for keywords, domain in mappings:
        if any(kw in desc_lower for kw in keywords):
            return domain

    return ""


def search_company(ddgs: DDGS, company_name: str, description: str, hq: str) -> dict:
    """Search for a company's website and NEQ."""
    result = {"site_web": "", "domaine": "", "neq": ""}

    # Classify domain from existing description
    result["domaine"] = classify_domain(description)

    # Check known websites first
    if company_name in KNOWN_WEBSITES:
        result["site_web"] = KNOWN_WEBSITES[company_name]
    else:
        # Search for website
        try:
            query = f"{company_name} Québec site officiel"
            results = list(ddgs.text(query, max_results=5, region="ca-fr"))
            result["site_web"] = extract_website(results, company_name)
            time.sleep(0.5)
        except Exception as e:
            log.warning("Website search failed for %s: %s", company_name, e)
            time.sleep(2)

    # Search for NEQ
    try:
        neq_query = f"{company_name} NEQ registre entreprises Québec"
        neq_results = list(ddgs.text(neq_query, max_results=5, region="ca-fr"))
        result["neq"] = extract_neq(neq_results)
        time.sleep(0.5)
    except Exception as e:
        log.warning("NEQ search failed for %s: %s", company_name, e)
        time.sleep(2)

    return result


def main():
    # Read CSV
    with open(INPUT_CSV, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        headers = next(reader)
        rows = list(reader)

    log.info("Loaded %d companies from CSV", len(rows))

    # Column indices
    name_idx = 1  # Unnamed: 1
    desc_idx = 3  # Unnamed: 3
    hq_idx = 5    # Siege sociale
    domaine_idx = headers.index("Domaine d'activité")
    siteweb_idx = headers.index("Site Web")
    neq_idx = headers.index("NEQ")

    # Load progress
    progress = load_progress()
    log.info("Previously processed: %d companies", len(progress))

    ddgs = DDGS()
    processed = 0
    errors = 0

    for i, row in enumerate(rows):
        # Pad row if needed
        while len(row) < len(headers):
            row.append("")

        company_name = row[name_idx].strip()
        if not company_name:
            continue

        # Skip if already processed
        if company_name in progress:
            data = progress[company_name]
            row[domaine_idx] = data.get("domaine", row[domaine_idx])
            row[siteweb_idx] = data.get("site_web", row[siteweb_idx])
            row[neq_idx] = data.get("neq", row[neq_idx])
            continue

        description = row[desc_idx].strip() if desc_idx < len(row) else ""
        hq = row[hq_idx].strip() if hq_idx < len(row) else ""

        try:
            data = search_company(ddgs, company_name, description, hq)
            row[domaine_idx] = data["domaine"]
            row[siteweb_idx] = data["site_web"]
            row[neq_idx] = data["neq"]

            progress[company_name] = data
            processed += 1

            if processed % 10 == 0:
                save_progress(progress)
                log.info("Processed %d/%d (errors: %d)", processed + len(progress) - processed, len(rows), errors)

        except Exception as e:
            log.error("Error processing %s: %s", company_name, e)
            errors += 1
            time.sleep(3)

    # Save final progress
    save_progress(progress)

    # Write enriched CSV
    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    log.info("Enriched CSV saved to %s (%d processed, %d errors)", OUTPUT_CSV, processed, errors)

    # Stats
    filled_web = sum(1 for r in rows if r[siteweb_idx].strip())
    filled_dom = sum(1 for r in rows if r[domaine_idx].strip())
    filled_neq = sum(1 for r in rows if r[neq_idx].strip())
    log.info("Fill rates: Site Web=%d/%d, Domaine=%d/%d, NEQ=%d/%d",
             filled_web, len(rows), filled_dom, len(rows), filled_neq, len(rows))


if __name__ == "__main__":
    main()
