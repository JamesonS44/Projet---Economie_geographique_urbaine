# 05_robustesse_500m.R : robustesse avec des carreaux de 500 m

library(sf)
library(dplyr)
library(fixest)
library(spdep)

# 1. Chargement des données
communes <- st_read("data/clean/communes.gpkg", quiet = TRUE)
carreaux200 <- st_read("data/clean/carreaux.gpkg", quiet = TRUE)
sirene <- st_read("data/clean/resto_sirene.gpkg", quiet = TRUE)
osm <- st_read("data/clean/resto_osm.gpkg", quiet = TRUE)
sites <- st_read("data/clean/sites.gpkg", quiet = TRUE)
freq <- st_read("data/clean/frequentation_lieux.gpkg", quiet = TRUE)

# Mêmes filtres que dans 02 : actifs au 30/09/2026, sans adresses empilées
sirene <- filter(sirene, actif)
nb_meme_point <- table(sirene$geo)
sirene <- filter(sirene, geo %in% names(nb_meme_point)[nb_meme_point < 5])

nrow(sirene)
# Mêmes 2 082 restaurants : seuls les carreaux changent

# 2. Grille de 500 m et population
# Grille de 500 m en projection européenne (EPSG:3035)
communes_3035 <- st_transform(communes, 3035)
limites <- st_bbox(communes_3035)
depart <- c(floor(limites["xmin"] / 500) * 500, floor(limites["ymin"] / 500) * 500)

grille <- st_sf(geometry = st_make_grid(communes_3035, cellsize = 500, offset = depart))
dedans <- lengths(st_within(st_centroid(grille), st_union(communes_3035))) > 0
grille <- grille[dedans, ]

xy <- st_coordinates(st_centroid(grille))
grille$id <- paste(floor(xy[, "X"] / 500), floor(xy[, "Y"] / 500))
nrow(grille)
# 2 129 carreaux, 6,25 fois plus grands qu'à 200 m : lisse les écarts entre rues

# Population des carreaux de 200 m versée au carreau de 500 m qui contient leur centre
# (500 n'est pas un multiple de 200, un carreau à cheval va en entier d'un côté)
xy200 <- st_coordinates(st_centroid(st_transform(st_geometry(carreaux200), 3035)))
pop500 <- carreaux200 |>
  st_drop_geometry() |>
  mutate(id = paste(floor(xy200[, "X"] / 500), floor(xy200[, "Y"] / 500))) |>
  group_by(id) |>
  summarise(population = sum(population), habité = any(habité))

grille <- left_join(grille, pop500, by = "id")
grille$population[is.na(grille$population)] <- 0
grille$habité[is.na(grille$habité)] <- FALSE

sum(grille$population) - sum(carreaux200$population)
# Écart presque nul, dû à quelques carreaux de bordure

# Retour en Lambert 93 pour les distances
carreaux <- st_transform(grille, 2154)
centres <- st_centroid(st_geometry(carreaux))

# 3. Variables à 500 m
# Nombre de restaurants par carreau de 500 m
carreaux$n_sirene <- lengths(st_intersects(carreaux, sirene))
carreaux$n_osm <- lengths(st_intersects(carreaux, osm))
sum(carreaux$n_sirene)
# Tous les restaurants sont dans la grille

# Log de la distance au site le plus proche (sans mémoriaux)
dist_proche <- function(points, cibles) {
  proche <- st_nearest_feature(points, cibles)
  as.numeric(st_distance(points, cibles[proche, ], by_element = TRUE)) / 1000
}
carreaux$log_dist <- log(dist_proche(centres, filter(sites, !memorial)))

# Distance (km) à la place du Commerce
commerce <- st_transform(st_sfc(st_point(c(-1.5584, 47.2131)), crs = 4326), 2154)
carreaux$dist_commerce <- as.numeric(st_distance(centres, commerce)) / 1000

# Restaurants des carreaux voisins (reine)
voisins <- poly2nb(carreaux, queen = TRUE)
poids_somme <- nb2listw(voisins, style = "B", zero.policy = TRUE)

carreaux$voisins_sirene <- lag.listw(poids_somme, carreaux$n_sirene, zero.policy = TRUE)
carreaux$voisins_osm <- lag.listw(poids_somme, carreaux$n_osm, zero.policy = TRUE)

# Potentiel de fréquentation (15 lieux, moyenne 2009-2019)
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

# Population, commune et coordonnées pour Conley
carreaux$pop_centaines <- carreaux$population / 100
carreaux$commune <- communes$nom[st_nearest_feature(centres, communes)]

coords <- st_coordinates(st_transform(centres, 4326))
carreaux$lon <- coords[, 1]
carreaux$lat <- coords[, 2]

donnees <- st_drop_geometry(carreaux)

mean(donnees$n_sirene == 0)
var(donnees$n_sirene) / mean(donnees$n_sirene)
# Moins de carreaux vides qu'à 200 m, mais toujours une forte surdispersion

# 4. Modèles
m4_500 <- fepois(n_sirene ~ log_dist + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = conley(1))
m5_500 <- fepois(n_sirene ~ log_dist + pop_centaines + dist_commerce + voisins_sirene +
                       potentiel | commune, data = donnees, vcov = conley(1))
m4_500_osm <- fepois(n_osm ~ log_dist + pop_centaines + dist_commerce + voisins_osm,
                     data = donnees, vcov = conley(1))

modeles_500 <- list(m4_500, m5_500, m4_500_osm)
noms_500 <- c("(4) 500 m", "(5) 500 m", "(4) 500 m OSM")

etable(modeles_500, headers = noms_500)
# On vérifie que les résultats à 200 m ne viennent pas du découpage (MAUP)

# Effet en % d'un doublement de la distance
round((2^sapply(modeles_500, function(m) coef(m)["log_dist"]) - 1) * 100, 1)
# À comparer aux effets à 200 m

# Moran sur les résidus de la colonne (5)
moran.test(
  resid(m5_500, type = "pearson"),
  nb2listw(voisins, style = "W", zero.policy = TRUE),
  zero.policy = TRUE
)
# Les carreaux de 500 m absorbent une partie de la dépendance entre rues voisines ;
# Conley reste utile s'il en reste

# Export du tableau
etable(modeles_500, headers = noms_500, tex = FALSE,
       file = "output/tableaux/robustesse_500m.txt", replace = TRUE)