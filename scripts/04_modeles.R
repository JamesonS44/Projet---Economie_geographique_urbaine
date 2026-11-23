# 04_modeles.R : modèles et robustesse

library(sf)
library(dplyr)
library(fixest)
library(spdep)
library(ggplot2)

# 1. Chargement des données et variables en plus
carreaux <- st_read("data/clean/carreaux_variables.gpkg", quiet = TRUE)
communes <- st_read("data/clean/communes.gpkg", quiet = TRUE)
freq <- st_read("data/clean/frequentation_lieux.gpkg", quiet = TRUE)

centres <- st_centroid(st_geometry(carreaux))

# Commune de chaque carreau (effets fixes)
carreaux$commune <- communes$nom[st_nearest_feature(centres, communes)]

# Coordonnées GPS pour conley()
coords <- st_coordinates(st_transform(centres, 4326))
carreaux$lon <- coords[, 1]
carreaux$lat <- coords[, 2]

# Fréquentation moyenne 2009-2019 par lieu. On exclut 2020 (Covid), les années à 0
# (travaux) et le musée du Château, déjà compté dans les entrées de la cour.
lieux <- freq |>
  filter(
    annee <= 2019,
    entrees > 0,
    nom != "CHÂTEAU DES DUCS DE BRETAGNE - MUSÉE D'HISTOIRE DE NANTES"
  ) |>
  group_by(nom) |>
  summarise(entrees = mean(entrees))

nrow(lieux)
# 15 lieux

# Potentiel de fréquentation : somme des entrées / distance (en centaines de milliers).
# Distance minimale de 0,1 km (demi-côté du carreau) pour ne pas diviser par ~0.
d <- as.numeric(st_distance(centres, lieux)) / 1000
d <- matrix(pmax(d, 0.1), nrow = length(centres))
carreaux$potentiel <- as.numeric(d^-1 %*% lieux$entrees) / 1e5

summary(carreaux$potentiel)
# Pondère la proximité par le nombre de visiteurs, alors que la distance au site
# le plus proche traite tous les sites pareil.

# Population en centaines d'habitants
carreaux$pop_centaines <- carreaux$population / 100

# Distance en log : le coefficient se lit comme une élasticité
carreaux$log_dist <- log(carreaux$dist_site_sans_mem)
carreaux$log_dist_ancien <- log(carreaux$dist_site_ancien)
carreaux$log_dist_tous <- log(carreaux$dist_site_tous)

# Table sans géométrie pour les régressions
donnees <- st_drop_geometry(carreaux)

# Statistiques descriptives
vars_desc <- c("n_sirene", "n_osm", "dist_site_sans_mem", "dist_commerce",
               "population", "voisins_sirene", "potentiel")

stats_desc <- t(sapply(donnees[vars_desc], function(x) {
  round(c(
    moyenne = mean(x),
    ecart_type = sd(x),
    min = min(x),
    mediane = median(x),
    max = max(x)
  ), 2)
}))
stats_desc
# Très asymétriques : médiane nulle pour les restaurants et les voisins, maximums élevés
# en centre-ville.

dir.create("output/tableaux", showWarnings = FALSE)
write.csv(stats_desc, "output/tableaux/stats_descriptives.csv")

# Part des restaurants dans le 1 % de carreaux qui en ont le plus
n_trie <- sort(donnees$n_sirene, decreasing = TRUE)
sum(n_trie[1:ceiling(0.01 * nrow(donnees))]) / sum(n_trie)
# 51 % des restaurants dans 1 % des carreaux

# Lien entre la distance au site (en log) et les contrôles, pour le sens des biais
cor(donnees$log_dist, donnees$dist_commerce)
cor(donnees$log_dist, donnees$potentiel)
# 0,54 avec la distance au centre, -0,40 avec le potentiel

# 2. Modèles principaux
# PPML (fepois) : convergent malgré les nombreux zéros et la surdispersion.
# Erreurs-types de Conley (1 km) : corrélation spatiale entre carreaux proches.
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
# Avec la population (m2) et la distance au Commerce (m3), l'effet de la distance baisse :
# sans contrôles, il était biaisé vers le négatif. Les voisins (m4) le réduisent encore
# (H2 et H3).

# Effets en % : doublement de la distance pour log_dist, +1 unité pour les autres
# (+100 hab., +1 km, +1 voisin)
effet <- function(m) {
  b <- coef(m)
  e <- exp(b) - 1
  e["log_dist"] <- 2^b["log_dist"] - 1
  round(e * 100, 1)
}
lapply(modeles, effet)
# Donne la perte de restaurants quand la distance au site double

# Ratio variance / moyenne de Y
var(donnees$n_sirene) / mean(donnees$n_sirene)
# Très supérieur à 1 (surdispersion) : binomiale négative en robustesse

# 3. Robustesse
f4 <- n_sirene ~ log_dist + pop_centaines + dist_commerce + voisins_sirene

r_nb <- fenegbin(f4, data = donnees, vcov = se_conley)
r_ancien <- fepois(n_sirene ~ log_dist_ancien + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = se_conley)
r_tous <- fepois(n_sirene ~ log_dist_tous + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = se_conley)
r_habite <- fepois(f4, data = filter(donnees, habité), vcov = se_conley)
r_osm <- fepois(n_osm ~ log_dist + pop_centaines + dist_commerce + voisins_osm,
                     data = donnees, vcov = se_conley)
r_cluster <- fepois(f4, data = donnees, cluster = ~commune)
r_conley2 <- fepois(f4, data = donnees, vcov = conley(2))
r_lineaire <- fepois(n_sirene ~ dist_site_sans_mem + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = se_conley)

robustesse <- list(m4, r_nb, r_ancien, r_tous, r_habite, r_osm, r_cluster, r_conley2, r_lineaire)
noms_robustesse <- c("Principal", "NB", "Sites anciens", "Avec mémoriaux", "Habités",
                     "OSM", "Cluster commune", "Conley 2 km", "Distance en km")

etable(robustesse, headers = noms_robustesse)
# L'effet de la distance garde son signe et reste significatif dans les 8 variantes :
# le résultat ne dépend pas d'un choix de spécification.

# Distance en log (m4) ou en km (r_lineaire) ?
BIC(m4)
BIC(r_lineaire)
# BIC plus faible avec le log : 500 m de plus comptent bien plus près d'un site qu'à 5 km

# 4. Moran sur les résidus
voisins <- poly2nb(carreaux, queen = TRUE)
poids <- nb2listw(voisins, style = "W", zero.policy = TRUE)

moran.test(resid(m4, type = "pearson"), poids, zero.policy = TRUE)
moran.test(resid(m5, type = "pearson"), poids, zero.policy = TRUE)
# Moran positif et significatif même avec les voisins et les EF commune : des facteurs
# locaux non observés (rues piétonnes, gares, centres commerciaux) restent, d'où Conley.

# 5. Export des tableaux
etable(modeles, tex = FALSE, file = "output/tableaux/modeles_principaux.txt", replace = TRUE)
etable(robustesse, tex = FALSE, file = "output/tableaux/robustesse.txt", replace = TRUE,
       headers = noms_robustesse)

# Effets en % des 5 modèles
variables <- names(coef(m5))
effets <- sapply(modeles, function(m) effet(m)[variables])
rownames(effets) <- variables
colnames(effets) <- paste0("(", 1:5, ")")
write.csv(effets, "output/tableaux/effets_pourcent.csv")

carreaux$residu_m5 <- resid(m5, type = "pearson")
st_write(carreaux, "data/clean/carreaux_residus.gpkg", delete_dsn = TRUE, quiet = TRUE)

# 6. Carte des résidus
# Résidu > 0 : plus de restaurants que prévu ; < 0 : moins que prévu
p_res <- ggplot() +
  geom_sf(data = carreaux, aes(fill = residu_m5), color = NA) +
  geom_sf(data = communes, fill = NA, color = "grey25", linewidth = 0.35) +
  scale_fill_gradient2(
    name = "Résidu de Pearson",
    low = "#2166AC",
    mid = "grey95",
    high = "#B2182B",
    limits = c(-3, 3),
    oob = scales::squish
  ) +
  labs(
    title = "Résidus du modèle complet (colonne 5)",
    subtitle = "Rouge : plus de restaurants que prévu ; bleu : moins que prévu ; échelle coupée à ±3",
    caption = "Modèle de Poisson (PPML) avec effets fixes commune — Lambert 93"
  ) +
  theme_void() +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave("output/cartes/06_residus.png", p_res, width = 9, height = 7.5, dpi = 300)

# Zoom de 5 km autour de la place du Commerce
centre <- st_bbox(st_buffer(st_transform(st_sfc(st_point(c(-1.5579, 47.2134)), crs = 4326), 2154), 2500))

p_res_centre <- p_res +
  coord_sf(xlim = centre[c(1, 3)], ylim = centre[c(2, 4)], datum = NA) +
  labs(title = "Résidus du modèle complet : centre de Nantes")

ggsave("output/cartes/06b_residus_centre.png", p_res_centre, width = 8, height = 7.5, dpi = 300)

# Les 10 plus gros résidus
carreaux |>
  st_drop_geometry() |>
  arrange(desc(abs(residu_m5))) |>
  select(id, commune, n_sirene, voisins_sirene, dist_site_sans_mem, residu_m5) |>
  head(10)
# Surtout des carreaux isolés en périphérie (Le Pellerin, Vertou, Couëron, Carquefou) :
# 2 à 8 restaurants sans voisins, prédits presque à zéro. Un seul au centre (29 restaurants).