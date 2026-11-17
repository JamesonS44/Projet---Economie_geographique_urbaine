library(sf)
library(dplyr)
library(data.table)
library(osmdata)
library(jsonlite)

# Les fichiers bruts sont dans data/raw (sources et dates dans DATES.txt).
# Ce script les lit, les nettoie et écrit les couches propres dans data/clean.
# Toutes les couches propres sont en Lambert 93 (EPSG 2154).

date_analyse <- as.Date("2026-09-30")
bbox_nm <- c(xmin = -1.75, ymin = 47.10, xmax = -1.40, ymax = 47.35)

# contour des communes de Nantes Métropole
# download.file("https://geo.api.gouv.fr/communes?codeEpci=244400404&format=geojson&geometry=contour&fields=nom,code",
#               "data/raw/communes_nm.geojson", mode = "wb")
communes <- st_read("data/raw/communes_nm.geojson")
communes <- st_transform(communes, 2154)
contour <- st_union(communes)
cat("communes :", nrow(communes), "\n")

# transforme un texte "lat, lon" en points Lambert 93
texte_en_points <- function(donnees, colonne) {
  coord <- strsplit(donnees[[colonne]], ",")
  donnees$lat <- as.numeric(sapply(coord, function(x) x[1]))
  donnees$lon <- as.numeric(sapply(coord, function(x) x[2]))
  points <- st_as_sf(donnees, coords = c("lon", "lat"), crs = 4326)
  st_transform(points, 2154)
}

# restaurants SIRENE
# on garde tous les restaurants (actifs et fermés) pour le panel,
# la colonne actif indique ceux ouverts à la date d'analyse
sirene <- fread("data/raw/base_sirene.csv", sep = ";", encoding = "UTF-8",
                select = c(3, 5, 22, 42, 47, 105, 107))
sirene <- as.data.frame(sirene)
names(sirene) <- c("siret", "creation", "commune", "etat", "naf", "fermeture", "geo")

resto <- sirene[sirene$naf %in% c("56.10A", "56.10C"), ]
cat("restaurants NAF 56.10A/C :", nrow(resto), "\n")

resto <- resto[resto$geo != "", ]
cat("avec coordonnées :", nrow(resto), "\n")

# un établissement « Fermé » sans date de fermeture est compté comme fermé
resto$actif <- resto$creation <= date_analyse &
  (resto$etat == "Actif" | (!is.na(resto$fermeture) & resto$fermeture > date_analyse))
cat("actifs au", format(date_analyse), ":", sum(resto$actif), "\n")

resto_sirene <- texte_en_points(resto, "geo")
resto_sirene <- st_filter(resto_sirene, contour)
cat("dans le contour :", nrow(resto_sirene), "dont actifs", sum(resto_sirene$actif), "\n")

# grille de 200 m alignée sur celle de l'INSEE (EPSG 3035)
communes_3035 <- st_transform(communes, 3035)
limites <- st_bbox(communes_3035)
depart <- c(floor(limites["xmin"] / 200) * 200, floor(limites["ymin"] / 200) * 200)
grille <- st_make_grid(communes_3035, cellsize = 200, offset = depart)
grille <- st_sf(geometry = grille)
centres <- st_centroid(grille)
dedans <- lengths(st_within(centres, st_union(communes_3035))) > 0
grille <- grille[dedans, ]
centres <- st_coordinates(st_centroid(grille))
grille$id <- paste0("CRS3035RES200mN", centres[, "Y"] - 100, "E", centres[, "X"] - 100)
cat("carreaux de la grille :", nrow(grille), "\n")

# population par carreau (Filosofi 2019)
zone <- st_as_text(st_as_sfc(st_bbox(communes)))
filo <- st_read("data/raw/Filosofi2019_carreaux_200m_gpkg/carreaux_200m_met.gpkg",
                wkt_filter = zone)
filo <- st_drop_geometry(filo)
filo <- filo[, c("idcar_200m", "ind", "i_est_200")]
names(filo) <- c("id", "population", "imputé")

carreaux <- merge(grille, filo, by = "id", all.x = TRUE)
cat("carreaux avec population Filosofi :", sum(!is.na(carreaux$population)), "\n")
carreaux$habité <- !is.na(carreaux$population)
carreaux$population[is.na(carreaux$population)] <- 0
carreaux <- st_transform(carreaux, 2154)

# restaurants OSM (extraction faite une fois le 17/11/2026)
requete <- opq(bbox_nm, timeout = 120) |>
  add_osm_feature("amenity", c("restaurant", "fast_food"))
# osmdata_xml(requete, filename = "data/raw/osm_restaurants.osm")
osm <- osmdata_sf(requete, doc = "data/raw/osm_restaurants.osm")
points <- osm$osm_points[!is.na(osm$osm_points$amenity), c("osm_id", "name", "amenity")]
polygones <- st_centroid(osm$osm_polygons[, c("osm_id", "name", "amenity")])
resto_osm <- rbind(points, polygones)
resto_osm <- resto_osm[resto_osm$amenity %in% c("restaurant", "fast_food"), ]
resto_osm <- st_transform(resto_osm, 2154)
resto_osm <- st_filter(resto_osm, contour)
cat("restaurants OSM dans le contour :", nrow(resto_osm), "\n")

# sites touristiques OSM (extraction faite une fois le 17/11/2026)
requete <- opq(bbox_nm, timeout = 120) |>
  add_osm_features(list(tourism = c("museum", "attraction", "gallery"),
                        historic = c("monument", "castle", "memorial")))
# osmdata_xml(requete, filename = "data/raw/osm_sites.osm")
osm <- osmdata_sf(requete, doc = "data/raw/osm_sites.osm")
points <- osm$osm_points[!is.na(osm$osm_points$tourism) | !is.na(osm$osm_points$historic),
                         c("osm_id", "name", "tourism", "historic")]
polygones <- st_centroid(osm$osm_polygons[, c("osm_id", "name", "tourism", "historic")])
sites_osm <- rbind(points, polygones)
sites_osm <- st_transform(sites_osm, 2154)
sites_osm <- st_filter(sites_osm, contour)
sites_osm <- data.frame(nom = sites_osm$name,
                        source = "OSM",
                        type = ifelse(is.na(sites_osm$tourism), sites_osm$historic, sites_osm$tourism),
                        memorial = sites_osm$historic %in% "memorial",
                        geometry = st_geometry(sites_osm))
cat("sites OSM dans le contour :", nrow(sites_osm), "dont mémoriaux", sum(sites_osm$memorial), "\n")

# monuments historiques (Mérimée)
merimee <- fread("data/raw/merimee.csv", sep = "|", encoding = "UTF-8")
merimee <- as.data.frame(merimee)
merimee <- merimee[merimee$COG_Insee_lors_de_la_protection %in% communes$code, ]
merimee <- merimee[, c("Reference", "Titre_editorial_de_la_notice", "Adresse_forme_index",
                       "Commune_forme_index", "Siecle_de_la_campagne_principale_de_construction",
                       "coordonnees_au_format_WGS84")]
names(merimee) <- c("ref", "nom", "adresse", "commune", "siecle", "geo")
cat("monuments historiques :", nrow(merimee), "dont sans coordonnées", sum(merimee$geo == ""), "\n")

# géocodage des monuments sans coordonnées avec la Base Adresse Nationale (fait une fois)
# l'adresse Mérimée "Kervégan (rue) 32" devient "32 rue Kervégan"
if (!file.exists("data/raw/merimee_geocodage.csv")) {
  a_geocoder <- merimee[merimee$geo == "" & merimee$adresse != "", c("ref", "adresse", "commune")]
  adresse <- sub(" ;.*", "", a_geocoder$adresse)
  adresse <- sub("^(.*) \\((.*)\\) ?([0-9]*).*$", "\\3 \\2 \\1", adresse)
  commune <- sub("^(.*) \\((.*)\\)$", "\\2 \\1", a_geocoder$commune)
  a_geocoder$recherche <- trimws(paste(adresse, commune))
  a_geocoder$geo_ban <- ""
  a_geocoder$score <- NA
  for (i in seq_len(nrow(a_geocoder))) {
    url <- paste0("https://api-adresse.data.gouv.fr/search/?limit=1&q=",
                  URLencode(a_geocoder$recherche[i], reserved = TRUE))
    reponse <- fromJSON(url)
    if (length(reponse$features) > 0) {
      xy <- reponse$features$geometry$coordinates[[1]]
      a_geocoder$geo_ban[i] <- paste0(xy[2], ", ", xy[1])
      a_geocoder$score[i] <- reponse$features$properties$score
    }
    Sys.sleep(0.1)
  }
  write.csv(a_geocoder, "data/raw/merimee_geocodage.csv", row.names = FALSE)
}
geocodage <- read.csv("data/raw/merimee_geocodage.csv")
geocodage <- geocodage[!is.na(geocodage$score) & geocodage$score >= 0.5, ]
merimee$geocode <- merimee$ref %in% geocodage$ref
merimee$geo[merimee$geocode] <- geocodage$geo_ban[match(merimee$ref[merimee$geocode], geocodage$ref)]
merimee <- merimee[merimee$geo != "", ]
cat("monuments historiques localisés :", nrow(merimee), "dont géocodés", sum(merimee$geocode), "\n")

# monument ancien = campagne principale de construction avant 1800 (18e siècle ou avant)
# on prend le premier siècle cité ("3e quart 17e siècle;19e siècle" donne 17)
premier_siecle <- suppressWarnings(as.numeric(sub(".*?([0-9]+)e? siècle.*", "\\1", merimee$siecle, perl = TRUE)))
merimee$ancien <- premier_siecle <= 18 | grepl("Gallo|Moyen Age|Néolithique", merimee$siecle)
merimee$ancien[merimee$siecle == ""] <- NA
merimee <- texte_en_points(merimee, "geo")
merimee <- st_filter(merimee, contour)
cat("monuments anciens (avant 1800) :", sum(merimee$ancien, na.rm = TRUE), "\n")

# musées de France (Muséofile)
museofile <- fread("data/raw/museofile.csv", encoding = "UTF-8")
museofile <- as.data.frame(museofile)
museofile <- museofile[museofile$Departement == "Loire-Atlantique" & museofile$Coordonnees != "", ]
museofile <- texte_en_points(museofile, "Coordonnees")
museofile <- st_filter(museofile, contour)
cat("musées de France :", nrow(museofile), "\n")

# châteaux, monuments et musées du département (géométrie vide, coordonnées en colonnes)
sites_44 <- st_drop_geometry(st_read("data/raw/sites_44.geojson"))
sites_44 <- st_as_sf(sites_44, coords = c("longitude", "latitude"), crs = 4326)
sites_44 <- st_transform(sites_44, 2154)
sites_44 <- st_filter(sites_44, contour)
cat("sites du département :", nrow(sites_44), "\n")

# tous les sites dans une seule couche
# un même lieu peut venir de plusieurs sources : ça ne change pas la distance au site le plus proche
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

# fréquentation des lieux de visite (entrées par an, 2009-2020)
freq <- fread("data/raw/frequentation_lieux_44.csv", sep = ";", encoding = "UTF-8")
freq <- as.data.frame(freq)
names(freq) <- c("annee", "nom", "commune", "type", "entrees", "geo")
freq <- texte_en_points(freq, "geo")
freq <- st_filter(freq, contour)
cat("fréquentation :", length(unique(freq$nom)), "lieux,", nrow(freq), "lignes lieu x année,",
    sum(is.na(freq$entrees)), "entrées manquantes\n")

# sauvegarde
st_write(communes, "data/clean/communes.gpkg", delete_dsn = TRUE)
st_write(carreaux, "data/clean/carreaux.gpkg", delete_dsn = TRUE)
st_write(resto_sirene, "data/clean/resto_sirene.gpkg", delete_dsn = TRUE)
st_write(resto_osm, "data/clean/resto_osm.gpkg", delete_dsn = TRUE)
st_write(sites, "data/clean/sites.gpkg", delete_dsn = TRUE)
st_write(freq, "data/clean/frequentation_lieux.gpkg", delete_dsn = TRUE)
