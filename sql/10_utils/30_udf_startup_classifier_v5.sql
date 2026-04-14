-- =============================================================================
-- File: 30_udf_startup_classifier_v5.sql
-- Location: /snowflake/sql/10_util/
-- Purpose:
--   Dealroom startup classification logic (previously in Python notebook).
--
-- Returns VARIANT object with:
--   - rating_letter: A+, A, B, C, D
--   - reason: rule label
--   - flags: {tech, vc, accelerator, gov_nonprofit, service_provider, consumer_only}
--   - dealroom_signal_rating: numeric used in the rules
--   - tech_strength: count of fields with tech hits (+1 if Technologies present)
--   - matches: first matched keywords + VC sub-signals (debug/review)
--
-- Notes:
--   - Dealroom-only (no HubSpot, no registry, no web checks).
--   - Two intent-preserving fixes vs the notebook:
--       1) gov/nonprofit applied early (criterion #4)
--       2) removed an inconsistent service-provider -> A rule
-- =============================================================================

use database DEV_QUEBECTECH;
use schema UTIL;

create or replace function DEV_QUEBECTECH.UTIL.STARTUP_CLASSIFY_DEALROOM_V5(
    website string,
    name string,
    tagline string,
    long_description string,
    industries_raw string,
    sub_industries_raw string,
    tags_raw string,
    all_tags_raw string,
    technologies_raw string,
    each_investor_type_raw string,
    each_round_type_raw string,
    investors_names_raw string,
    lead_investors_raw string,
    total_funding_usd_m float,
    total_funding_eur_m float,
    dealroom_signal_rating_raw string
)
returns variant
language javascript
as
$$
  // ---------------------------------------------------------------------------
  // Bind args by position (Snowflake JS UDF safe pattern)
  // ---------------------------------------------------------------------------
  var website               = arguments[0];
  var company_name          = arguments[1];
  var tagline               = arguments[2];
  var long_description      = arguments[3];
  var industries_raw        = arguments[4];
  var sub_industries_raw    = arguments[5];
  var tags_raw              = arguments[6];
  var all_tags_raw          = arguments[7];
  var technologies_raw      = arguments[8];
  var each_investor_type_raw= arguments[9];
  var each_round_type_raw   = arguments[10];
  var investors_names_raw   = arguments[11];
  var lead_investors_raw    = arguments[12];
  var total_funding_usd_m   = arguments[13];
  var total_funding_eur_m   = arguments[14];
  var dealroom_signal_rating_raw = arguments[15];

  
  // -----------------------------
  // Keyword lists (from v5 python notebook)
  // -----------------------------
  const GOV_ORG_SUFFIXES = [
    ".gov",
    ".gouv.qc.ca",
    ".gc.ca",
    ".quebec",
    ".gouv.fr",
    ".gov.uk",
    ".qc.ca",
    ".gouv.ca",
    ".org",
    ".ong"
  ];
  const GOV_ORG_KEYWORDS = [
    "ministere",
    "ministry",
    "municipalite",
    "municipality",
    "city of",
    "ville de",
    "ciudad de",
    "centre integre de sante",
    "chsld",
    "cisss",
    "ciusss",
    "public health",
    "gouvernement",
    "agence de sante",
    "organisme communautaire",
    "non-profit",
    "non profit",
    "organisme sans but lucratif",
    "osbl",
    "foundation",
    "fondation",
    "association",
    "cooperative",
    "coop",
    "societe d'etat",
    "prevention du suicide",
    "centre d'entraide",
    "entraide",
    "charity",
    "prévention du suicide"
  ];
  const ACCELERATOR_KEYWORDS = [
    "accelerator",
    "incubator",
    "startup studio",
    "venture builder",
    "venture studio"
  ];
  const ACCELERATOR_LIST = [
    "centech",
    "cycle momentum",
    "le_camp",
    "le camp",
    "acet",
    "techstars",
    "startup_montreal_1",
    "quebec tech",
    "quebec_tech",
    "mt_lab",
    "mt lab",
    "district 3",
    "d3",
    "nextai",
    "creative destruction lab",
    "cdl",
    "founders factory",
    "launch academy",
    "foundry",
    "y combinator",
    "yc",
    "500 startups",
    "500 global",
    "founders fund",
    "masschallenge",
    "startupbootcamp",
    "entrepreneur first",
    "ef",
    "plug and play",
    "pnp",
    "alchemist accelerator",
    "antler",
    "tech nation",
    "station f",
    "h7",
    "imagine",
    "inovia",
    "real ventures",
    "diagram",
    "panache ventures",
    "white star capital",
    "ftq",
    "aquam",
    "mila",
    "ivadoo",
    "notman house",
    "maison notman",
    "la base entrepreneuriale",
    "la base",
    "esplanade quebec",
    "esplanade",
    "startupfest",
    "bmo launch me",
    "desjardins lab",
    "c2 montreal",
    "investissement quebec",
    "iq"
  ];
  const SERVICE_PROVIDER_KEYWORDS = [
    "consulting",
    "consultant",
    "agence",
    "agency",
    "marketing agency",
    "digital agency",
    "web agency",
    "studio",
    "bureau",
    "cabinet",
    "services",
    "service",
    "integration",
    "integrateur",
    "integrator",
    "implementation",
    "support",
    "managed services",
    "it services",
    "outsourcing",
    "recrutement",
    "recruitment",
    "formation",
    "coaching",
    "comptabilite",
    "accounting",
    "ressources humaines",
    "hebergement",
    "hosting",
    "maintenance informatique",
    "boutique de services",
    "freelance",
    "outside tech"
  ];
  const CONSUMER_ONLY_KEYWORDS = [
    "consumer",
    "b2c only",
    "retail",
    "ecommerce",
    "e-commerce",
    "marketplace",
    "fashion",
    "clothing",
    "beauty",
    "cosmetics",
    "food delivery",
    "restaurant",
    "bar",
    "cafe",
    "hotel",
    "tourism",
    "travel",
    "real estate agency",
    "broker",
    "brokerage",
    "gym",
    "fitness studio",
    "spa",
    "salon",
    "wedding",
    "event planning",
    "photography",
    "music",
    "artist",
    "media agency",
    "influencer",
    "boutique",
    "store"
  ];
  const VC_TYPE_KEYWORDS = [
    "venture capital",
    "vc",
    "seed",
    "serie a",
    "series a",
    "series b",
    "series c",
    "growth",
    "private equity",
    "mezzanine",
    "venture debt"
  ];
  const TECH_KEYWORDS = [
    "ai",
    "artificial intelligence",
    "machine learning",
    "ml",
    "deep learning",
    "nlp",
    "computer vision",
    "generative ai",
    "llm",
    "saas",
    "software",
    "cloud",
    "api",
    "platform",
    "data",
    "analytics",
    "cybersecurity",
    "blockchain",
    "iot",
    "robotics",
    "biotech",
    "medtech",
    "fintech",
    "insurtech",
    "cleantech",
    "edtech",
    "proptech",
    "devops",
    "automation",
    "digital twin",
    "simulation",
    "semiconductor",
    "quantum",
    "ar",
    "vr",
    "mixed reality",
    "3d printing",
    "additive manufacturing",
    "edge computing",
    "computer graphics",
    "payment",
    "payments",
    "identity",
    "kubernetes",
    "docker",
    "microservices",
    "data pipeline",
    "etl",
    "bi",
    "business intelligence",
    "crm",
    "erp",
    "e-signature",
    "health data",
    "clinical",
    "genomics",
    "diagnostics",
    "sensor",
    "wearable",
    "telemedicine",
    "remote monitoring",
    "logistics tech",
    "supply chain",
    "autonomous",
    "drone",
    "satellite",
    "space tech",
    "geospatial",
    "computer aided",
    "cad",
    "plm",
    "manufacturing software",
    "digital health"
  ];

  // -----------------------------
  // Helpers (normalize + substring matching)
  // -----------------------------
  function nz(x) {
    if (x === null || x === undefined) return "";
    let s = String(x).toLowerCase().trim();
    try {
      s = s.normalize("NFKD").replace(/[\u0300-\u036f]/g, "");
    } catch (e) {}
    return s;
  }

  function hasAnyKeyword(text, keywords) {
    const t = nz(text);
    if (!t) return false;
    for (let i = 0; i < keywords.length; i++) {
      const k = keywords[i];
      if (k && t.indexOf(k) >= 0) return true;
    }
    return false;
  }

  function firstMatch(text, keywords) {
    const t = nz(text);
    if (!t) return null;
    for (let i = 0; i < keywords.length; i++) {
      const k = keywords[i];
      if (k && t.indexOf(k) >= 0) return k;
    }
    return null;
  }

  function boolText(x) {
    return nz(x).length > 0;
  }

  function safeFloat(x) {
    if (x === null || x === undefined) return 0.0;
    const s = String(x).replace(/,/g, "").trim();
    if (!s) return 0.0;
    const v = parseFloat(s);
    return isNaN(v) ? 0.0 : v;
  }

  // -----------------------------
  // Text columns equivalent (Name, Tagline, Long description, Industries, Sub industries, Tags, All tags, Technologies)
  // -----------------------------
  const text_cols = [
    nz(company_name),
    nz(tagline),
    nz(long_description),
    nz(industries_raw),
    nz(sub_industries_raw),
    nz(tags_raw),
    nz(all_tags_raw),
    nz(technologies_raw)
  ];
  const text_all = text_cols.join(" | ");

  // -----------------------------
  // Component flags (your 5 criteria)
  // -----------------------------
  // (4) Not government / non-profit / coop etc.
  const w = nz(website);
  let gov_nonprofit = false;
  for (let i = 0; i < GOV_ORG_SUFFIXES.length; i++) {
    const suf = GOV_ORG_SUFFIXES[i];
    if (suf && (w.endsWith(suf) || w.indexOf(suf) >= 0)) {
      gov_nonprofit = true;
      break;
    }
  }
  let gov_kw = null;
  if (!gov_nonprofit) {
    gov_kw = firstMatch(text_all, GOV_ORG_KEYWORDS);
    gov_nonprofit = gov_kw !== null;
  }

  // (3) Accelerator / incubator participation
  const inv_types = nz(each_investor_type_raw);
  const accel_from_type = hasAnyKeyword(inv_types, ACCELERATOR_KEYWORDS);
  const accel_haystack = [
    investors_names_raw,
    lead_investors_raw,
    all_tags_raw,
    tags_raw,
    long_description
  ].map(nz).join(" | ");
  const accel_from_list = hasAnyKeyword(accel_haystack, ACCELERATOR_LIST);
  const accel_kw = firstMatch(accel_haystack, ACCELERATOR_LIST);
  const accelerator = accel_from_type || accel_from_list;

  // (5) Not services-only
  const service_kw = firstMatch(text_all, SERVICE_PROVIDER_KEYWORDS);
  const service_provider = service_kw !== null;

  // (1) Technology keywords
  const tech_kw = firstMatch(text_all, TECH_KEYWORDS);
  const tech = tech_kw !== null;

  // Consumer-only keywords (used in rule tree)
  const consumer_kw = firstMatch(text_all, CONSUMER_ONLY_KEYWORDS);
  const consumer_only = consumer_kw !== null;

  // (2) VC investment signal (keeps your notebook logic: funded OR VC markers OR investors present)
  const usd = safeFloat(total_funding_usd_m);
  const eur = safeFloat(total_funding_eur_m);
  const funded = (usd > 0) || (eur > 0);

  const round_types = nz(each_round_type_raw);
  const investors_text = nz(investors_names_raw) + " " + nz(lead_investors_raw);

  const vc_from_types = hasAnyKeyword(inv_types, VC_TYPE_KEYWORDS);
  const vc_from_rounds = hasAnyKeyword(round_types, VC_TYPE_KEYWORDS);
  const vc_from_investors_present = investors_text.trim().length > 0;  // broad by design (matches notebook)
  const vc = funded || vc_from_types || vc_from_rounds || vc_from_investors_present;

  // Dealroom signal rating used in your rules (>=50, >50)
  const deal_signal = safeFloat(dealroom_signal_rating_raw);
  const deal_ge_50 = deal_signal >= 50;
  const deal_gt_50 = deal_signal > 50;

  // Tech strength (matches notebook pattern)
  let tech_strength = 0;
  for (let i = 0; i < text_cols.length; i++) {
    if (hasAnyKeyword(text_cols[i], TECH_KEYWORDS)) tech_strength += 1;
  }
  if (boolText(technologies_raw)) tech_strength += 1;

  // -----------------------------
  // Letter rating decision tree (A+..D)
  // -----------------------------
  let rating = "D";
  let reason = "does_not_meet_startup_criteria";

  // Fix: gov/nonprofit is a hard negative early (criterion #4)
  if (gov_nonprofit) {
    rating = "D";
    reason = "gov_or_nonprofit";
  } else {
    // A+ paths
    if (accelerator && vc && tech && !service_provider && deal_ge_50) {
      rating = "A+";
      reason = "A+_accel_vc_tech_not_svc_signal_ge_50";
    } else if (!accelerator && vc && tech && !service_provider && !consumer_only && deal_ge_50) {
      rating = "A+";
      reason = "A+_vc_tech_not_svc_not_consumer_signal_ge_50";
    } else if (!accelerator && !vc && tech && !service_provider && !consumer_only && deal_ge_50) {
      rating = "A+";
      reason = "A+_no_vc_tech_not_svc_not_consumer_signal_ge_50";
    } else if (accelerator && !vc && tech && !service_provider && deal_ge_50) {
      rating = "A+";
      reason = "A+_accel_not_vc_tech_not_svc_signal_ge_50";

    // A paths
    } else if (accelerator && vc && tech && !service_provider && !deal_ge_50) {
      rating = "A";
      reason = "A_accel_vc_tech_not_svc_signal_lt_50";
    } else if (!accelerator && vc && tech && !service_provider && !consumer_only && !deal_ge_50) {
      rating = "A";
      reason = "A_vc_tech_not_svc_not_consumer_signal_lt_50";
    } else if (!accelerator && !vc && tech && !service_provider && !consumer_only && !deal_ge_50) {
      rating = "A";
      reason = "A_no_vc_tech_not_svc_not_consumer_signal_lt_50";
    } else if (accelerator && !vc && tech && !service_provider && !deal_ge_50) {
      rating = "A";
      reason = "A_accel_not_vc_tech_not_svc_signal_not_ge_50";

    // B paths
    } else if (accelerator && vc && tech && service_provider) {
      rating = "B";
      reason = "B_accel_vc_tech_service_provider";
    } else if (!accelerator && vc && tech && !service_provider && consumer_only && deal_ge_50) {
      rating = "B";
      reason = "B_vc_tech_not_svc_consumer_signal_ge_50";
    } else if (!accelerator && !vc && tech && !service_provider && consumer_only && deal_ge_50) {
      rating = "B";
      reason = "B_no_vc_tech_not_svc_consumer_signal_ge_50";
    } else if (!accelerator && !vc && !tech && !service_provider && !consumer_only && deal_ge_50) {
      rating = "B";
      reason = "B_no_vc_no_tech_not_svc_not_consumer_signal_ge_50";

    // C paths
    } else if (accelerator && !vc && !tech) {
      rating = "C";
      reason = "C_accel_no_vc_no_tech";
    } else if (accelerator && !vc && tech && service_provider) {
      rating = "C";
      reason = "C_accel_no_vc_tech_svc";
    } else if (accelerator && vc && !tech) {
      rating = "C";
      reason = "C_accel_vc_no_tech";
    } else if (!accelerator && vc && !tech) {
      rating = "C";
      reason = "C_vc_no_tech";
    } else if (!accelerator && vc && tech && service_provider) {
      rating = "C";
      reason = "C_vc_tech_service_provider";
    } else if (!accelerator && vc && tech && !service_provider && consumer_only && !deal_gt_50) {
      rating = "C";
      reason = "C_vc_tech_not_svc_consumer_signal_le_50";
    } else if (!accelerator && !vc && tech && service_provider) {
      rating = "C";
      reason = "C_no_vc_tech_service_provider";
    } else if (!accelerator && !vc && tech && !service_provider && consumer_only && !deal_gt_50) {
      rating = "C";
      reason = "C_no_vc_tech_not_svc_consumer_signal_le_50";
    } else if (!accelerator && !vc && !tech && !service_provider && consumer_only && deal_gt_50) {
      rating = "C";
      reason = "C_no_vc_no_tech_not_svc_consumer_signal_gt_50";
    } else if (!accelerator && !vc && !tech && !service_provider && !consumer_only && !deal_gt_50) {
      rating = "C";
      reason = "C_no_vc_no_tech_not_svc_not_consumer_signal_le_50";

    // Explicit D paths
    } else if (!accelerator && !vc && !tech && service_provider) {
      rating = "D";
      reason = "D_no_vc_no_tech_service_provider";
    } else if (!accelerator && !vc && !tech && !service_provider && consumer_only && !deal_gt_50) {
      rating = "D";
      reason = "D_no_vc_no_tech_not_svc_consumer_signal_le_50";
    } else {
      rating = "D";
      reason = "does_not_meet_startup_criteria";
    }
  }

  return {
    rating_letter: rating,
    reason: reason,
    flags: {
      tech: tech,
      vc: vc,
      accelerator: accelerator,
      gov_nonprofit: gov_nonprofit,
      service_provider: service_provider,
      consumer_only: consumer_only
    },
    dealroom_signal_rating: deal_signal,
    deal_ge_50: deal_ge_50,
    deal_gt_50: deal_gt_50,
    tech_strength: tech_strength,
    matches: {
      tech_keyword: tech_kw,
      service_keyword: service_kw,
      consumer_keyword: consumer_kw,
      gov_keyword: gov_kw,
      accelerator_keyword: accel_kw,
      vc_from_funding: funded,
      vc_from_types: vc_from_types,
      vc_from_rounds: vc_from_rounds,
      vc_from_investors_present: vc_from_investors_present
    }
  };
$$;




select
  DEV_QUEBECTECH.UTIL.STARTUP_CLASSIFY_DEALROOM_V5(
    'example.com',
    'TestCo',
    'AI platform',
    'We build AI tools for enterprises',
    'Software',
    null,
    'AI; SaaS',
    'AI; SaaS',
    'Python; AWS',
    'venture capital',
    'seed',
    'Real Ventures',
    'Real Ventures',
    2.5::float,
    0.0::float,
    '65'
  ):"rating_letter"::string as rating;
