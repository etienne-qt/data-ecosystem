CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.V_HS_CLEAN AS
SELECT
  "ID de fiche d'informations"::NUMBER(38,0)                    AS HS_COMPANY_ID,
  "Nom de l'entreprise"                                         AS HS_NAME_RAW,
  UTIL.NORM_NAME("Nom de l'entreprise")                         AS HS_NAME_NORM,

  URL_DU_SITE_WEB                                               AS HS_WEBSITE_RAW,
  UTIL.NORM_DOMAIN(URL_DU_SITE_WEB)                             AS HS_DOMAIN_FROM_WEBSITE,

  "Nom de domaine de l'entreprise"                              AS HS_DOMAIN_RAW,
  UTIL.NORM_DOMAIN("Nom de domaine de l'entreprise")            AS HS_DOMAIN_NORM,

  "Page d'entreprise LinkedIn"                                  AS HS_LINKEDIN_RAW,
  UTIL.NORM_LINKEDIN("Page d'entreprise LinkedIn")              AS HS_LINKEDIN_NORM,

  IDENTIFIANT_LINKEDIN                                          AS HS_LINKEDIN_ID_RAW,
  UTIL.NORM_LINKEDIN(IDENTIFIANT_LINKEDIN)                      AS HS_LINKEDIN_ID_NORM,

  "(NEQ) Numéro d'entreprise du Québec"                          AS HS_NEQ_RAW,
  UTIL.NORM_NEQ("(NEQ) Numéro d'entreprise du Québec")          AS HS_NEQ_NORM,

  -- dealroom properties currently stored in Hubspot
  "Dealroom - ID"                                               AS HS_DEALROOM_ID_RAW,
  "Dealroom - Profile URL"                                      AS HS_DEALROOM_URL_RAW,
  "Dealroom - Website"                                          AS HS_DEALROOM_WEBSITE_RAW,
  "Dealroom - LinkedIn"                                         AS HS_DEALROOM_LINKEDIN_RAW
FROM DEV_QUEBECTECH.IMPORT.HS_COMPANY_RAW;
