# ==============================================================================
# Script 05 : Test de robustesse au changement d'échelle (grille de 500 m — MAUP)
# Projet : Localisation des restaurants et sites touristiques à Nantes Métropole
# Auteurs : Jameson Saussereau & Nassim Ikhelef (M2 ECAP - IAE Nantes)
# ==============================================================================

library(sf)      # Manipulation des géométries et calculs de distances
library(dplyr)   # Agrégation et filtrage des tables
library(fixest)  # Estimation PPML et erreurs-types spatiales de Conley
library(spdep)   # Matrice de voisinage et test de Moran

# ------------------------------------------------------------------------------
# 1. Chargement des couches propres et filtrage des restaurants
# ------------------------------------------------------------------------------
communes    <- st_read("data/clean/communes.gpkg", quiet = TRUE)
carreaux200 <- st_read("data/clean/carreaux.gpkg", quiet = TRUE)
sirene      <- st_read("data/clean/resto_sirene.gpkg", quiet = TRUE)
osm         <- st_read("data/clean/resto_osm.gpkg", quiet = TRUE)
sites       <- st_read("data/clean/sites.gpkg", quiet = TRUE)
freq        <- st_read("data/clean/frequentation_lieux.gpkg", quiet = TRUE)

# On applique exactement les mêmes critères que dans le script 02 :
# établissements actifs au 30/09/2026 et retrait des adresses empilées (>= 5 au même point GPS).
sirene <- filter(sirene, actif)
nb_meme_point <- table(sirene$geo)
sirene <- filter(sirene, geo %in% names(nb_meme_point)[nb_meme_point < 5])

nrow(sirene)
# On travaille sur le même échantillon de 2 082 restaurants physiques actifs afin que
# les écarts éventuels proviennent uniquement du changement de taille des carreaux.

# ------------------------------------------------------------------------------
# 2. Construction de la grille de 500 m et agrégation de la population
# ------------------------------------------------------------------------------
# Création du maillage de 500 m x 500 m en projection européenne (EPSG:3035)
communes_3035 <- st_transform(communes, 3035)
limites       <- st_bbox(communes_3035)
depart        <- c(floor(limites["xmin"] / 500) * 500, floor(limites["ymin"] / 500) * 500)

grille <- st_sf(geometry = st_make_grid(communes_3035, cellsize = 500, offset = depart))
dedans <- lengths(st_within(st_centroid(grille), st_union(communes_3035))) > 0
grille <- grille[dedans, ]

xy        <- st_coordinates(st_centroid(grille))
grille$id <- paste(floor(xy[, "X"] / 500), floor(xy[, "Y"] / 500))
nrow(grille)
# La métropole est découpée en environ 2 140 carreaux de 500 m (surface 6,25 fois plus grande
# que les carreaux de 200 m), ce qui lisse les micro-variations à l'échelle de la rue.

# Rattachement de la population des carreaux de 200 m vers ceux de 500 m selon leur centre.
# Remarque : 500 n'étant pas un multiple entier de 200, un carreau de 200 m à cheval sur
# deux carreaux de 500 m est affecté en entier à celui qui contient son centre géométrique.
xy200  <- st_coordinates(st_centroid(st_transform(st_geometry(carreaux200), 3035)))
pop500 <- carreaux200 |>
  st_drop_geometry() |>
  mutate(id = paste(floor(xy200[, "X"] / 500), floor(xy200[, "Y"] / 500))) |>
  group_by(id) |>
  summarise(population = sum(population), habité = any(habité))

grille <- left_join(grille, pop500, by = "id")
grille$population[is.na(grille$population)] <- 0
grille$habité[is.na(grille$habité)]         <- FALSE

sum(grille$population) - sum(carreaux200$population)
# L'écart de population totale est quasi nul (uniquement dû aux quelques carreaux situés
# sur la bordure extérieure dont le centre bascule hors du contour à 500 m).

# Reprojection en Lambert 93 (EPSG:2154) pour les calculs de distances
carreaux <- st_transform(grille, 2154)
centres  <- st_centroid(st_geometry(carreaux))

# ------------------------------------------------------------------------------
# 3. Calcul des variables spatiales à l'échelle de 500 m
# ------------------------------------------------------------------------------
# Nombre de restaurants par carreau de 500 m
carreaux$n_sirene <- lengths(st_intersects(carreaux, sirene))
carreaux$n_osm    <- lengths(st_intersects(carreaux, osm))
sum(carreaux$n_sirene)
# Tous les établissements actifs sont bien rattachés au maillage de 500 m.

# Distance en log au site touristique le plus proche (hors mémoriaux OSM)
dist_proche <- function(points, cibles) {
  proche <- st_nearest_feature(points, cibles)
  as.numeric(st_distance(points, cibles[proche, ], by_element = TRUE)) / 1000
}
carreaux$log_dist <- log(dist_proche(centres, filter(sites, !memorial)))

# Distance (km) à la place du Commerce
commerce <- st_transform(st_sfc(st_point(c(-1.5584, 47.2131)), crs = 4326), 2154)
carreaux$dist_commerce <- as.numeric(st_distance(centres, commerce)) / 1000

# Somme des restaurants dans les carreaux voisins (contiguïté reine)
voisins     <- poly2nb(carreaux, queen = TRUE)
poids_somme <- nb2listw(voisins, style = "B", zero.policy = TRUE)

carreaux$voisins_sirene <- lag.listw(poids_somme, carreaux$n_sirene, zero.policy = TRUE)
carreaux$voisins_osm    <- lag.listw(poids_somme, carreaux$n_osm, zero.policy = TRUE)

# Potentiel de fréquentation touristique (15 grands lieux culturels, moyenne 2009-2019)
lieux <- freq |>
  filter(
    annee <= 2019,
    entrees > 0,
    nom != "CHÂTEAU DES DUCS DE BRETAGNE - MUSÉE D'HISTOIRE DE NANTES"
  ) |>
  group_by(nom) |>
  summarise(entrees = mean(entrees))

d <- matrix(pmax(as.numeric(st_distance(centres, lieux)) / 1000, 0.1), nrow = length(centres))
carreaux$potentiel <- as.numeric(d^-1 %*% lieux$entrees) / 1e5

# Contrôles complémentaires et coordonnées GPS pour Conley
carreaux$pop_centaines <- carreaux$population / 100
carreaux$commune       <- communes$nom[st_nearest_feature(centres, communes)]

coords       <- st_coordinates(st_transform(centres, 4326))
carreaux$lon <- coords[, 1]
carreaux$lat <- coords[, 2]

donnees <- st_drop_geometry(carreaux)

mean(donnees$n_sirene == 0)
var(donnees$n_sirene) / mean(donnees$n_sirene)
# Le passage à 500 m réduit la proportion de carreaux sans restaurant (autour de 77 % contre
# 93 % à 200 m), mais la surdispersion reste très marquée, confirmant le choix du PPML.

# ------------------------------------------------------------------------------
# 4. Estimation des modèles (colonnes 4, 5 et variante OSM) et diagnostics
# ------------------------------------------------------------------------------
m4_500     <- fepois(n_sirene ~ log_dist + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = conley(1))
m5_500     <- fepois(n_sirene ~ log_dist + pop_centaines + dist_commerce + voisins_sirene +
                       potentiel | commune, data = donnees, vcov = conley(1))
m4_500_osm <- fepois(n_osm ~ log_dist + pop_centaines + dist_commerce + voisins_osm,
                     data = donnees, vcov = conley(1))

modeles_500 <- list(m4_500, m5_500, m4_500_osm)
noms_500    <- c("(4) 500 m", "(5) 500 m", "(4) 500 m OSM")

etable(modeles_500, headers = noms_500)
# La comparaison avec les estimations à 200 m permet de vérifier que les résultats ne sont pas
# un artefact du découpage spatial (problème du MAUP) : le signe et la significativité de
# l'agglomération commerciale et de la proximité touristique sont testés à une échelle plus large.

# Variation relative (%) du nombre de restaurants lorsque la distance au site double
round((2^sapply(modeles_500, function(m) coef(m)["log_dist"]) - 1) * 100, 1)
# Mesure directement l'élasticité à la distance touristique à l'échelle de 500 m pour la
# mettre en regard des pourcentages obtenus sur la grille fine de 200 m.

# Test d'autocorrélation spatiale de Moran sur les résidus de la colonne (5)
moran.test(
  resid(m5_500, type = "pearson"),
  nb2listw(voisins, style = "W", zero.policy = TRUE),
  zero.policy = TRUE
)
# L'agrégation à 500 m absorbe une partie des dépendances locales entre rues adjacentes, mais
# les erreurs-types de Conley restent indispensables si une autocorrélation résiduelle subsiste.

# Exportation du tableau de robustesse
etable(modeles_500, headers = noms_500, tex = FALSE,
       file = "output/tableaux/robustesse_500m.txt", replace = TRUE)