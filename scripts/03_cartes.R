# 03_cartes.R : cartes descriptives

library(sf)
library(dplyr)
library(ggplot2)

# Dossier de sortie
dir.create("output/cartes", recursive = TRUE, showWarnings = FALSE)

# 1. Chargement des données
carreaux <- st_read("data/clean/carreaux.gpkg", quiet = TRUE)
communes <- st_read("data/clean/communes.gpkg", quiet = TRUE)
resto_osm <- st_read("data/clean/resto_osm.gpkg", quiet = TRUE) # 1 292 points
sites <- st_read("data/clean/sites.gpkg", quiet = TRUE)  # 736 sites

# Restaurants SIRENE actifs (2 268), sans les adresses empilées comme dans 02
# (5 établissements ou plus au même point GPS) : 2 082 restaurants
resto_sirene <- st_read("data/clean/resto_sirene.gpkg", quiet = TRUE) %>%
  filter(actif == TRUE)

nb_meme_point <- table(resto_sirene$geo)
resto_sirene <- filter(resto_sirene, geo %in% names(nb_meme_point)[nb_meme_point < 5])

# 2. Thème des cartes
theme_carte <- theme_void(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 13, margin = margin(b = 4)),
    plot.subtitle = element_text(size = 10, color = "grey30", margin = margin(b = 8)),
    plot.caption = element_text(size = 8.5, color = "grey40", hjust = 0, margin = margin(t = 8)),
    legend.title = element_text(face = "bold", size = 9.5),
    legend.text = element_text(size = 8.5),
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(10, 10, 10, 10)
  )

# 3. Carte 1 : zone d'étude
p1 <- ggplot() +
  geom_sf(data = carreaux, fill = "grey97", color = "grey85", linewidth = 0.08) +
  geom_sf(data = communes, fill = NA, color = "grey25", linewidth = 0.45) +
  geom_sf_text(
    data = communes, aes(label = nom),
    size = 2.6, fontface = "bold", color = "grey15", check_overlap = TRUE
  ) +
  labs(
    title = "Zone d'étude : Nantes Métropole et grille d'analyse (200 m)",
    subtitle = "24 communes découpées en 13 384 carreaux de 200 m × 200 m",
    caption = "Source : IGN Admin Express & INSEE Filosofi (grille 200 m) — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte

ggsave("output/cartes/01_zone_etude.png", p1, width = 9, height = 7.5, dpi = 300)
# Les carreaux comparent le territoire à surface égale, alors que les communes vont
# de très petites (Indre) à très grandes (Couëron, Carquefou, Vertou).

# 4. Carte 2 : SIRENE et OSM
# Les deux sources avec les mêmes classes, pour comparer sur la même échelle
carreaux_comp <- bind_rows(
  carreaux %>%
    mutate(
      n_restos = lengths(st_intersects(., resto_sirene)),
      source = "SIRENE actifs (n = 2 082)"
    ),
  carreaux %>%
    mutate(
      n_restos = lengths(st_intersects(., resto_osm)),
      source = "OpenStreetMap (n = 1 292)"
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
  "0" = "#F7F7F7",
  "1" = "#FEE0B6",
  "2 – 3" = "#FDB863",
  "4 – 10" = "#E08214",
  "Plus de 10" = "#7F3B08"
)

p2 <- ggplot() +
  geom_sf(data = carreaux_comp, aes(fill = classe_restos), color = NA) +
  geom_sf(data = communes, fill = NA, color = "grey35", linewidth = 0.3) +
  facet_wrap(~ source) +
  scale_fill_manual(
    values = palette_restos,
    name = "Restaurants\npar carreau"
  ) +
  labs(
    title = "Comparaison spatiale de l'offre de restauration : SIRENE vs OpenStreetMap",
    subtitle = "Nombre d'établissements recensés par carreau de 200 m (échelle identique)",
    caption = "Sources : Base SIRENE (INSEE, 30/09/2026) et OpenStreetMap — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte +
  theme(strip.text = element_text(face = "bold", size = 11, margin = margin(b = 6)))

ggsave("output/cartes/02_restaurants_sirene_osm.png", p2, width = 12, height = 6.5, dpi = 300)
# Restaurants concentrés dans l'hypercentre et vers Saint-Herblain, 93 % de carreaux
# à zéro (SIRENE) : modèle de comptage. OSM couvre mal les zones d'activités
# (Carquefou, Vertou, Rezé) et les bourgs : SIRENE en principal.

# 5. Carte 3 : sites
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
    data = sites_plot,
    aes(color = categorie_q1, shape = source),
    size = 2.1,
    alpha = 0.85
  ) +
  scale_color_manual(
    values = c(
      "Mémorial OSM (n = 396)" = "#D90429",
      "Autre site patrimonial / culturel (n = 340)" = "#1D3557"
    ),
    name = "Nature du site (Q1)"
  ) +
  scale_shape_manual(
    values = c(
      "OSM" = 16,
      "Mérimée" = 17,
      "Département 44" = 15,
      "Muséofile" = 18
    ),
    name = "Source de données"
  ) +
  labs(
    title = "Répartition des sites patrimoniaux et mémoriaux dans la métropole",
    subtitle = "53,8 % des 736 sites recensés sont des mémoriaux issus d'OpenStreetMap",
    caption = "Sources : OpenStreetMap, Base Mérimée, Département 44, Muséofile — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte

ggsave("output/cartes/03_sites_memoriaux.png", p3, width = 10, height = 7.5, dpi = 300)

# Zoom de 6 km autour de la place du Commerce, où les points se superposent
commerce <- st_transform(st_sfc(st_point(c(-1.5584, 47.2131)), crs = 4326), 2154)
centre <- st_coordinates(commerce)

p3_zoom <- p3 +
  coord_sf(
    xlim = centre[1] + c(-3000, 3000),
    ylim = centre[2] + c(-3000, 3000),
    datum = NA
  ) +
  labs(
    title = "Sites patrimoniaux et mémoriaux : zoom sur le centre de Nantes",
    subtitle = "Carré de 6 km centré sur la place du Commerce"
  )

ggsave("output/cartes/03b_sites_memoriaux_centre.png", p3_zoom, width = 10, height = 7.5, dpi = 300)
# Les 396 mémoriaux (plaques, stèles, monuments aux morts) sont plus centraux : 84 % à
# Nantes (69 % pour les autres sites), médiane à 1,1 km de la place du Commerce. Les
# retirer évite que les plaques de l'hypercentre gonflent l'attrait touristique.

# 6. Carte 4 : population
carreaux_pop <- carreaux %>%
  mutate(
    classe_pop = case_when(
      habité == FALSE | population == 0 ~ "0 (inhabité)",
      population <= 50 ~ "1 – 50 hab.",
      population <= 150 ~ "51 – 150 hab.",
      population <= 400 ~ "151 – 400 hab.",
      TRUE ~ "Plus de 400 hab."
    ),
    classe_pop = factor(
      classe_pop,
      levels = c("0 (inhabité)", "1 – 50 hab.", "51 – 150 hab.", "151 – 400 hab.", "Plus de 400 hab.")
    )
  )

palette_pop <- c(
  "0 (inhabité)" = "#F5F5F5",
  "1 – 50 hab." = "#D0E1F9",
  "51 – 150 hab." = "#6BAED6",
  "151 – 400 hab." = "#2171B5",
  "Plus de 400 hab." = "#08306B"
)

p4 <- ggplot() +
  geom_sf(data = carreaux_pop, aes(fill = classe_pop), color = NA) +
  geom_sf(
    data = filter(carreaux_pop, habité == TRUE, imputé == TRUE),
    fill = NA,
    color = "#E6550D",
    linewidth = 0.14
  ) +
  geom_sf(data = communes, fill = NA, color = "grey25", linewidth = 0.35) +
  scale_fill_manual(
    values = palette_pop,
    name = "Population\n(individus / carreau)"
  ) +
  labs(
    title = "Densité de population et carreaux imputés (grille 200 m)",
    subtitle = "Contours orange : carreaux habités à population imputée (44 % des carreaux habités)",
    caption = "Source : INSEE Filosofi (données carroyées 200 m) — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte

ggsave("output/cartes/04_population.png", p4, width = 9.5, height = 7.5, dpi = 300)
# Population dans la couronne nantaise et les centres secondaires ; l'estuaire ouest,
# les abords du lac de Grand-Lieu et les zones d'activités sont inhabités. Les carreaux
# imputés (orange) sont presque tous peu denses (1 à 50 hab.), sans restaurants.

# 7. Carte 5 : distance au site
carreaux_var <- st_read("data/clean/carreaux_variables.gpkg", quiet = TRUE)

# Échelle coupée à 5 km pour garder les nuances en ville
p5 <- ggplot() +
  geom_sf(data = carreaux_var, aes(fill = dist_site_sans_mem), color = NA) +
  geom_sf(data = communes, fill = NA, color = "grey25", linewidth = 0.35) +
  geom_sf(data = filter(sites, !memorial), size = 0.4, color = "#E6550D") +
  scale_fill_viridis_c(
    name = "Distance (km)",
    option = "mako",
    direction = -1,
    limits = c(0, 5),
    oob = scales::squish
  ) +
  labs(
    title = "Distance au site touristique le plus proche (grille 200 m)",
    subtitle = "Points orange : sites touristiques hors mémoriaux ; échelle coupée à 5 km",
    caption = "Source : OSM, Mérimée, Muséofile, Département 44 — Projection : Lambert 93 (EPSG:2154)"
  ) +
  theme_carte

ggsave("output/cartes/05_distance_site.png", p5, width = 9, height = 7.5, dpi = 300)
# Moins de 1 km dans le centre de Nantes et près des bourgs anciens (Vertou, Carquefou,
# Couëron), 3 à 5 km et plus dans les zones agricoles de l'ouest et du sud : la distance
# varie beaucoup, ce qui aide à mesurer son effet.