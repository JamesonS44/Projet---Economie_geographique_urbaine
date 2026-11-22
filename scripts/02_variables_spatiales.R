# ==============================================================================
# Script 02 : Construction des variables spatiales par carreau de 200 m
# Projet : Localisation des restaurants et sites touristiques à Nantes Métropole
# Auteurs : Jameson Saussereau & Nassim Ikhelef (M2 ECAP - IAE Nantes)
# ==============================================================================

library(sf)     # Manipulation des géométries et calculs de distances
library(dplyr)  # Filtrage et manipulation des tables
library(spdep)  # Matrices de voisinage spatial (contiguïté reine)

# ------------------------------------------------------------------------------
# 1. Chargement des couches propres et nettoyage fin des restaurants SIRENE
# ------------------------------------------------------------------------------
# Toutes les couches sont en Lambert 93 (EPSG:2154), les distances sont donc en mètres.
carreaux <- st_read("data/clean/carreaux.gpkg", quiet = TRUE)
sirene   <- st_read("data/clean/resto_sirene.gpkg", quiet = TRUE)
osm      <- st_read("data/clean/resto_osm.gpkg", quiet = TRUE)
sites    <- st_read("data/clean/sites.gpkg", quiet = TRUE)

# Sélection des seuls établissements actifs à la date d'analyse (30/09/2026)
sirene <- filter(sirene, actif)
nrow(sirene)
# On dispose de 2 268 établissements actifs géolocalisés dans la métropole.

# Suppression des adresses empilées : 5 établissements ou plus au même point GPS.
# Il s'agit d'adresses de domiciliation ou de sociétés boîtes aux lettres (notamment
# en restauration rapide créée entre 2024 et 2026) et non de véritables salles de restaurant
# (18 points GPS concernés, soit 186 établissements écartés).
nb_meme_point <- table(sirene$geo)
sirene <- filter(sirene, geo %in% names(nb_meme_point)[nb_meme_point < 5])
nrow(sirene)
# L'échantillon net compte 2 082 restaurants physiques actifs pour la variable principale.

# ------------------------------------------------------------------------------
# 2. Variable expliquée (Y) : nombre de restaurants par carreau
# ------------------------------------------------------------------------------
# Comptage des points tombant à l'intérieur de chaque carreau de 200 m
carreaux$n_sirene <- lengths(st_intersects(carreaux, sirene))
carreaux$n_osm    <- lengths(st_intersects(carreaux, osm))

# Vérification des totaux et de la distribution
sum(carreaux$n_sirene)
sum(carreaux$n_osm)
# Quasi-totalité des restaurants rattachés à la grille (un seul point SIRENE tombe en limite extérieure).

mean(carreaux$n_sirene == 0)
summary(carreaux$n_sirene)
# Plus de 93 % des carreaux n'ont aucun restaurant, tandis que les carreaux les plus denses
# de l'hypercentre en concentrent plusieurs dizaines : cette forte surdispersion (variance bien
# supérieure à la moyenne) orientera l'estimation vers une loi binomiale négative plutôt que Poisson.

# ------------------------------------------------------------------------------
# 3. Variable explicative (X) : distance (en km) au site touristique le plus proche
# ------------------------------------------------------------------------------
# Les distances sont calculées à vol d'oiseau depuis le centre géométrique de chaque carreau
centres <- st_centroid(st_geometry(carreaux))

# Fonction qui associe chaque carreau au site le plus proche et renvoie la distance en km
dist_proche <- function(points, cibles) {
  proche <- st_nearest_feature(points, cibles)
  as.numeric(st_distance(points, cibles[proche, ], by_element = TRUE)) / 1000
}

# Trois définitions des sites pour tester la sensibilité des résultats :
carreaux$dist_site_tous     <- dist_proche(centres, sites)                       # Tous les sites (736)
carreaux$dist_site_sans_mem <- dist_proche(centres, filter(sites, !memorial))   # Hors mémoriaux OSM (340)
carreaux$dist_site_ancien   <- dist_proche(centres, filter(sites, ancien))      # Monuments avant 1800 (113)

summary(carreaux$dist_site_tous)
summary(carreaux$dist_site_sans_mem)
summary(carreaux$dist_site_ancien)
# Retirer les 396 mémoriaux OSM fait passer la distance médiane de 1,01 km à 1,28 km : l'écart reste
# modéré car les mémoriaux sont surtout concentrés dans le centre-ville. En revanche, restreindre
# aux seuls monuments historiques d'avant 1800 éloigne nettement la médiane (2,58 km).

# ------------------------------------------------------------------------------
# 4. Variable de contrôle : distance (en km) à la place du Commerce (hypercentre)
# ------------------------------------------------------------------------------
# Coordonnées GPS de la place du Commerce converties en Lambert 93
commerce <- st_sfc(st_point(c(-1.5584, 47.2131)), crs = 4326)
commerce <- st_transform(commerce, 2154)

carreaux$dist_commerce <- as.numeric(st_distance(centres, commerce)) / 1000
summary(carreaux$dist_commerce)
# La médiane se situe à 9,55 km du cœur commercial de Nantes. Ce contrôle est indispensable pour
# isoler l'attractivité propre des monuments de l'effet général de centralité urbaine.

# ------------------------------------------------------------------------------
# 5. Variable d'agglomération : restaurants dans les 8 carreaux voisins
# ------------------------------------------------------------------------------
# Définition du voisinage de type "reine" (carreaux partageant un côté ou un coin)
voisins <- poly2nb(carreaux, queen = TRUE)

# Poids binaires (style = "B") pour obtenir la somme brute des restaurants voisins, sans le carreau lui-même
poids <- nb2listw(voisins, style = "B", zero.policy = TRUE)

carreaux$voisins_sirene <- lag.listw(poids, carreaux$n_sirene, zero.policy = TRUE)
carreaux$voisins_osm    <- lag.listw(poids, carreaux$n_osm, zero.policy = TRUE)

table(card(voisins))
# 12 308 carreaux ont bien 8 voisins complets ; les 1 076 carreaux restants sont situés
# sur la frontière extérieure de Nantes Métropole et ont donc entre 3 et 7 voisins.

# Vérification manuelle sur le carreau le plus dense (quartier Bouffay)
i <- which.max(carreaux$n_sirene)
sum(carreaux$n_sirene[voisins[[i]]]) == carreaux$voisins_sirene[i]
# Le test renvoie TRUE : la somme calculée par la matrice de poids spatial correspond exactement
# au comptage manuel des établissements autour du carreau central le plus dense.

# ------------------------------------------------------------------------------
# 6. Sauvegarde de la table prête pour la cartographie et les modèles
# ------------------------------------------------------------------------------
st_write(carreaux, "data/clean/carreaux_variables.gpkg", delete_dsn = TRUE, quiet = TRUE)