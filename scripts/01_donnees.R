# ==============================================================================
# Script 01 : Importation, nettoyage et mise en forme des données spatiales
# Projet : Localisation des restaurants et sites touristiques à Nantes Métropole
# Auteurs : Jameson Saussereau & Nassim Ikhelef (M2 ECAP - IAE Nantes)
# ==============================================================================

library(sf)          # Manipulation des données spatiales (vecteurs)
library(dplyr)       # Manipulation de tables
library(data.table)  # Lecture rapide des gros fichiers CSV (fread)
library(osmdata)     # Extraction des données OpenStreetMap
library(jsonlite)    # Lecture des réponses JSON de l'API Adresse (BAN)

# ------------------------------------------------------------------------------
# 1. Paramètres généraux et fonction utilitaire
# ------------------------------------------------------------------------------
# Les fichiers bruts sont dans data/raw (sources et dates dans DATES.txt).
# Toutes les couches finales sont projetées en Lambert 93 (EPSG:2154, en mètres).

date_analyse <- as.Date("2026-09-30")
bbox_nm      <- c(xmin = -1.75, ymin = 47.10, xmax = -1.40, ymax = 47.35)

# Convertit une colonne texte "latitude, longitude" en points Lambert 93
texte_en_points <- function(donnees, colonne) {
  coord <- strsplit(donnees[[colonne]], ",")
  donnees$lat <- as.numeric(sapply(coord, function(x) x[1]))
  donnees$lon <- as.numeric(sapply(coord, function(x) x[2]))

  # Création des points en WGS84 (GPS) puis reprojection en Lambert 93
  points <- st_as_sf(donnees, coords = c("lon", "lat"), crs = 4326)
  st_transform(points, 2154)
}

# ------------------------------------------------------------------------------
# 2. Contours des 24 communes de Nantes Métropole
# ------------------------------------------------------------------------------
communes <- st_read("data/raw/communes_nm.geojson", quiet = TRUE)
communes <- st_transform(communes, 2154)
contour  <- st_union(communes) # Contour extérieur global de la métropole

cat("Nombre de communes :", nrow(communes), "\n")
# On vérifie que l'EPCI complet (24 communes) est bien chargé pour délimiter la zone d'étude.

# ------------------------------------------------------------------------------
# 3. Restaurants (Base SIRENE - INSEE)
# ------------------------------------------------------------------------------
# Lecture des colonnes utiles (siret, dates, commune, état, NAF, coordonnées)
sirene <- fread("data/raw/base_sirene.csv", sep = ";", encoding = "UTF-8",
                select = c(3, 5, 22, 42, 47, 105, 107))
sirene <- as.data.frame(sirene)
names(sirene) <- c("siret", "creation", "commune", "etat", "naf", "fermeture", "geo")

# Sélection de la restauration traditionnelle (56.10A) et rapide (56.10C)
resto <- sirene[sirene$naf %in% c("56.10A", "56.10C"), ]
cat("Restaurants NAF 56.10A/C :", nrow(resto), "\n")

# Suppression des établissements sans géolocalisation
resto <- resto[resto$geo != "", ]
cat("Avec coordonnées :", nrow(resto), "\n")

# Indicatrice d'activité au 30/09/2026 : un établissement marqué "Fermé" sans date
# de fermeture renseignée est considéré comme fermé.
resto$actif <- resto$creation <= date_analyse &
  (resto$etat == "Actif" | (!is.na(resto$fermeture) & resto$fermeture > date_analyse))

cat("Actifs au", format(date_analyse), ":", sum(resto$actif), "\n")

# Conversion en points spatiaux et découpage sur Nantes Métropole
resto_sirene <- texte_en_points(resto, "geo")
resto_sirene <- st_filter(resto_sirene, contour)

cat("Dans Nantes Métropole :", nrow(resto_sirene), "dont actifs :", sum(resto_sirene$actif), "\n")
# Sur 6 598 restaurants géolocalisés au total, 2 268 sont actifs à la date d'analyse
# (variable Y principale). On conserve les 4 330 fermés pour reconstituer les ouvertures en panel.

# ------------------------------------------------------------------------------
# 4. Grille carroyée de 200 m et population (Filosofi 2019 - INSEE)
# ------------------------------------------------------------------------------
# Reconstitution de la grille officielle INSEE en projection européenne (EPSG:3035)
communes_3035 <- st_transform(communes, 3035)
limites       <- st_bbox(communes_3035)
depart        <- c(floor(limites["xmin"] / 200) * 200, floor(limites["ymin"] / 200) * 200)

grille <- st_make_grid(communes_3035, cellsize = 200, offset = depart)
grille <- st_sf(geometry = grille)

# On ne garde que les carreaux dont le centre tombe dans Nantes Métropole
centres <- st_centroid(grille)
dedans  <- lengths(st_within(centres, st_union(communes_3035))) > 0
grille  <- grille[dedans, ]

# Identifiant officiel INSEE de chaque carreau (coordonnées du coin sud-ouest)
coords_centres <- st_coordinates(st_centroid(grille))
grille$id <- paste0("CRS3035RES200mN", coords_centres[, "Y"] - 100, "E", coords_centres[, "X"] - 100)
cat("Nombre total de carreaux de 200 m :", nrow(grille), "\n")

# Lecture des données de population Filosofi filtrées sur l'emprise de la métropole
zone <- st_as_text(st_as_sfc(st_bbox(communes)))
filo <- st_read("data/raw/Filosofi2019_carreaux_200m_gpkg/carreaux_200m_met.gpkg",
                wkt_filter = zone, quiet = TRUE)
filo <- st_drop_geometry(filo)
filo <- filo[, c("idcar_200m", "ind", "i_est_200")]
names(filo) <- c("id", "population", "imputé")

# Jointure avec la grille complète : les carreaux absents de Filosofi sont inhabités (pop = 0)
carreaux <- merge(grille, filo, by = "id", all.x = TRUE)
carreaux$habité <- !is.na(carreaux$population)
carreaux$population[is.na(carreaux$population)] <- 0
carreaux <- st_transform(carreaux, 2154)

cat("Carreaux habités (Filosofi) :", sum(carreaux$habité), "\n")
# Environ la moitié des 13 384 carreaux est habitée (6 681 carreaux). Garder les carreaux
# inhabités (pop = 0) évite de perdre les zones commerciales ou touristiques sans résidents.

# ------------------------------------------------------------------------------
# 5. Restaurants OpenStreetMap (source alternative pour la robustesse)
# ------------------------------------------------------------------------------
requete_resto <- opq(bbox_nm, timeout = 120) |>
  add_osm_feature("amenity", c("restaurant", "fast_food"))

osm_r  <- osmdata_sf(requete_resto, doc = "data/raw/osm_restaurants.osm")
pts_r  <- osm_r$osm_points[!is.na(osm_r$osm_points$amenity), c("osm_id", "name", "amenity")]
poly_r <- st_centroid(osm_r$osm_polygons[, c("osm_id", "name", "amenity")])

resto_osm <- rbind(pts_r, poly_r)
resto_osm <- resto_osm[resto_osm$amenity %in% c("restaurant", "fast_food"), ]
resto_osm <- st_transform(resto_osm, 2154)
resto_osm <- st_filter(resto_osm, contour)

cat("Restaurants OSM dans le contour :", nrow(resto_osm), "\n")
# OSM recense 1 292 établissements (57 % du stock SIRENE actif), avec une sous-couverture
# marquée hors centre-ville : cette source servira uniquement en test de robustesse.

# ------------------------------------------------------------------------------
# 6. Sites touristiques et patrimoniaux (4 sources combinées)
# ------------------------------------------------------------------------------

# 6.1 Sites issus d'OpenStreetMap (musées, attractions, monuments, mémoriaux)
requete_sites <- opq(bbox_nm, timeout = 120) |>
  add_osm_features(list(
    tourism  = c("museum", "attraction", "gallery"),
    historic = c("monument", "castle", "memorial")
  ))

osm_s  <- osmdata_sf(requete_sites, doc = "data/raw/osm_sites.osm")
pts_s  <- osm_s$osm_points[!is.na(osm_s$osm_points$tourism) | !is.na(osm_s$osm_points$historic),
                           c("osm_id", "name", "tourism", "historic")]
poly_s <- st_centroid(osm_s$osm_polygons[, c("osm_id", "name", "tourism", "historic")])

sites_osm <- rbind(pts_s, poly_s)
sites_osm <- st_transform(sites_osm, 2154)
sites_osm <- st_filter(sites_osm, contour)

sites_osm <- data.frame(
  nom      = sites_osm$name,
  source   = "OSM",
  type     = ifelse(is.na(sites_osm$tourism), sites_osm$historic, sites_osm$tourism),
  memorial = sites_osm$historic %in% "memorial",
  geometry = st_geometry(sites_osm)
)
cat("Sites OSM :", nrow(sites_osm), "dont mémoriaux :", sum(sites_osm$memorial), "\n")
# 70 % des sites OSM (396 sur 566) sont des mémoriaux (plaques, stèles) : l'indicatrice
# permet de les écarter en spécification principale et de les réintégrer en robustesse.

# 6.2 Monuments historiques (Base Mérimée)
merimee <- fread("data/raw/merimee.csv", sep = "|", encoding = "UTF-8")
merimee <- as.data.frame(merimee)
merimee <- merimee[merimee$COG_Insee_lors_de_la_protection %in% communes$code, ]
merimee <- merimee[, c("Reference", "Titre_editorial_de_la_notice", "Adresse_forme_index",
                       "Commune_forme_index", "Siecle_de_la_campagne_principale_de_construction",
                       "coordonnees_au_format_WGS84")]
names(merimee) <- c("ref", "nom", "adresse", "commune", "siecle", "geo")

cat("Monuments Mérimée :", nrow(merimee), "dont sans coordonnées :", sum(merimee$geo == ""), "\n")

# Géocodage via la Base Adresse Nationale (BAN) pour les monuments sans coordonnées
if (!file.exists("data/raw/merimee_geocodage.csv")) {
  a_geocoder <- merimee[merimee$geo == "" & merimee$adresse != "", c("ref", "adresse", "commune")]
  adresse <- sub(" ;.*", "", a_geocoder$adresse)
  adresse <- sub("^(.*) \\((.*)\\) ?([0-9]*).*$", "\\3 \\2 \\1", adresse)
  commune <- sub("^(.*) \\((.*)\\)$", "\\2 \\1", a_geocoder$commune)

  a_geocoder$recherche <- trimws(paste(adresse, commune))
  a_geocoder$geo_ban   <- ""
  a_geocoder$score     <- NA

  for (i in seq_len(nrow(a_geocoder))) {
    url <- paste0("https://api-adresse.data.gouv.fr/search/?limit=1&q=",
                  URLencode(a_geocoder$recherche[i], reserved = TRUE))
    reponse <- fromJSON(url)
    if (length(reponse$features) > 0) {
      xy <- reponse$features$geometry$coordinates[[1]]
      a_geocoder$geo_ban[i] <- paste0(xy[2], ", ", xy[1])
      a_geocoder$score[i]   <- reponse$features$properties$score
    }
    Sys.sleep(0.1) # Pause courte pour respecter l'API
  }
  write.csv(a_geocoder, "data/raw/merimee_geocodage.csv", row.names = FALSE)
}

# Intégration des adresses géocodées avec un score de confiance suffisant (>= 0.5)
geocodage <- read.csv("data/raw/merimee_geocodage.csv")
geocodage <- geocodage[!is.na(geocodage$score) & geocodage$score >= 0.5, ]

merimee$geocode <- merimee$ref %in% geocodage$ref
merimee$geo[merimee$geocode] <- geocodage$geo_ban[match(merimee$ref[merimee$geocode], geocodage$ref)]
merimee <- merimee[merimee$geo != "", ]

# Indicatrice "ancien" : construction antérieure à 1800 (18e siècle ou avant)
premier_siecle <- suppressWarnings(as.numeric(sub(".*?([0-9]+)e? siècle.*", "\\1", merimee$siecle, perl = TRUE)))
merimee$ancien <- premier_siecle <= 18 | grepl("Gallo|Moyen Age|Néolithique", merimee$siecle)
merimee$ancien[merimee$siecle == ""] <- NA

merimee <- texte_en_points(merimee, "geo")
merimee <- st_filter(merimee, contour)
cat("Monuments Mérimée retenus :", nrow(merimee), "dont anciens (< 1800) :", sum(merimee$ancien, na.rm = TRUE), "\n")
# Le géocodage BAN récupère la quasi-totalité des monuments sans coordonnées initiales
# (148 retenus), dont 113 bâtis avant 1800 utilisés pour la variante « monuments anciens ».

# 6.3 Musées de France (Base Muséofile)
museofile <- fread("data/raw/museofile.csv", encoding = "UTF-8")
museofile <- as.data.frame(museofile)
museofile <- museofile[museofile$Departement == "Loire-Atlantique" & museofile$Coordonnees != "", ]
museofile <- texte_en_points(museofile, "Coordonnees")
museofile <- st_filter(museofile, contour)
cat("Musées Muséofile :", nrow(museofile), "\n")

# 6.4 Sites patrimoniaux et culturels du Département 44
sites_44 <- st_drop_geometry(st_read("data/raw/sites_44.geojson", quiet = TRUE))
sites_44 <- st_as_sf(sites_44, coords = c("longitude", "latitude"), crs = 4326)
sites_44 <- st_transform(sites_44, 2154)
sites_44 <- st_filter(sites_44, contour)
cat("Sites Département 44 :", nrow(sites_44), "\n")

# 6.5 Fusion des 4 sources de sites en une couche unique
sites <- rbind(
  sites_osm,
  data.frame(nom = merimee$nom, source = "Mérimée", type = "monument historique",
             memorial = FALSE, geometry = st_geometry(merimee)),
  data.frame(nom = museofile$Nom_officiel, source = "Muséofile", type = "museum",
             memorial = FALSE, geometry = st_geometry(museofile)),
  data.frame(nom = sites_44$raison_sociale, source = "Département 44", type = sites_44$type_1,
             memorial = FALSE, geometry = st_geometry(sites_44))
)

sites$ancien <- NA
sites$ancien[sites$source == "Mérimée"] <- merimee$ancien
sites <- st_as_sf(sites)

print(table(sites$source))
# On obtient 736 sites au total (340 hors mémoriaux) en croisant OSM avec les bases
# publiques (Mérimée, Muséofile, Département 44) pour éviter les oublis patrimoniaux.

# ------------------------------------------------------------------------------
# 7. Fréquentation annuelle des lieux de visite (2009-2020)
# ------------------------------------------------------------------------------
freq <- fread("data/raw/frequentation_lieux_44.csv", sep = ";", encoding = "UTF-8")
freq <- as.data.frame(freq)
names(freq) <- c("annee", "nom", "commune", "type", "entrees", "geo")

freq <- texte_en_points(freq, "geo")
freq <- st_filter(freq, contour)

cat("Fréquentation :", length(unique(freq$nom)), "lieux,", nrow(freq), "observations lieu x année\n")
# Ce suivi longitudinal sur 12 ans (16 lieux majeurs) fournit une mesure directe
# de l'affluence touristique pour estimer un modèle en panel sur les ouvertures de restaurants.

# ------------------------------------------------------------------------------
# 8. Sauvegarde des couches propres au format GeoPackage (.gpkg)
# ------------------------------------------------------------------------------
st_write(communes,     "data/clean/communes.gpkg",            delete_dsn = TRUE, quiet = TRUE)
st_write(carreaux,     "data/clean/carreaux.gpkg",            delete_dsn = TRUE, quiet = TRUE)
st_write(resto_sirene, "data/clean/resto_sirene.gpkg",        delete_dsn = TRUE, quiet = TRUE)
st_write(resto_osm,    "data/clean/resto_osm.gpkg",           delete_dsn = TRUE, quiet = TRUE)
st_write(sites,        "data/clean/sites.gpkg",               delete_dsn = TRUE, quiet = TRUE)
st_write(freq,         "data/clean/frequentation_lieux.gpkg", delete_dsn = TRUE, quiet = TRUE)

cat("Toutes les couches propres ont été enregistrées dans data/clean/.\n")