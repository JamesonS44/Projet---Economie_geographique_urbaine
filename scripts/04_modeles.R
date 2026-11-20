# 04_modeles.R
# Modèles : nombre de restaurants par carreau de 200 m

library(sf)
library(dplyr)
library(fixest)
library(spdep)
library(ggplot2)

carreaux <- st_read("data/clean/carreaux_variables.gpkg", quiet = TRUE)
communes <- st_read("data/clean/communes.gpkg", quiet = TRUE)
freq <- st_read("data/clean/frequentation_lieux.gpkg", quiet = TRUE)

# 1. Variables supplémentaires

# Commune de chaque carreau (pour les effets fixes)
centres <- st_centroid(st_geometry(carreaux))
carreaux$commune <- communes$nom[st_nearest_feature(centres, communes)]

# Coordonnées en degrés pour les erreurs-types de Conley
coords <- st_coordinates(st_transform(centres, 4326))
carreaux$lon <- coords[, 1]
carreaux$lat <- coords[, 2]

# Fréquentation moyenne 2009-2019 par lieu
# Les années à 0 (lieu fermé, ex. musée d'arts en travaux) et 2020 (Covid) sont exclues.
# La cour du château compte déjà les visiteurs du musée : on ne garde que la cour.
lieux <- freq |>
  filter(annee <= 2019, entrees > 0,
         nom != "CHÂTEAU DES DUCS DE BRETAGNE - MUSÉE D'HISTOIRE DE NANTES") |>
  group_by(nom) |>
  summarise(entrees = mean(entrees))
nrow(lieux)  # 15 lieux

# Potentiel de fréquentation : somme des entrées / distance (en centaines de milliers d'entrées par km)
# Distance minimale fixée à 100 m (demi-côté du carreau) pour éviter les divisions par ~0
d <- as.numeric(st_distance(centres, lieux)) / 1000
d <- matrix(pmax(d, 0.1), nrow = length(centres))
carreaux$potentiel <- as.numeric(d^-1 %*% lieux$entrees) / 1e5
summary(carreaux$potentiel)

# Population en centaines d'habitants
carreaux$pop_centaines <- carreaux$population / 100

# Distance au site en log (km) : le coefficient se lit comme une élasticité
carreaux$log_dist <- log(carreaux$dist_site_sans_mem)
carreaux$log_dist_ancien <- log(carreaux$dist_site_ancien)
carreaux$log_dist_tous <- log(carreaux$dist_site_tous)

donnees <- st_drop_geometry(carreaux)

# Statistiques descriptives des variables du modèle
vars_desc <- c("n_sirene", "n_osm", "dist_site_sans_mem", "dist_commerce",
               "population", "voisins_sirene", "potentiel")
stats_desc <- t(sapply(donnees[vars_desc], function(x)
  round(c(moyenne = mean(x), ecart_type = sd(x), min = min(x),
          mediane = median(x), max = max(x)), 2)))
stats_desc
dir.create("output/tableaux", showWarnings = FALSE)
write.csv(stats_desc, "output/tableaux/stats_descriptives.csv")

# 2. Modèles principaux : Poisson (PPML), erreurs-types de Conley (seuil 1 km)
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

# Effets en % : +1 unité pour les variables en niveau, doublement de la distance pour log_dist
effet <- function(m) {
  b <- coef(m)
  e <- exp(b) - 1
  e["log_dist"] <- 2^b["log_dist"] - 1
  round(e * 100, 1)
}
lapply(modeles, effet)

# Surdispersion : variance / moyenne de Y
var(donnees$n_sirene) / mean(donnees$n_sirene)

# 3. Robustesse (sur la colonne 4)
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
# Distance en km (forme linéaire) au lieu du log
r_lineaire <- fepois(n_sirene ~ dist_site_sans_mem + pop_centaines + dist_commerce + voisins_sirene,
                     data = donnees, vcov = se_conley)

robustesse <- list(m4, r_nb, r_ancien, r_tous, r_habite, r_osm, r_cluster, r_conley2, r_lineaire)
noms_robustesse <- c("Principal", "NB", "Sites anciens", "Avec mémoriaux", "Habités",
                     "OSM", "Cluster commune", "Conley 2 km", "Distance en km")
etable(robustesse, headers = noms_robustesse)

# Comparaison des deux formes de distance (BIC plus faible = meilleur ajustement)
BIC(m4)
BIC(r_lineaire)

# 4. Moran sur les résidus (colonnes 4 et 5), voisinage reine
voisins <- poly2nb(carreaux, queen = TRUE)
poids <- nb2listw(voisins, style = "W", zero.policy = TRUE)
moran.test(resid(m4, type = "pearson"), poids, zero.policy = TRUE)
moran.test(resid(m5, type = "pearson"), poids, zero.policy = TRUE)

# 5. Export des tableaux et des résidus (pour la carte)
dir.create("output/tableaux", showWarnings = FALSE)
etable(modeles, tex = FALSE, file = "output/tableaux/modeles_principaux.txt", replace = TRUE)
etable(robustesse, tex = FALSE, file = "output/tableaux/robustesse.txt", replace = TRUE,
       headers = noms_robustesse)

# Effets en % : une ligne par variable, une colonne par modèle
variables <- names(coef(m5))
effets <- sapply(modeles, function(m) effet(m)[variables])
rownames(effets) <- variables
colnames(effets) <- paste0("(", 1:5, ")")
write.csv(effets, "output/tableaux/effets_pourcent.csv")

carreaux$residu_m5 <- resid(m5, type = "pearson")
st_write(carreaux, "data/clean/carreaux_residus.gpkg", delete_dsn = TRUE, quiet = TRUE)

# 6. Carte des résidus de la colonne (5)
# Résidu > 0 : plus de restaurants que prévu par le modèle ; < 0 : moins que prévu
p_res <- ggplot() +
  geom_sf(data = carreaux, aes(fill = residu_m5), color = NA) +
  geom_sf(data = communes, fill = NA, color = "grey25", linewidth = 0.35) +
  scale_fill_gradient2(name = "Résidu de Pearson", low = "#2166AC", mid = "grey95",
                       high = "#B2182B", limits = c(-3, 3), oob = scales::squish) +
  labs(title = "Résidus du modèle complet (colonne 5)",
       subtitle = "Rouge : plus de restaurants que prévu ; bleu : moins que prévu ; échelle coupée à ±3",
       caption = "Modèle de Poisson (PPML) avec effets fixes commune — Lambert 93") +
  theme_void() +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave("output/cartes/06_residus.png", p_res, width = 9, height = 7.5, dpi = 300)

# Zoom sur le centre de Nantes (carré de 5 km centré sur la place du Commerce)
centre <- st_bbox(st_buffer(st_transform(st_sfc(st_point(c(-1.5579, 47.2134)), crs = 4326), 2154), 2500))
p_res_centre <- p_res +
  coord_sf(xlim = centre[c(1, 3)], ylim = centre[c(2, 4)], datum = NA) +
  labs(title = "Résidus du modèle complet : centre de Nantes")
ggsave("output/cartes/06b_residus_centre.png", p_res_centre, width = 8, height = 7.5, dpi = 300)

# Carreaux avec les plus gros résidus
carreaux |> st_drop_geometry() |> arrange(desc(abs(residu_m5))) |>
  select(id, commune, n_sirene, voisins_sirene, dist_site_sans_mem, residu_m5) |> head(10)
