# ==============================================================================
# Script 04 : Estimation des modèles économétriques et tests de robustesse
# Projet : Localisation des restaurants et sites touristiques à Nantes Métropole
# Auteurs : Jameson Saussereau & Nassim Ikhelef (M2 ECAP - IAE Nantes)
# ==============================================================================

library(sf)       # Manipulation des couches spatiales et calcul de distances
library(dplyr)    # Filtrage et préparation des données
library(fixest)   # Estimation rapide des modèles de comptage et erreurs de Conley
library(spdep)    # Matrice de voisinage et test d'autocorrélation spatiale de Moran
library(ggplot2)  # Cartographie des résidus

# ------------------------------------------------------------------------------
# 1. Chargement des données et création des variables complémentaires
# ------------------------------------------------------------------------------
carreaux <- st_read("data/clean/carreaux_variables.gpkg", quiet = TRUE)
communes <- st_read("data/clean/communes.gpkg", quiet = TRUE)
freq     <- st_read("data/clean/frequentation_lieux.gpkg", quiet = TRUE)

centres <- st_centroid(st_geometry(carreaux))

# Rattachement de chaque carreau à sa commune (pour les effets fixes communaux)
carreaux$commune <- communes$nom[st_nearest_feature(centres, communes)]

# Extraction des coordonnées GPS (longitude, latitude) requises par conley()
coords       <- st_coordinates(st_transform(centres, 4326))
carreaux$lon <- coords[, 1]
carreaux$lat <- coords[, 2]

# Calcul de la fréquentation moyenne annuelle (2009-2019) des grands lieux culturels.
# On exclut l'année 2020 (biaisée par les fermetures Covid), les années à 0 (travaux)
# et le musée d'histoire du Château des Ducs (déjà comptabilisé dans les entrées de la cour).
lieux <- freq |>
  filter(
    annee <= 2019,
    entrees > 0,
    nom != "CHÂTEAU DES DUCS DE BRETAGNE - MUSÉE D'HISTOIRE DE NANTES"
  ) |>
  group_by(nom) |>
  summarise(entrees = mean(entrees))

nrow(lieux)
# On dispose de 15 grands équipements culturels géolocalisés avec une fréquentation fiable.

# Indice de potentiel touristique (modèle gravitaire : somme des entrées / distance).
# La distance minimale est bornée à 0,1 km (demi-côté d'un carreau) pour éviter une division par zéro.
d <- as.numeric(st_distance(centres, lieux)) / 1000
d <- matrix(pmax(d, 0.1), nrow = length(centres))
carreaux$potentiel <- as.numeric(d^-1 %*% lieux$entrees) / 1e5

summary(carreaux$potentiel)
# Cet indicateur pondère la proximité par l'attractivité réelle (nombre de visiteurs),
# complétant la simple distance au site le plus proche qui traite tous les monuments à égalité.

# Mise à l'échelle de la population (en centaines d'habitants) pour faciliter la lecture des coefficients
carreaux$pop_centaines <- carreaux$population / 100

# Passage au logarithme des distances : le coefficient s'interprète directement comme une élasticité
carreaux$log_dist        <- log(carreaux$dist_site_sans_mem)
carreaux$log_dist_ancien <- log(carreaux$dist_site_ancien)
carreaux$log_dist_tous   <- log(carreaux$dist_site_tous)

# Table sans géométrie pour accélérer les régressions
donnees <- st_drop_geometry(carreaux)

# Tableau des statistiques descriptives des variables clés
vars_desc <- c("n_sirene", "n_osm", "dist_site_sans_mem", "dist_commerce",
               "population", "voisins_sirene", "potentiel")

stats_desc <- t(sapply(donnees[vars_desc], function(x) {
  round(c(
    moyenne    = mean(x),
    ecart_type = sd(x),
    min        = min(x),
    mediane    = median(x),
    max        = max(x)
  ), 2)
}))
stats_desc
# Les distributions sont très asymétriques à droite (médiane nulle pour les restaurants et leurs
# voisins, mais maximums élevés en centre-ville), confirmant la forte polarisation spatiale.

dir.create("output/tableaux", showWarnings = FALSE)
write.csv(stats_desc, "output/tableaux/stats_descriptives.csv")

# ------------------------------------------------------------------------------
# 2. Estimation des modèles principaux (Poisson PPML, erreurs de Conley à 1 km)
# ------------------------------------------------------------------------------
# L'estimateur PPML (fepois) reste convergent même en présence de nombreux zéros et de surdispersion.
# Les erreurs-types de Conley (rayon 1 km) corrigent la corrélation spatiale entre carreaux proches.
se_conley <- conley(1)

m1 <- fepois(n_sirene ~ log_dist, data = donnees, vcov = se_conley)
m2 <- fepois(n_sirene ~ log_dist + pop_centaines, data = donnees, vcov = se_conley)
m3 <- fepois(n_sirene ~ log_dist + pop_centaines + dist_commerce,
             data = donnees, vcov = se_conley)
m4 <- fepois(n_sirene ~ log_dist + pop_centaines + dist_commerce + voisins_sirene,
             data = donnees, vcov = se_conley)
m5 <- fepois(n_sirene ~ log_dist + pop_centaines + dist_commerce + voisins_sirene +
               potentiel | commune, data = donnees, vcov = se_conley)

modeles <- list(m1, m2, m3, m4, m5)
etable(modeles)
# L'ajout progressif des contrôles (population en m2, distance à Commerce en m3) atténue
# l'élasticité à la distance touristique, confirmant le biais négatif de variable omise.
# L'introduction des restaurants voisins en m4 réduit encore cet effet, illustrant le rôle
# conjoint de l'agglomération commerciale (H2) et de la médiation spatiale (H3).

# Conversion des coefficients en variations relatives (%) :
# - Pour log_dist : variation du nombre de restaurants lorsque la distance au site double (+100 %).
# - Pour les autres variables : variation associée à une hausse d'une unité (+100 hab., +1 km, +1 voisin).
effet <- function(m) {
  b <- coef(m)
  e <- exp(b) - 1
  e["log_dist"] <- 2^b["log_dist"] - 1
  round(e * 100, 1)
}
lapply(modeles, effet)
# Cette lecture en pourcentage permet de quantifier concrètement la perte d'attractivité
# lorsqu'on double l'éloignement par rapport à un site patrimonial.

# Vérification du ratio variance / moyenne de la variable dépendante
var(donnees$n_sirene) / mean(donnees$n_sirene)
# Le ratio est très supérieur à 1 (forte surdispersion), ce qui justifie de doubler le PPML
# par une estimation en loi binomiale négative dans les tests de robustesse.

# ------------------------------------------------------------------------------
# 3. Batterie de tests de robustesse (autour de la spécification m4)
# ------------------------------------------------------------------------------
f4 <- n_sirene ~ log_dist + pop_centaines + dist_commerce + voisins_sirene

r_nb       <- fenegbin(f4, data = donnees, vcov = se_conley)
r_ancien   <- fepois(n_sirene ~ log_dist_ancien + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = se_conley)
r_tous     <- fepois(n_sirene ~ log_dist_tous + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = se_conley)
r_habite   <- fepois(f4, data = filter(donnees, habité), vcov = se_conley)
r_osm      <- fepois(n_osm ~ log_dist + pop_centaines + dist_commerce + voisins_osm,
                     data = donnees, vcov = se_conley)
r_cluster  <- fepois(f4, data = donnees, cluster = ~commune)
r_conley2  <- fepois(f4, data = donnees, vcov = conley(2))
r_lineaire <- fepois(n_sirene ~ dist_site_sans_mem + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = se_conley)

robustesse <- list(m4, r_nb, r_ancien, r_tous, r_habite, r_osm, r_cluster, r_conley2, r_lineaire)
noms_robustesse <- c("Principal", "NB", "Sites anciens", "Avec mémoriaux", "Habités",
                     "OSM", "Cluster commune", "Conley 2 km", "Distance en km")

etable(robustesse, headers = noms_robustesse)
# La stabilité du signe et de la significativité à travers ces 8 variantes (loi binomiale négative,
# définition des sites, restriction aux carreaux habités, source OSM et calcul des écarts-types)
# confirme que les résultats ne dépendent pas d'un choix arbitraire de spécification.

# Comparaison de l'ajustement entre distance en log (m4) et distance linéaire (r_lineaire)
BIC(m4)
BIC(r_lineaire)
# Le critère BIC plus faible pour m4 confirme que l'effet de l'éloignement est non linéaire
# (une hausse de 500 m pèse beaucoup plus près d'un monument qu'à 5 km en périphérie).

# ------------------------------------------------------------------------------
# 4. Diagnostic d'autocorrélation spatiale sur les résidus (test de Moran)
# ------------------------------------------------------------------------------
voisins <- poly2nb(carreaux, queen = TRUE)
poids   <- nb2listw(voisins, style = "W", zero.policy = TRUE)

moran.test(resid(m4, type = "pearson"), poids, zero.policy = TRUE)
moran.test(resid(m5, type = "pearson"), poids, zero.policy = TRUE)
# L'indice de Moran reste positif et significatif même après inclusion des voisins et des effets
# fixes communaux : des facteurs locaux inobservés (rues piétonnes, gares, centres commerciaux)
# restent corrélés dans l'espace, ce qui justifie pleinement l'usage des erreurs-types de Conley.

# ------------------------------------------------------------------------------
# 5. Exportation des tableaux de résultats et sauvegarde des résidus
# ------------------------------------------------------------------------------
etable(modeles, tex = FALSE, file = "output/tableaux/modeles_principaux.txt", replace = TRUE)
etable(robustesse, tex = FALSE, file = "output/tableaux/robustesse.txt", replace = TRUE,
       headers = noms_robustesse)

# Export de la matrice des effets en pourcentage pour les 5 modèles
variables <- names(coef(m5))
effets    <- sapply(modeles, function(m) effet(m)[variables])
rownames(effets) <- variables
colnames(effets) <- paste0("(", 1:5, ")")
write.csv(effets, "output/tableaux/effets_pourcent.csv")

carreaux$residu_m5 <- resid(m5, type = "pearson")
st_write(carreaux, "data/clean/carreaux_residus.gpkg", delete_dsn = TRUE, quiet = TRUE)

# ------------------------------------------------------------------------------
# 6. Cartographie des résidus du modèle complet (colonne 5)
# ------------------------------------------------------------------------------
# Résidu > 0 : le carreau accueille plus de restaurants que prévu par le modèle.
# Résidu < 0 : le carreau accueille moins de restaurants que prévu.
p_res <- ggplot() +
  geom_sf(data = carreaux, aes(fill = residu_m5), color = NA) +
  geom_sf(data = communes, fill = NA, color = "grey25", linewidth = 0.35) +
  scale_fill_gradient2(
    name     = "Résidu de Pearson",
    low      = "#2166AC",
    mid      = "grey95",
    high     = "#B2182B",
    limits   = c(-3, 3),
    oob      = scales::squish
  ) +
  labs(
    title    = "Résidus du modèle complet (colonne 5)",
    subtitle = "Rouge : plus de restaurants que prévu ; bleu : moins que prévu ; échelle coupée à ±3",
    caption  = "Modèle de Poisson (PPML) avec effets fixes commune — Lambert 93"
  ) +
  theme_void() +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave("output/cartes/06_residus.png", p_res, width = 9, height = 7.5, dpi = 300)

# Zoom sur le centre de Nantes (carré de 5 km autour de la place du Commerce)
centre <- st_bbox(st_buffer(st_transform(st_sfc(st_point(c(-1.5579, 47.2134)), crs = 4326), 2154), 2500))

p_res_centre <- p_res +
  coord_sf(xlim = centre[c(1, 3)], ylim = centre[c(2, 4)], datum = NA) +
  labs(title = "Résidus du modèle complet : centre de Nantes")

ggsave("output/cartes/06b_residus_centre.png", p_res_centre, width = 8, height = 7.5, dpi = 300)

# Inspection des 10 carreaux présentant les plus forts écarts à la prédiction
carreaux |>
  st_drop_geometry() |>
  arrange(desc(abs(residu_m5))) |>
  select(id, commune, n_sirene, voisins_sirene, dist_site_sans_mem, residu_m5) |>
  head(10)
# Les plus forts résidus positifs correspondent aux pôles commerciaux et rues très commerçantes
# (centre commercial Atlantis à Saint-Herblain, marché de Talensac, axes de l'hypercentre)
# dont l'attractivité commerciale spécifique dépasse la seule proximité des monuments.