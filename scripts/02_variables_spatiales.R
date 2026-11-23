# 02_variables_spatiales.R : variables par carreau de 200 m

library(sf)
library(dplyr)
library(spdep)

# 1. Chargement des données
# Couches en Lambert 93 : distances en mètres
carreaux <- st_read("data/clean/carreaux.gpkg", quiet = TRUE)
sirene <- st_read("data/clean/resto_sirene.gpkg", quiet = TRUE)
osm <- st_read("data/clean/resto_osm.gpkg", quiet = TRUE)
sites <- st_read("data/clean/sites.gpkg", quiet = TRUE)

# Restaurants actifs au 30/09/2026
sirene <- filter(sirene, actif)
nrow(sirene)
# 2 268 restaurants actifs

# Adresses empilées : 5 établissements ou plus au même point GPS. Ce sont des
# domiciliations (souvent de la restauration rapide créée en 2024-2026), pas de
# vraies salles : 18 points, 186 établissements retirés.
nb_meme_point <- table(sirene$geo)
sirene <- filter(sirene, geo %in% names(nb_meme_point)[nb_meme_point < 5])
nrow(sirene)
# Il reste 2 082 restaurants

# 2. Nombre de restaurants par carreau
# Nombre de points dans chaque carreau
carreaux$n_sirene <- lengths(st_intersects(carreaux, sirene))
carreaux$n_osm <- lengths(st_intersects(carreaux, osm))

# Vérification des totaux
sum(carreaux$n_sirene)
sum(carreaux$n_osm)
# Un seul restaurant SIRENE tombe hors de la grille (en limite)

mean(carreaux$n_sirene == 0)
summary(carreaux$n_sirene)
# Plus de 93 % de carreaux sans restaurant, quelques dizaines dans l'hypercentre :
# beaucoup de zéros et forte surdispersion (d'où PPML, et NB en robustesse).

# 3. Distance au site le plus proche
# Distance à vol d'oiseau depuis le centre du carreau
centres <- st_centroid(st_geometry(carreaux))

# Distance (km) au site le plus proche
dist_proche <- function(points, cibles) {
  proche <- st_nearest_feature(points, cibles)
  as.numeric(st_distance(points, cibles[proche, ], by_element = TRUE)) / 1000
}

# Trois définitions des sites :
carreaux$dist_site_tous <- dist_proche(centres, sites)  # tous les sites (736)
carreaux$dist_site_sans_mem <- dist_proche(centres, filter(sites, !memorial))  # sans mémoriaux OSM (340)
carreaux$dist_site_ancien <- dist_proche(centres, filter(sites, ancien))  # monuments avant 1800 (113)

summary(carreaux$dist_site_tous)
summary(carreaux$dist_site_sans_mem)
summary(carreaux$dist_site_ancien)
# Sans les mémoriaux, la médiane passe de 1,01 à 1,28 km (ils sont surtout au centre).
# Avec les seuls monuments d'avant 1800, elle monte à 2,58 km.

# 4. Distance à la place du Commerce
# Place du Commerce en GPS puis en Lambert 93
commerce <- st_sfc(st_point(c(-1.5584, 47.2131)), crs = 4326)
commerce <- st_transform(commerce, 2154)

carreaux$dist_commerce <- as.numeric(st_distance(centres, commerce)) / 1000
summary(carreaux$dist_commerce)
# Médiane à 9,55 km. Ce contrôle sépare l'effet des sites de l'effet du centre-ville.

# 5. Restaurants des 8 carreaux voisins
# Voisinage reine : côté ou coin commun
voisins <- poly2nb(carreaux, queen = TRUE)

# Poids binaires (style "B") : somme des restaurants voisins, sans le carreau lui-même
poids <- nb2listw(voisins, style = "B", zero.policy = TRUE)

carreaux$voisins_sirene <- lag.listw(poids, carreaux$n_sirene, zero.policy = TRUE)
carreaux$voisins_osm <- lag.listw(poids, carreaux$n_osm, zero.policy = TRUE)

table(card(voisins))
# 12 308 carreaux ont 8 voisins ; les 1 076 autres, en bordure de la métropole,
# en ont entre 3 et 7.

# Vérification à la main sur le carreau le plus dense (Bouffay)
i <- which.max(carreaux$n_sirene)
sum(carreaux$n_sirene[voisins[[i]]]) == carreaux$voisins_sirene[i]
# TRUE : la somme calculée correspond au comptage à la main

# 6. Sauvegarde
st_write(carreaux, "data/clean/carreaux_variables.gpkg", delete_dsn = TRUE, quiet = TRUE)
