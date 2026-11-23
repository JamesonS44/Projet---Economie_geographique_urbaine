# 01_donnees.R : import et nettoyage des données

library(sf)
library(dplyr)
library(data.table)
library(osmdata)
library(jsonlite)

# 1. Paramètres
# Couches finales en Lambert 93 (EPSG:2154, en mètres)

date_analyse <- as.Date("2026-09-30")
bbox_nm <- c(xmin = -1.75, ymin = 47.10, xmax = -1.40, ymax = 47.35)

# Colonne texte "latitude, longitude" -> points Lambert 93
texte_en_points <- function(donnees, colonne) {
  coord <- strsplit(donnees[[colonne]], ",")
  donnees$lat <- as.numeric(sapply(coord, function(x) x[1]))
  donnees$lon <- as.numeric(sapply(coord, function(x) x[2]))

  # Points en GPS (WGS84) puis passage en Lambert 93
  points <- st_as_sf(donnees, coords = c("lon", "lat"), crs = 4326)
  st_transform(points, 2154)
}

# 2. Communes
communes <- st_read("data/raw/communes_nm.geojson", quiet = TRUE)
communes <- st_transform(communes, 2154)
contour <- st_union(communes) # contour de la métropole

print(nrow(communes))  # nombre de communes
# On doit trouver les 24 communes de la métropole

# 3. Restaurants SIRENE
# Colonnes utiles : siret, dates, commune, état, NAF, coordonnées
sirene <- fread("data/raw/base_sirene.csv", sep = ";", encoding = "UTF-8",
                select = c(3, 5, 22, 42, 47, 105, 107))
sirene <- as.data.frame(sirene)
names(sirene) <- c("siret", "creation", "commune", "etat", "naf", "fermeture", "geo")

# Restauration traditionnelle (56.10A) et rapide (56.10C)
resto <- sirene[sirene$naf %in% c("56.10A", "56.10C"), ]
print(nrow(resto))  # restaurants NAF 56.10A/C

# On enlève les établissements sans coordonnées
resto <- resto[resto$geo != "", ]
print(nrow(resto))  # avec coordonnées

# Actif au 30/09/2026 ; "Fermé" sans date de fermeture = fermé
resto$actif <- resto$creation <= date_analyse &
  (resto$etat == "Actif" | (!is.na(resto$fermeture) & resto$fermeture > date_analyse))

print(sum(resto$actif))  # actifs à la date d'analyse

# Points et découpage sur la métropole
resto_sirene <- texte_en_points(resto, "geo")
resto_sirene <- st_filter(resto_sirene, contour)

print(c(total = nrow(resto_sirene), actifs = sum(resto_sirene$actif)))  # dans Nantes Métropole
# 6 598 restaurants dont 2 268 actifs (variable Y). Les 4 330 fermés sont gardés
# pour une éventuelle piste panel (ouvertures).

# 4. Grille de 200 m et population
# Grille INSEE refaite en projection européenne (EPSG:3035)
communes_3035 <- st_transform(communes, 3035)
limites <- st_bbox(communes_3035)
depart <- c(floor(limites["xmin"] / 200) * 200, floor(limites["ymin"] / 200) * 200)

grille <- st_make_grid(communes_3035, cellsize = 200, offset = depart)
grille <- st_sf(geometry = grille)

# Carreaux dont le centre est dans la métropole
centres <- st_centroid(grille)
dedans <- lengths(st_within(centres, st_union(communes_3035))) > 0
grille <- grille[dedans, ]

# Identifiant INSEE du carreau (coin sud-ouest)
coords_centres <- st_coordinates(st_centroid(grille))
grille$id <- paste0("CRS3035RES200mN", coords_centres[, "Y"] - 100, "E", coords_centres[, "X"] - 100)
print(nrow(grille))  # carreaux de 200 m

# Population Filosofi, lue seulement sur l'emprise de la métropole
zone <- st_as_text(st_as_sfc(st_bbox(communes)))
filo <- st_read("data/raw/Filosofi2019_carreaux_200m_gpkg/carreaux_200m_met.gpkg",
                wkt_filter = zone, quiet = TRUE)
filo <- st_drop_geometry(filo)
filo <- filo[, c("idcar_200m", "ind", "i_est_200")]
names(filo) <- c("id", "population", "imputé")

# Carreau absent de Filosofi = inhabité (population 0)
carreaux <- merge(grille, filo, by = "id", all.x = TRUE)
carreaux$habité <- !is.na(carreaux$population)
carreaux$population[is.na(carreaux$population)] <- 0
carreaux <- st_transform(carreaux, 2154)

print(sum(carreaux$habité))  # carreaux habités (Filosofi)
# 6 681 carreaux habités sur 13 384. On garde les inhabités pour ne pas perdre
# les zones commerciales ou touristiques sans habitants.

# 5. Restaurants OSM
requete_resto <- opq(bbox_nm, timeout = 120) |>
  add_osm_feature("amenity", c("restaurant", "fast_food"))

osm_r <- osmdata_sf(requete_resto, doc = "data/raw/osm_restaurants.osm")
pts_r <- osm_r$osm_points[!is.na(osm_r$osm_points$amenity), c("osm_id", "name", "amenity")]
poly_r <- st_centroid(osm_r$osm_polygons[, c("osm_id", "name", "amenity")])

resto_osm <- rbind(pts_r, poly_r)
resto_osm <- resto_osm[resto_osm$amenity %in% c("restaurant", "fast_food"), ]
resto_osm <- st_transform(resto_osm, 2154)
resto_osm <- st_filter(resto_osm, contour)

print(nrow(resto_osm))  # restaurants OSM dans le contour
# 1 292 restaurants OSM (57 % de SIRENE actif), moins bien couverts hors centre :
# OSM sert seulement en robustesse.

# 6. Sites touristiques

# 6.1 Sites OSM
requete_sites <- opq(bbox_nm, timeout = 120) |>
  add_osm_features(list(
    tourism = c("museum", "attraction", "gallery"),
    historic = c("monument", "castle", "memorial")
  ))

osm_s <- osmdata_sf(requete_sites, doc = "data/raw/osm_sites.osm")
pts_s <- osm_s$osm_points[!is.na(osm_s$osm_points$tourism) | !is.na(osm_s$osm_points$historic),
                           c("osm_id", "name", "tourism", "historic")]
poly_s <- st_centroid(osm_s$osm_polygons[, c("osm_id", "name", "tourism", "historic")])

sites_osm <- rbind(pts_s, poly_s)
sites_osm <- st_transform(sites_osm, 2154)
sites_osm <- st_filter(sites_osm, contour)

sites_osm <- data.frame(
  nom = sites_osm$name,
  source = "OSM",
  type = ifelse(is.na(sites_osm$tourism), sites_osm$historic, sites_osm$tourism),
  memorial = sites_osm$historic %in% "memorial",
  geometry = st_geometry(sites_osm)
)
print(c(sites = nrow(sites_osm), memoriaux = sum(sites_osm$memorial)))  # sites OSM
# 396 des 566 sites OSM sont des mémoriaux (plaques, stèles) : exclus en principal,
# remis en robustesse.

# 6.2 Mérimée
merimee <- fread("data/raw/merimee.csv", sep = "|", encoding = "UTF-8")
merimee <- as.data.frame(merimee)
merimee <- merimee[merimee$COG_Insee_lors_de_la_protection %in% communes$code, ]
merimee <- merimee[, c("Reference", "Titre_editorial_de_la_notice", "Adresse_forme_index",
                       "Commune_forme_index", "Siecle_de_la_campagne_principale_de_construction",
                       "coordonnees_au_format_WGS84")]
names(merimee) <- c("ref", "nom", "adresse", "commune", "siecle", "geo")

print(c(monuments = nrow(merimee), sans_coord = sum(merimee$geo == "")))  # Mérimée

# Monuments sans coordonnées : géocodage avec la Base Adresse Nationale
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
    Sys.sleep(0.1) # pause pour ne pas surcharger l'API
  }
  write.csv(a_geocoder, "data/raw/merimee_geocodage.csv", row.names = FALSE)
}

# On garde les adresses géocodées avec un score >= 0,5
geocodage <- read.csv("data/raw/merimee_geocodage.csv")
geocodage <- geocodage[!is.na(geocodage$score) & geocodage$score >= 0.5, ]

merimee$geocode <- merimee$ref %in% geocodage$ref
merimee$geo[merimee$geocode] <- geocodage$geo_ban[match(merimee$ref[merimee$geocode], geocodage$ref)]
merimee <- merimee[merimee$geo != "", ]

# Ancien = construit avant 1800 (18e siècle ou avant)
premier_siecle <- suppressWarnings(as.numeric(sub(".*?([0-9]+)e? siècle.*", "\\1", merimee$siecle, perl = TRUE)))
merimee$ancien <- premier_siecle <= 18 | grepl("Gallo|Moyen Age|Néolithique", merimee$siecle)
merimee$ancien[merimee$siecle == ""] <- NA

merimee <- texte_en_points(merimee, "geo")
merimee <- st_filter(merimee, contour)
print(c(retenus = nrow(merimee), anciens = sum(merimee$ancien, na.rm = TRUE)))  # Mérimée, anciens = avant 1800
# Le géocodage récupère presque tous les monuments sans coordonnées : 148 retenus,
# dont 113 d'avant 1800 (variante « sites anciens »).

# 6.3 Muséofile
museofile <- fread("data/raw/museofile.csv", encoding = "UTF-8")
museofile <- as.data.frame(museofile)
museofile <- museofile[museofile$Departement == "Loire-Atlantique" & museofile$Coordonnees != "", ]
museofile <- texte_en_points(museofile, "Coordonnees")
museofile <- st_filter(museofile, contour)
print(nrow(museofile))  # musées Muséofile

# 6.4 Département 44
sites_44 <- st_drop_geometry(st_read("data/raw/sites_44.geojson", quiet = TRUE))
sites_44 <- st_as_sf(sites_44, coords = c("longitude", "latitude"), crs = 4326)
sites_44 <- st_transform(sites_44, 2154)
sites_44 <- st_filter(sites_44, contour)
print(nrow(sites_44))  # sites du Département 44

# 6.5 Fusion des 4 sources
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
# 736 sites au total (340 sans les mémoriaux). Les bases publiques complètent
# les oublis d'OSM.

# 7. Fréquentation des lieux
freq <- fread("data/raw/frequentation_lieux_44.csv", sep = ";", encoding = "UTF-8")
freq <- as.data.frame(freq)
names(freq) <- c("annee", "nom", "commune", "type", "entrees", "geo")

freq <- texte_en_points(freq, "geo")
freq <- st_filter(freq, contour)

print(c(lieux = length(unique(freq$nom)), observations = nrow(freq)))  # fréquentation lieu x année
# 16 lieux suivis sur 12 ans : mesure directe de l'affluence, utilisée pour
# le potentiel de fréquentation (04).

# 8. Sauvegarde
st_write(communes, "data/clean/communes.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(carreaux, "data/clean/carreaux.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(resto_sirene, "data/clean/resto_sirene.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(resto_osm, "data/clean/resto_osm.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(sites, "data/clean/sites.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(freq, "data/clean/frequentation_lieux.gpkg", delete_dsn = TRUE, quiet = TRUE)
