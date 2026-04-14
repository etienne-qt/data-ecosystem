"""Startup classifier — rates Dealroom companies as A+/A/B/C/D.

Migrated from ~/Desktop/dealroom_classifier.py.

Usage:
    from ecosystem.processing.classifier import rate_companies
    result_df = rate_companies(df, score_version="v5")

The public API is `rate_companies(df, score_version) -> DataFrame` returning:
    drm_company_id, startup_rating_letter, rating_reason, score_version, startup_score
"""

from __future__ import annotations

import functools
import logging
import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


# ============================================================
# Configuration
# ============================================================

@dataclass
class ClassifierConfig:
    """Tunable parameters for the classifier."""

    completeness_fields: list[str] = field(default_factory=lambda: [
        "Website", "LinkedIn", "Industries", "Sub industries", "All tags",
        "Tags", "Long description", "Tagline", "Launch year",
    ])
    completeness_min_a: float = 0.85
    completeness_min_b: float = 0.50
    dealroom_signal_a_nudge: int = 20
    use_dealroom_signal_nudge: bool = True
    safe_mode_strict_d_for_services: bool = True
    manual_overrides: dict[str, str] = field(default_factory=dict)


DEFAULT_CONFIG = ClassifierConfig()

# Text columns scanned for keyword matching
TEXT_COLS = [
    "Name", "Tagline", "Long description", "Industries", "Sub industries",
    "Tags", "All tags", "Technologies",
]


# ============================================================
# Keyword lists
# ============================================================

GOV_ORG_SUFFIXES = [
    ".gov", ".gouv.qc.ca", ".gc.ca", ".quebec", ".gouv.fr", ".gov.uk", ".qc.ca", ".gouv.ca", ".ong",
]

GOV_ORG_KEYWORDS = [
    "ministere", "ministry", "municipalite", "municipality", "city of", "ville de", "ciudad de",
    "centre integre de sante", "chsld", "cisss", "ciusss", "public health", "gouvernement", "agence de sante",
    "organisme communautaire", "non-profit", "non profit", "organisme sans but lucratif", "osbl",
    "foundation", "fondation", "association", "cooperative", "coop", "societe d'etat",
    "prevention du suicide", "centre d'entraide", "entraide", "organisme", "charity",
]

ACCELERATOR_KEYWORDS = ["accelerator", "incubator", "accélérateur", "incubateur"]

ACCELERATOR_LIST = [
    "centech", "cycle momentum", "le_camp", "le camp", "acet", "techstars", "startup_montreal_1", "quebec tech",
    "quebec_tech", "mt_lab", "scale_ai_1", "scale ai", "propolys", "quantino", "2_degres", "2 degres",
    "station fintech", "station_fintech", "zu", "district3", "d3", "district_3_innovation_centre",
    "district 3 innovation centre", "nextai", "next ai", "next_ai", "founderfuel", "founder fuel", "esplanade",
    "starburst_accelerator", "startburst", "cdl_montreal", "cdl montreal", "medxlab", "med x lab", "med_x_lab",
    "apollo13", "apollo 13", "apollo_13", "aquaaction", "aqua action", "aqua_action",
    "quebec_life_sciences_incubator_accelerator_cqib_", "cqib", "quebec life sciences incubator accelerator cqib",
    "groupe3737", "groupe 3737", "groupe_3737", "startup_en_r_sidence", "startup en residence",
    "startup en r sidence", "ceim", "tandemlaunch_technologies",
]

SERVICE_PROVIDER_KEYWORDS = [
    "agence", "agency", "conseil", "consulting", "services", "service", "web design", "seo",
    "marketing", "dev shop", "developpement sur mesure", "custom software", "recrutement", "recruitment",
    "formation", "coaching", "comptabilite", "accounting", "ressources humaines", "hebergement", "hosting",
    "it services", "managed services", "maintenance informatique", "boutique de services", "studio",
    "freelance", "outside tech",
]

TECH_KEYWORDS = [
    # AI
    "ai", "ml", "machine learning", "artificial intelligence", "intelligence artificielle",
    "deep learning", "neural network", "large language model", "foundation model",
    "generative ai", "gen ai", "natural language processing", "nlp", "computer vision",
    "image recognition", "predictive analytics", "recommendation engine",
    "conversational ai", "chatbot", "copilot", "agent", "reinforcement learning",
    "ai model", "training data", "deeptech", "deep tech", "explainable ai", "xai", "responsible ai",
    # Data & analytics
    "data", "data analytics", "analytics", "big data", "data science", "data warehouse",
    "data lake", "data visualization", "business intelligence", "bi", "etl",
    "data pipeline", "mdm", "dashboard", "reporting", "analytics platform", "data governance",
    # IoT & embedded
    "iot", "internet of things", "connected device", "smart device", "embedded system",
    "embedded software", "edge computing", "edge ai", "smart sensor", "wireless sensor",
    "telemetry", "data logger", "wearable", "smart home", "connected vehicle",
    "lora", "sigfox", "mqtt", "device management",
    # Robotics & automation
    "robotics", "robot", "robotic arm", "cobot", "collaborative robot",
    "industrial automation", "process automation", "rpa", "factory automation",
    "automated system", "autonomous robot", "autonomous vehicle", "drone",
    "uav", "unmanned system", "navigation system", "vision-guided", "manipulator",
    "motion control", "autonomous", "autonomous tech", "autonomous driving",
    # Cybersecurity
    "cyber", "cybersecurity", "cybersecurite", "information security", "data protection",
    "privacy", "network security", "infosec", "endpoint protection", "encryption",
    "threat detection", "identity management", "iam", "zero trust", "access control",
    "siem", "firewall", "malware detection", "phishing protection", "compliance", "cyber resilience",
    # Blockchain & Web3
    "blockchain", "distributed ledger", "web3", "cryptocurrency", "crypto asset",
    "digital wallet", "token", "smart contract", "defi", "nft", "dao", "stablecoin",
    "digital identity", "decentralized exchange", "proof of reserve", "tokenization",
    "metaverse", "decentralized app", "dapp",
    # Quantum
    "quantum", "quantum computing", "quantum technology", "qubit", "quantum algorithm",
    "quantum communication", "quantum sensor", "superconducting", "cryogenics",
    "quantum hardware", "quantum annealing",
    # Hardware & components
    "hardware", "semiconductor", "semiconductors", "chip", "microchip", "microprocessor",
    "integrated circuit", "pcb", "electronic board", "fpga", "sensor", "device",
    "electronics manufacturing", "embedded hardware", "ai chip", "ai accelerator",
    "neuromorphic", "electromechanical",
    # Photonics & laser
    "photonics", "laser", "optics", "optical sensor", "fiber optics", "lidar",
    "spectroscopy", "photodetector", "optoelectronics", "optical imaging",
    "integrated photonics", "photonics tech",
    # XR & spatial computing
    "virtual reality", "vr", "augmented reality", "ar", "mixed reality", "mr",
    "extended reality", "xr", "holography", "immersive experience", "digital twin",
    "3d visualization", "headset", "spatial computing",
    # Additive manufacturing
    "3d printing", "additive manufacturing", "rapid prototyping", "3d fabrication",
    "printed material", "generative design", "metal printing", "polymer printing",
    "on-demand production", "local manufacturing",
    # Energy & cleantech
    "energy", "renewable energy", "clean energy", "clean tech", "cleantech",
    "green tech", "greentech", "climate tech", "climatetech", "decarbonization",
    "carbon capture", "carbon storage", "sustainability", "circular economy",
    "recycling", "waste management", "water treatment", "pollution control",
    "hydrogen", "battery", "energy storage", "solar", "wind", "hydro", "smart grid",
    # Space & geospatial
    "satellite", "nanosatellite", "cubesat", "earth observation", "geospatial",
    "mapping", "radar", "space propulsion", "communication satellite", "gnss",
    "remote sensing", "space", "spacetech", "space tech",
    # Advanced materials & nanotech
    "advanced materials", "nanotech", "nanotechnology", "composites", "coatings",
    "polymers", "ceramics", "graphene", "metamaterials", "lightweight materials",
    # Health & biotech
    "biotech", "medtech", "healthtech", "health technology", "medical device",
    "devices", "synthetic biology", "synbio",
    # Frontier / deep / hard tech
    "frontier tech", "frontier technology", "hard tech", "hardtech",
    "industrial tech", "hardware startup", "physical product", "manufacturing",
    "advanced manufacturing", "factory equipment", "production equipment",
    "grid technology", "industrial automation", "power systems", "novel energy",
    "nuclear fusion", "fusion", "tokamak", "solid-state battery",
    "solid state battery", "solid-state batteries", "carbon removal",
    "direct air capture", "dac", "autonomous systems", "tough tech", "future of computing",
]

CONSUMER_KEYWORDS = [
    "ecommerce", "e-commerce", "marketplace", "boutique", "magasin", "store",
    "retail", "vetements", "apparel", "clothing", "fashion", "home renovation", "renovation",
    "kitchen", "bath", "furniture", "meubles", "food", "restaurant", "cafe", "grocery", "traiteur",
    "cosmetics", "beauty", "salon", "spa", "gym", "yoga", "bakery", "boulangerie", "patisserie",
    "plombier", "électricien", "plomberie", "ménage",
    "hotel", "tourism", "travel", "wedding", "photography", "event planning",
    "broker", "brokerage", "real estate agency", "fitness studio",
    "art gallery", "gallery", "florist", "veterinary",
    "dentist", "dental", "optometrist", "chiropractor",
    "notary", "notaire",
]

VC_TYPE_KEYWORDS = [
    "venture capital", "vc", "seed", "serie a", "series a", "series b", "series c",
    "angel", "pre-seed", "pre seed", "equity crowdfunding",
]

ECOMMERCE_ALIASES = {
    "ecommerce", "e-commerce", "e commerce", "marketplace", "market place",
}


# ============================================================
# Text helpers
# ============================================================

def nz(x: object) -> str:
    """Normalize to ASCII lowercase string, strip whitespace. NaN → empty string."""
    if pd.isna(x):
        return ""
    s = str(x)
    try:
        s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    except Exception:
        pass
    return s.strip().lower()


@functools.lru_cache(maxsize=256)
def _short_kw_pattern(keyword: str) -> re.Pattern:
    escaped = re.escape(keyword)
    return re.compile(rf"(?<![a-z0-9]){escaped}(?![a-z0-9])")


def has_any_keyword(text: str, keywords: list[str]) -> bool:
    t = nz(text)
    if not t:
        return False
    for k in keywords:
        if len(k) <= 3:
            if _short_kw_pattern(k).search(t):
                return True
        else:
            if k in t:
                return True
    return False


def any_in_columns(row: pd.Series, cols: list[str], keywords: list[str]) -> bool:
    return any(
        c in row.index and has_any_keyword(row.get(c, ""), keywords)
        for c in cols
    )


def safe_float(x: object) -> float:
    """Robust float parser for funding, signals etc."""
    try:
        s = str(x).replace(",", "").strip()
        if not s or s.lower() in {"nan", "none", "null"}:
            return 0.0
        return float(s)
    except Exception:
        return 0.0


def present_ratio(row: pd.Series, required_cols: list[str]) -> float:
    """Fraction of required_cols that are non-empty on a given row."""
    total = len(required_cols)
    if total == 0:
        return 0.0
    present = sum(
        1 for c in required_cols
        if c in row.index and str(row.get(c, "")).strip().lower() not in {"", "nan", "none", "null"}
    )
    return present / total


def _tokens_from_field(s: str) -> list[str]:
    s_norm = nz(s)
    if not s_norm:
        return []
    parts = re.split(r"[,|;/]+", s_norm)
    return [p.strip().lower() for p in parts if p.strip()]


def get_any(row: pd.Series, cols: list[str]) -> str:
    """Concatenate values from several columns into one string."""
    parts = [
        str(row[c]) for c in cols
        if c in row.index and pd.notna(row[c]) and str(row[c]).strip()
    ]
    return " | ".join(parts)


# ============================================================
# Feature flags
# ============================================================

def is_gov_or_nonprofit(row: pd.Series) -> bool:
    website = nz(row.get("Website", ""))
    if any(suf in website for suf in GOV_ORG_SUFFIXES):
        return True
    # Soft .org check: only counts if text also contains a gov/org keyword
    if ".org" in website and any_in_columns(row, TEXT_COLS, GOV_ORG_KEYWORDS):
        return True
    return any_in_columns(row, TEXT_COLS, GOV_ORG_KEYWORDS)


def has_accelerator_signal(row: pd.Series) -> bool:
    if has_any_keyword(row.get("Each investor type", ""), ACCELERATOR_KEYWORDS):
        return True
    haystack = get_any(row, ["Investors names", "Lead investors", "All tags", "Tags", "Long description"])
    return has_any_keyword(haystack, ACCELERATOR_LIST)


def is_service_provider(row: pd.Series) -> bool:
    return any_in_columns(row, TEXT_COLS, SERVICE_PROVIDER_KEYWORDS)


def has_tech_indication(row: pd.Series) -> bool:
    return any_in_columns(row, TEXT_COLS + ["Technologies"], TECH_KEYWORDS)


def is_consumer_only(row: pd.Series) -> bool:
    if has_tech_indication(row):
        return False
    return any_in_columns(row, TEXT_COLS, CONSUMER_KEYWORDS)


def is_vc_backed(row: pd.Series) -> bool:
    haystack = get_any(row, ["Each investor type", "Investors names", "Lead investors", "Each round type"])
    return has_any_keyword(haystack, VC_TYPE_KEYWORDS)


def compute_completeness(row: pd.Series, fields: list[str]) -> float:
    return present_ratio(row, fields)


def tech_strength(row: pd.Series) -> int:
    """Count of text columns with tech keywords + tech field presence."""
    hits = sum(1 for c in TEXT_COLS if has_any_keyword(row.get(c, ""), TECH_KEYWORDS))
    if str(row.get("Technologies", "")).strip():
        hits += 1
    return hits


def dealroom_signal_bump(row: pd.Series, threshold: int = 20) -> bool:
    return safe_float(row.get("Dealroom Signal - Rating", "")) >= threshold


def ecommerce_only(row: pd.Series) -> bool:
    """True iff the ONLY technology tags present are e-commerce/marketplace variants."""
    toks = _tokens_from_field(str(row.get("Technologies", "")))
    if not toks:
        return False
    return all(t in ECOMMERCE_ALIASES for t in toks)


ESTABLISHED_INDUSTRIES = {
    "food", "home living", "fashion", "real estate", "wellness beauty", "kids", "sports",
}


def is_established_business(row: pd.Series) -> bool:
    """Detect traditional/established businesses unlikely to be startups.

    True when 2+ of:
    - launch_year < 2005
    - employees > 200
    - low-tech traditional industry
    - acquired/ipo/public status
    """
    signals = 0

    launch = row.get("Launch year")
    if pd.notna(launch):
        try:
            if float(launch) < 2005:
                signals += 1
        except (ValueError, TypeError):
            pass

    emp = row.get("Employees latest number")
    if pd.notna(emp):
        try:
            if float(emp) > 200:
                signals += 1
        except (ValueError, TypeError):
            pass

    # Traditional industry with weak tech
    industries_text = nz(row.get("Industries", ""))
    ts = tech_strength(row)
    if ts <= 2 and any(ind in industries_text for ind in ESTABLISHED_INDUSTRIES):
        signals += 1

    status_val = nz(row.get("Company status", ""))
    if status_val in {"acquired", "ipo", "public"}:
        signals += 1

    return signals >= 2


def has_weak_tech_signal(row: pd.Series) -> bool:
    """True when tech_strength <= 2, Technologies field empty, and not VC-backed."""
    ts = tech_strength(row)
    techs = nz(row.get("Technologies", ""))
    return ts <= 2 and not techs and not is_vc_backed(row)


def _has_consumer_keywords(row: pd.Series) -> bool:
    """Check consumer keywords WITHOUT the tech exclusion gate."""
    return any_in_columns(row, TEXT_COLS, CONSUMER_KEYWORDS)


# ============================================================
# Core rating logic
# ============================================================

def rate_company(row: pd.Series, config: ClassifierConfig | None = None) -> dict[str, Any]:
    """Rate a single company row. Returns {"rating": str, "reason": str}."""
    cfg = config or DEFAULT_CONFIG

    # Manual overrides — skip post-hoc adjustments
    manual_col = str(row.get("Manual override", "")).strip()
    manual_dict = cfg.manual_overrides.get(str(row.get("ID", "")).strip())
    if manual_col in {"A+", "A", "B", "C", "D"}:
        return {"rating": manual_col, "reason": "manual_override_column"}
    if manual_dict in {"A+", "A", "B", "C", "D"}:
        return {"rating": manual_dict, "reason": "manual_override_dict"}

    # Flags
    gov_nonprofit = is_gov_or_nonprofit(row)
    accel = has_accelerator_signal(row)
    svc = is_service_provider(row)
    tech = has_tech_indication(row)
    consumer = is_consumer_only(row)
    vc = is_vc_backed(row)

    try:
        deal_signal = float(str(row.get("Dealroom Signal - Rating", "")).strip())
    except Exception:
        deal_signal = 0.0
    deal_ge_50 = deal_signal >= 50
    deal_gt_50 = deal_signal > 50

    # Kept for parity
    comp = compute_completeness(row, cfg.completeness_fields)
    tech_score = tech_strength(row)

    # ===== Decision tree (produces initial result) =====
    result = None

    # ===== A+ paths =====
    if result is None and accel and vc and tech and not svc and deal_ge_50:
        result = {"rating": "A+", "reason": "A+_accel_vc_tech_not_svc_signal_ge_50"}
    if result is None and (not accel) and vc and tech and (not svc) and (not consumer) and deal_ge_50:
        result = {"rating": "A+", "reason": "A+_vc_tech_not_svc_not_consumer_signal_ge_50"}
    if result is None and (not accel) and (not vc) and tech and (not svc) and (not consumer) and deal_ge_50:
        result = {"rating": "A+", "reason": "A+_no_vc_tech_not_svc_not_consumer_signal_ge_50"}
    if result is None and accel and (not vc) and tech and (not svc) and deal_ge_50:
        result = {"rating": "A+", "reason": "A+_accel_not_vc_tech_not_svc_signal_ge_50"}

    # ===== A paths =====
    if result is None and accel and vc and tech and (not svc) and (not deal_ge_50):
        result = {"rating": "A", "reason": "A_accel_vc_tech_not_svc_signal_lt_50"}
    if result is None and (not accel) and vc and tech and (not svc) and (not consumer) and (not deal_ge_50):
        result = {"rating": "A", "reason": "A_vc_tech_not_svc_not_consumer_signal_lt_50"}
    if result is None and (not accel) and (not vc) and tech and (not svc) and (not consumer) and (not deal_ge_50):
        result = {"rating": "A", "reason": "A_no_vc_tech_not_svc_not_consumer_signal_lt_50"}
    if result is None and accel and (not vc) and tech and (not svc) and (not deal_ge_50):
        result = {"rating": "A", "reason": "A_accel_not_vc_tech_not_svc_signal_not_ge_50"}

    # ===== B paths =====
    if result is None and accel and vc and tech and svc:
        result = {"rating": "B", "reason": "B_accel_vc_tech_service_provider"}
    if result is None and accel and (not vc) and tech and svc:
        result = {"rating": "A", "reason": "A_accel_not_vc_tech_not_svc_signal_not_ge_50"}
    if result is None and (not accel) and vc and tech and (not svc) and consumer and deal_ge_50:
        result = {"rating": "B", "reason": "B_vc_tech_not_svc_consumer_signal_ge_50"}
    if result is None and (not accel) and (not vc) and tech and (not svc) and consumer and deal_ge_50:
        result = {"rating": "B", "reason": "B_no_vc_tech_not_svc_consumer_signal_ge_50"}
    if result is None and (not accel) and (not vc) and (not tech) and (not svc) and (not consumer) and deal_ge_50:
        result = {"rating": "B", "reason": "B_no_vc_no_tech_not_svc_not_consumer_signal_ge_50"}

    # ===== C paths =====
    if result is None and accel and (not vc) and (not tech):
        result = {"rating": "C", "reason": "C_accel_no_vc_no_tech"}
    if result is None and accel and (not vc) and tech and svc:
        result = {"rating": "C", "reason": "C_accel_no_vc_tech_svc"}
    if result is None and accel and vc and (not tech):
        result = {"rating": "C", "reason": "C_accel_vc_no_tech"}
    if result is None and (not accel) and vc and (not tech):
        result = {"rating": "C", "reason": "C_vc_no_tech"}
    if result is None and (not accel) and vc and tech and svc:
        result = {"rating": "C", "reason": "C_vc_tech_service_provider"}
    if result is None and (not accel) and vc and tech and (not svc) and consumer and (not deal_gt_50):
        result = {"rating": "C", "reason": "C_vc_tech_not_svc_consumer_signal_le_50"}
    if result is None and (not accel) and (not vc) and tech and svc:
        result = {"rating": "C", "reason": "C_no_vc_tech_service_provider"}
    if result is None and (not accel) and (not vc) and tech and (not svc) and consumer and (not deal_gt_50):
        result = {"rating": "C", "reason": "C_no_vc_tech_not_svc_consumer_signal_le_50"}
    if result is None and (not accel) and (not vc) and (not tech) and (not svc) and consumer and deal_gt_50:
        result = {"rating": "C", "reason": "C_no_vc_no_tech_not_svc_consumer_signal_gt_50"}
    if result is None and (not accel) and (not vc) and (not tech) and (not svc) and (not consumer) and (not deal_gt_50):
        result = {"rating": "C", "reason": "C_no_vc_no_tech_not_svc_not_consumer_signal_le_50"}

    # ===== D paths =====
    if result is None and (not accel) and (not vc) and (not tech) and svc:
        result = {"rating": "D", "reason": "D_no_vc_no_tech_service_provider"}
    if result is None and (not accel) and (not vc) and (not tech) and (not svc) and consumer and (not deal_gt_50):
        result = {"rating": "D", "reason": "D_no_vc_no_tech_not_svc_consumer_signal_le_50"}
    if result is None and gov_nonprofit:
        result = {"rating": "D", "reason": "gov_or_nonprofit"}

    if result is None:
        result = {"rating": "D", "reason": "does_not_meet_startup_criteria"}

    # ===== Post-hoc adjustments =====
    if result["rating"] in {"A+", "A"} and is_established_business(row):
        result = {"rating": "C", "reason": "C_established_business_override"}
    if result["rating"] in {"A+", "A"} and has_weak_tech_signal(row) and _has_consumer_keywords(row):
        result = {"rating": "C", "reason": "C_weak_tech_consumer_override"}

    # Weak tech + no VC/accel on dominant A path → B
    if (result["rating"] == "A"
            and result["reason"] == "A_no_vc_tech_not_svc_not_consumer_signal_lt_50"
            and tech_score < 3):
        result = {"rating": "B", "reason": "B_weak_tech_no_vc_no_accel_downgrade"}

    # Old company (pre-2005) with no VC/accel → C
    if result["rating"] in {"A+", "A"}:
        _launch = row.get("Launch year")
        _launch_year = None
        if pd.notna(_launch):
            try:
                _launch_year = float(_launch)
            except (ValueError, TypeError):
                pass
        if _launch_year is not None and _launch_year < 2005 and not vc and not accel:
            result = {"rating": "C", "reason": "C_old_company_no_vc_no_accel_override"}

    return result


# ============================================================
# Public API
# ============================================================

def rate_companies(
    df: pd.DataFrame,
    score_version: str = "v1",
    config: ClassifierConfig | None = None,
) -> pd.DataFrame:
    """Rate all companies in a Dealroom-style DataFrame.

    Args:
        df: DataFrame with Dealroom columns. Must contain an ID column.
        score_version: Version tag for the output.
        config: Optional ClassifierConfig overrides.

    Returns:
        DataFrame with columns: drm_company_id, startup_rating_letter, rating_reason, score_version
    """
    cfg = config or DEFAULT_CONFIG

    # Normalize ID column
    id_col = None
    for cand in ["ID", "Id", "id", "Company ID", "company_id"]:
        if cand in df.columns:
            id_col = cand
            break
    if id_col is None:
        raise ValueError("No ID column found among ['ID','Id','id','Company ID','company_id'].")

    if id_col != "ID":
        df = df.rename(columns={id_col: "ID"})

    results = df.apply(lambda row: rate_company(row, cfg), axis=1, result_type="expand")

    # Compute continuous startup_score (0-100)
    def _compute_score(row_idx):
        letter = results.at[row_idx, "rating"]
        orig_row = df.loc[row_idx]
        base = {"A+": 95, "A": 85, "B": 70, "C": 50, "D": 20}.get(letter, 20)

        ts = tech_strength(orig_row)
        comp = compute_completeness(orig_row, cfg.completeness_fields)

        score = base + min(10, ts * 2) + comp * 10

        launch = orig_row.get("Launch year")
        try:
            ly = float(launch) if pd.notna(launch) else None
        except (ValueError, TypeError):
            ly = None

        if ly is not None:
            if ly >= 2020:
                score += 10  # 5 for >=2015 + 5 for >=2020
            elif ly >= 2015:
                score += 5
            if ly < 1990:
                score -= 15
            elif ly < 2000:
                score -= 10

        emp = orig_row.get("Employees latest number")
        try:
            emp_val = float(emp) if pd.notna(emp) else None
        except (ValueError, TypeError):
            emp_val = None

        if emp_val is not None:
            if emp_val > 1000:
                score -= 15
            elif emp_val > 500:
                score -= 10

        return max(0, min(100, score))

    startup_scores = pd.Series([_compute_score(i) for i in df.index], index=df.index)

    return pd.DataFrame({
        "drm_company_id": df["ID"].astype(str),
        "startup_rating_letter": results["rating"],
        "rating_reason": results["reason"],
        "score_version": score_version,
        "startup_score": startup_scores,
    })


def attach_flags_for_qc(df: pd.DataFrame, config: ClassifierConfig | None = None) -> pd.DataFrame:
    """Attach internal classification flags as columns for QC export."""
    cfg = config or DEFAULT_CONFIG
    df = df.copy()
    df["is_gov_nonprofit"] = df.apply(is_gov_or_nonprofit, axis=1)
    df["has_accelerator"] = df.apply(has_accelerator_signal, axis=1)
    df["is_service_provider"] = df.apply(is_service_provider, axis=1)
    df["has_tech_indication"] = df.apply(has_tech_indication, axis=1)
    df["is_consumer_only"] = df.apply(is_consumer_only, axis=1)
    df["is_vc_backed"] = df.apply(is_vc_backed, axis=1)
    df["completeness"] = df.apply(lambda r: compute_completeness(r, cfg.completeness_fields), axis=1)
    df["tech_strength"] = df.apply(tech_strength, axis=1)
    df["dealroom_signal_nudge"] = df.apply(dealroom_signal_bump, axis=1)
    return df
