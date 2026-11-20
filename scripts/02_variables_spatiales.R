# 02_variables_spatiales.R
# Variables du modèle par carreau de 200 m

library(sf)
library(dplyr)
library(spdep)

# Lecture des couches (toutes en Lambert 93, distances en mètres)
carreaux <- st_read("data/clean/carreaux.gpkg", quiet = TRUE)
sirene <- st_read("data/clean/resto_sirene.gpkg", quiet = TRUE)
osm <- st_read("data/clean/resto_osm.gpkg", quiet = TRUE)
sites <- st_read("data/clean/sites.gpkg", quiet = TRUE)

# On ne garde que les restaurants actifs au 30/09/2026
sirene <- filter(sirene, actif)
nrow(sirene)  # 2268 actifs

# On retire les adresses empilées : 5 restaurants ou plus au même point GPS.
# Ce sont des adresses de domiciliation (surtout restauration rapide créée en 2024-2026),
# pas de vrais restaurants (18 points, 186 établissements).
nb_meme_point <- table(sirene$geo)
sirene <- filter(sirene, geo %in% names(nb_meme_point)[nb_meme_point < 5])
nrow(sirene)  # 2082 attendus

# 1. Nombre de restaurants par carreau
carreaux$n_sirene <- lengths(st_intersects(carreaux, sirene))
carreaux$n_osm <- lengths(st_intersects(carreaux, osm))

# Vérifications
sum(carreaux$n_sirene)  # proche de 2082
sum(carreaux$n_osm)     # proche de 1292
mean(carreaux$n_sirene == 0)  # part des carreaux sans restaurant
summary(carreaux$n_sirene)

# 2. Distance (km) du centre du carreau au site le plus proche
centres <- st_centroid(st_geometry(carreaux))

dist_proche <- function(points, cibles) {
  proche <- st_nearest_feature(points, cibles)
  as.numeric(st_distance(points, cibles[proche, ], by_element = TRUE)) / 1000
}

carreaux$dist_site_tous <- dist_proche(centres, sites)
carreaux$dist_site_sans_mem <- dist_proche(centres, filter(sites, !memorial))
carreaux$dist_site_ancien <- dist_proche(centres, filter(sites, ancien))

summary(carreaux$dist_site_tous)
summary(carreaux$dist_site_sans_mem)
summary(carreaux$dist_site_ancien)

# 3. Distance (km) à la place du Commerce
commerce <- st_sfc(st_point(c(-1.5584, 47.2131)), crs = 4326)
commerce <- st_transform(commerce, 2154)
carreaux$dist_commerce <- as.numeric(st_distance(centres, commerce)) / 1000
summary(carreaux$dist_commerce)

# 4. Restaurants des 8 carreaux voisins (contiguïté reine, sans le carreau)
voisins <- poly2nb(carreaux, queen = TRUE)
poids <- nb2listw(voisins, style = "B", zero.policy = TRUE)  # poids 1 = somme
carreaux$voisins_sirene <- lag.listw(poids, carreaux$n_sirene, zero.policy = TRUE)
carreaux$voisins_osm <- lag.listw(poids, carreaux$n_osm, zero.policy = TRUE)

table(card(voisins))  # nombre de voisins par carreau (8 sauf en bordure)

# Vérification à la main sur le carreau le plus dense
i <- which.max(carreaux$n_sirene)
sum(carreaux$n_sirene[voisins[[i]]]) == carreaux$voisins_sirene[i]

# 5. Sauvegarde
st_write(carreaux, "data/clean/carreaux_variables.gpkg", delete_dsn = TRUE, quiet = TRUE)
