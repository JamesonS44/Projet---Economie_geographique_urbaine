# 03_cartes.R
# Cartes descriptives de Nantes Métropole (Nassim Ikhelef, 19/11/2026)

library(sf)
library(dplyr)
library(ggplot2)

# Création du dossier de sortie si nécessaire
dir.create("output/cartes", recursive = TRUE, showWarnings = FALSE)

# 0. Chargement des données propres (toutes en Lambert 93 - EPSG:2154)
carreaux     <- st_read("data/clean/carreaux.gpkg", quiet = TRUE)
communes     <- st_read("data/clean/communes.gpkg", quiet = TRUE)
resto_sirene <- st_read("data/clean/resto_sirene.gpkg", quiet = TRUE) %>%
  filter(actif == TRUE) # 2 268 établissements actifs
resto_osm    <- st_read("data/clean/resto_osm.gpkg", quiet = TRUE) # 1 292 points
sites        <- st_read("data/clean/sites.gpkg", quiet = TRUE)     # 736 sites

# Thème cartographique commun sobre et lisible
theme_carte <- theme_void(base_size = 11) +
  theme(
    plot.title      = element_text(face = "bold", size = 13, margin = margin(b = 4)),
    plot.subtitle   = element_text(size = 10, color = "grey30", margin = margin(b = 8)),
    plot.caption    = element_text(size = 8.5, color = "grey40", hjust = 0, margin = margin(t = 8)),
    legend.title    = element_text(face = "bold", size = 9.5),
    legend.text     = element_text(size = 8.5),
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin     = margin(10, 10, 10, 10)
  )

# Carte 1 : Zone d'étude (24 communes et grille de 200 m)
p1 <- ggplot() +
  geom_sf(data = carreaux, fill = "grey97", color = "grey85", linewidth = 0.08) +
  geom_sf(data = communes, fill = NA, color = "grey25", linewidth = 0.45) +
  geom_sf_text(
    data = communes, aes(label = nom),
    size = 2.6, fontface = "bold", color = "grey15", check_overlap = TRUE
  ) +
  labs(
    title    = "Zone d'étude : Nantes Métropole et grille d'analyse (200 m)",
    subtitle = "24 communes découpées en 13 384 carreaux de 200 m × 200 m",
    caption  = "Source : IGN Admin Express & INSEE Filosofi (grille 200 m) — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte

ggsave("output/cartes/01_zone_etude.png", p1, width = 9, height = 7.5, dpi = 300)

# Interprétation Carte 1 :
# Le maillage régulier de 13 384 carreaux de 200 m couvre l'ensemble des 24 communes de Nantes Métropole,
# avec une forte hétérogénéité de superficie entre le cœur urbain (Nantes, Rezé, Saint-Herblain)
# et les communes périphériques plus étendues (Orvault, Carquefou, Vertou, Bouguenais).

# Carte 2 : Restaurants SIRENE vs OpenStreetMap (même échelle)
carreaux_comp <- bind_rows(
  carreaux %>%
    mutate(
      n_restos = lengths(st_intersects(., resto_sirene)),
      source   = "SIRENE actifs (n = 2 268)"
    ),
  carreaux %>%
    mutate(
      n_restos = lengths(st_intersects(., resto_osm)),
      source   = "OpenStreetMap (n = 1 292)"
    )
) %>%
  mutate(
    classe_restos = cut(
      n_restos,
      breaks = c(-1, 0, 1, 3, 10, Inf),
      labels = c("0", "1", "2 – 3", "4 – 10", "Plus de 10")
    )
  )

palette_restos <- c(
  "0"          = "#F7F7F7",
  "1"          = "#FEE0B6",
  "2 – 3"      = "#FDB863",
  "4 – 10"     = "#E08214",
  "Plus de 10" = "#7F3B08"
)

p2 <- ggplot() +
  geom_sf(data = carreaux_comp, aes(fill = classe_restos), color = NA) +
  geom_sf(data = communes, fill = NA, color = "grey35", linewidth = 0.3) +
  facet_wrap(~ source) +
  scale_fill_manual(
    values = palette_restos,
    name   = "Restaurants\npar carreau"
  ) +
  labs(
    title    = "Comparaison spatiale de l'offre de restauration : SIRENE vs OpenStreetMap",
    subtitle = "Nombre d'établissements recensés par carreau de 200 m (échelle identique)",
    caption  = "Sources : Base SIRENE (INSEE, 30/09/2026) et OpenStreetMap — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte +
  theme(strip.text = element_text(face = "bold", size = 11, margin = margin(b = 6)))

ggsave("output/cartes/02_restaurants_sirene_osm.png", p2, width = 12, height = 6.5, dpi = 300)

# Interprétation Carte 2 :
# Les deux sources convergent sur la forte polarisation dans l'hypercentre nantais et le long des axes structurants.
# La plupart des carreaux n'ont aucun restaurant (93 % en SIRENE), ce qui justifie un modèle de comptage. OSM sous-couvre nettement
# les zones d'activités périphériques (Saint-Herblain, Carquefou, Vertou) et les centres-bourgs secondaires par rapport à SIRENE.

# Carte 3 : Sites touristiques et patrimoniaux — Mémoriaux vs autres sites (Q1)
sites_plot <- sites %>%
  mutate(
    categorie_q1 = ifelse(
      memorial == TRUE,
      "Mémorial OSM (n = 396)",
      "Autre site patrimonial / culturel (n = 340)"
    )
  )

p3 <- ggplot() +
  geom_sf(data = carreaux, fill = "grey98", color = "grey90", linewidth = 0.05) +
  geom_sf(data = communes, fill = NA, color = "grey30", linewidth = 0.4) +
  geom_sf(
    data  = sites_plot,
    aes(color = categorie_q1, shape = source),
    size  = 2.1,
    alpha = 0.85
  ) +
  scale_color_manual(
    values = c(
      "Mémorial OSM (n = 396)"                      = "#D90429",
      "Autre site patrimonial / culturel (n = 340)" = "#1D3557"
    ),
    name = "Nature du site (Q1)"
  ) +
  scale_shape_manual(
    values = c(
      "OSM"            = 16,
      "Mérimée"        = 17,
      "Département 44" = 15,
      "Muséofile"      = 18
    ),
    name = "Source de données"
  ) +
  labs(
    title    = "Répartition des sites patrimoniaux et mémoriaux dans la métropole",
    subtitle = "53,8 % des 736 sites recensés sont des mémoriaux issus d'OpenStreetMap",
    caption  = "Sources : OpenStreetMap, Base Mérimée, Département 44, Muséofile — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte

ggsave("output/cartes/03_sites_memoriaux.png", p3, width = 10, height = 7.5, dpi = 300)

# Zoom sur le centre-ville (3 km autour de la place du Commerce), illisible sur la carte entière
commerce <- st_transform(st_sfc(st_point(c(-1.5584, 47.2131)), crs = 4326), 2154)
centre <- st_coordinates(commerce)
p3_zoom <- p3 +
  coord_sf(
    xlim = centre[1] + c(-3000, 3000),
    ylim = centre[2] + c(-3000, 3000),
    datum = NA
  ) +
  labs(
    title    = "Sites patrimoniaux et mémoriaux : zoom sur le centre de Nantes",
    subtitle = "Carré de 6 km centré sur la place du Commerce"
  )

ggsave("output/cartes/03b_sites_memoriaux_centre.png", p3_zoom, width = 10, height = 7.5, dpi = 300)

# Interprétation Carte 3 :
# Les 396 mémoriaux (plaques, stèles, monuments aux morts) sont plus centraux que les autres sites :
# 84 % sont à Nantes (69 % pour les autres sites) et leur distance médiane à la place du Commerce est de 1,1 km
# (2,3 km pour les autres sites OSM). Les retirer change donc peu la distance au site le plus proche
# (médiane de 1,01 à 1,28 km, voir 02). La question des mémoriaux est surtout de savoir si ce sont des sites touristiques.

# Carte 4 : Distribution de la population et carreaux imputés (Filosofi)
carreaux_pop <- carreaux %>%
  mutate(
    classe_pop = case_when(
      habité == FALSE | population == 0 ~ "0 (inhabité)",
      population <= 50                  ~ "1 – 50 hab.",
      population <= 150                 ~ "51 – 150 hab.",
      population <= 400                 ~ "151 – 400 hab.",
      TRUE                              ~ "Plus de 400 hab."
    ),
    classe_pop = factor(
      classe_pop,
      levels = c("0 (inhabité)", "1 – 50 hab.", "51 – 150 hab.", "151 – 400 hab.", "Plus de 400 hab.")
    )
  )

palette_pop <- c(
  "0 (inhabité)"     = "#F5F5F5",
  "1 – 50 hab."      = "#D0E1F9",
  "51 – 150 hab."    = "#6BAED6",
  "151 – 400 hab."   = "#2171B5",
  "Plus de 400 hab." = "#08306B"
)

p4 <- ggplot() +
  geom_sf(data = carreaux_pop, aes(fill = classe_pop), color = NA) +
  geom_sf(
    data      = filter(carreaux_pop, habité == TRUE, imputé == TRUE),
    fill      = NA,
    color     = "#E6550D",
    linewidth = 0.14
  ) +
  geom_sf(data = communes, fill = NA, color = "grey25", linewidth = 0.35) +
  scale_fill_manual(
    values = palette_pop,
    name   = "Population\n(individus / carreau)"
  ) +
  labs(
    title    = "Densité de population et carreaux imputés (grille 200 m)",
    subtitle = "Contours orange : carreaux habités à population imputée (44 % des carreaux habités)",
    caption  = "Source : INSEE Filosofi (données carroyées 200 m) — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte

ggsave("output/cartes/04_population.png", p4, width = 9.5, height = 7.5, dpi = 300)

# Interprétation Carte 4 :
# La population se concentre dans la couronne centrale nantaise et les centralités secondaires, tandis qu'une large part
# des carreaux périphériques reste inhabitée (espaces agricoles, naturels ou zones d'activités).
# Les carreaux imputés (contour orange) concernent principalement les zones peu denses où le secret statistique s'applique.