# Séance du 19/11/2026 : 1 h avant la réunion avec l'enseignante

Objectif : avancer à deux sans conflit, et arriver à la réunion avec des chiffres et une carte pour appuyer les questions (surtout Q1, les mémoriaux).

## Règles communes

- Chacun travaille dans **son propre fichier** : Jameson dans `scripts/02_variables_spatiales.R`, Nassim dans `scripts/03_cartes.R`.
- On **ne modifie pas** `01_donnees.R` ni les fichiers déjà présents dans `data/clean/` (on les lit seulement).
- Tout en R, avec des commentaires courts en français et un script lisible de haut en bas (règle du projet).
- Faire un `git pull` avant de commencer et pousser à la fin. Comme les fichiers sont différents, il n'y aura pas de conflit.

## Ce qu'on a dans `data/clean/`

Toutes les couches sont en **Lambert 93 (EPSG 2154)**, donc les distances sortent **en mètres**.

| Fichier | Lignes | Colonnes utiles |
| --- | --- | --- |
| `carreaux.gpkg` | 13 384 carreaux de 200 m | `id`, `population`, `imputé`, `habité` |
| `communes.gpkg` | 24 communes | `nom`, `code` |
| `resto_sirene.gpkg` | 6 598 (dont **2 268** avec `actif == TRUE`) | `siret`, `creation`, `fermeture`, `etat`, `naf`, `actif` |
| `resto_osm.gpkg` | 1 292 | `osm_id`, `name`, `amenity` |
| `sites.gpkg` | 736 | `nom`, `source`, `type`, `memorial`, `ancien` |
| `frequentation_lieux.gpkg` | 192 (16 lieux × 12 ans) | pas utile aujourd'hui |

Composition de `sites` : OSM 566 (dont **396 mémoriaux**), Mérimée 148, Département 44 18, Muséofile 4. Seuls les sites OSM peuvent être des mémoriaux.

Pour lire une couche : `sf::st_read("data/clean/sites.gpkg")`.

---

## Partie Jameson : `scripts/02_variables_spatiales.R` (45 min)

But : produire une table avec **une ligne par carreau** et toutes les variables du modèle. Aucun de ces calculs ne dépend de la réunion : quand une décision est encore ouverte, on calcule les deux versions et on choisira après.

### Étape 0 : début du script (5 min)
- Charger `sf`, `dplyr` et `spdep`.
- Lire `carreaux`, `resto_sirene`, `resto_osm` et `sites`.
- Ne garder dans SIRENE que les restaurants actifs (`actif == TRUE`). Vérifier qu'on en a bien 2 268.

### Étape 1 : nombre de restaurants par carreau (10 min)
- Créer deux variables : `n_sirene` (restaurants actifs) et `n_osm`.
- Piste : `lengths(st_intersects(carreaux, restos))` donne directement un compte par carreau.
- Vérifications :
  - la somme de `n_sirene` doit être proche de 2 268 (un petit écart s'explique par les restaurants hors de la grille ou sur une limite) ;
  - la part de carreaux à 0 sera très forte, ce qui est normal pour un Poisson. La noter, elle servira pour le dossier.

### Étape 2 : distance au site le plus proche, en km (15 min)
- Mesurer depuis le **centroïde** du carreau (`st_centroid`).
- Calculer 3 versions :
  - `dist_site_tous` : tous les sites (spécification principale) ;
  - `dist_site_sans_mem` : sites avec `memorial == FALSE` (pour Q1) ;
  - `dist_site_ancien` : sites avec `ancien == TRUE` (robustesse « monuments anciens »).
- Piste : `st_nearest_feature()` donne l'indice du site le plus proche, puis `st_distance(..., by_element = TRUE)`. Diviser par 1000 pour avoir des km.
- **Pour la réunion (Q1)** : faire un `summary()` de `dist_site_tous` et de `dist_site_sans_mem`, et noter la médiane et le maximum des deux. Si la distance médiane change beaucoup sans les mémoriaux, c'est l'argument chiffré à montrer.

### Étape 3 : distance à la place du Commerce, en km (5 min)
- Créer un point à partir de ses coordonnées (environ lon -1.5590, lat 47.2133, à vérifier sur une carte). Le créer en WGS84 (EPSG 4326), puis le passer en 2154 avec `st_transform`.
- Variable : `dist_commerce`.

### Étape 4 : restaurants des 8 carreaux voisins (10 min, le plus délicat)
- Voisinage **reine** : `poly2nb(carreaux, queen = TRUE)`.
- On veut la **somme** des restaurants des voisins, sans le carreau lui-même. Il faut donc des poids **binaires** : `nb2listw(nb, style = "B", zero.policy = TRUE)`, puis `lag.listw(...)` appliqué à `n_sirene`.
- Variables : `voisins_sirene` (et `voisins_osm` si le temps le permet).
- Vérification : prendre un carreau au hasard, regarder ses voisins et refaire la somme à la main.
- À noter pour le dossier : les carreaux en bord de métropole ont moins de 8 voisins.

### Étape 5 : sauvegarde (2 min)
- Écrire `data/clean/carreaux_variables.gpkg` (un nouveau fichier, sans écraser `carreaux.gpkg`).

### Reporté après la réunion
Les carreaux de 500 m, le panel et le choix définitif de la version des sites.

---

## Partie Nassim : `scripts/03_cartes.R` (45 min)

But : faire les **4 cartes descriptives** qui n'ont besoin que de `data/clean/`. Il n'est pas nécessaire d'attendre le script 02. Les cartes vont dans `output/cartes/` (en PNG, avec `ggsave`).

Principes pour toutes les cartes : un titre, une légende lisible, la source en bas (« Source : SIRENE 30/09/2026 », « OpenStreetMap », etc.) et les contours des communes en fond.

### Carte 1 : zone d'étude (5 min)
- Les 24 communes avec leur nom, et éventuellement la grille de carreaux en trait très fin.
- Fichier : `01_zone_etude.png`.

### Carte 2 : restaurants SIRENE et OSM côte à côte (15 min)
- Deux panneaux avec la même échelle : à gauche les SIRENE actifs (2 268), à droite OSM (1 292).
- On peut afficher les points ou compter les restaurants par carreau (`lengths(st_intersects(...))`) et colorer les carreaux. Le comptage se lit mieux, mais les points sont plus rapides à faire.
- Utile pour Q5 : est-ce que les deux sources montrent la même géographie ? Où OSM sous-couvre-t-il ?
- Fichier : `02_restaurants_sirene_osm.png`.

### Carte 3 : sites touristiques, mémoriaux ou non (15 min, la plus importante pour la réunion)
- Tous les sites, avec une couleur selon `memorial` (TRUE / FALSE).
- On peut aussi faire une forme ou une couleur par `source` (OSM, Mérimée, Département 44, Muséofile).
- Ce qu'elle doit montrer pour Q1 : si les mémoriaux sont partout, la distance au site le plus proche devient faible presque partout.
- Fichier : `03_sites_memoriaux.png`.

### Carte 4 : population par carreau (10 min)
- Colorer les carreaux selon `population`. Utiliser une échelle en classes ou en log, car quelques carreaux très peuplés écrasent la palette.
- Option : hachurer ou signaler les carreaux `imputé == TRUE` (44 % des carreaux habités sont imputés, c'est une limite à montrer).
- Fichier : `04_population.png`.

### Pour chaque carte
Écrire 2 lignes d'interprétation (dans un commentaire du script ou dans un fichier à part). La consigne exige des cartes interprétées.

### Si tu as fini avant : tableau du biais de variable omise (sans code)
Pour chaque contrôle Z (population, distance à la place du Commerce, restaurants voisins), remplir :

| Contrôle Z | Effet de Z sur Y (nb restos) : + / - | Lien entre Z et la distance au site : + / - | Sens du biais sur le coef. de distance si Z est omis |
| --- | --- | --- | --- |
| Population | | | |
| Distance place du Commerce | | | |
| Restaurants voisins | | | |

Règle : biais = (effet de Z sur Y) × (lien Z–X). Les deux de même signe donnent un biais positif, de signes opposés un biais négatif. On pourra faire valider ce tableau à la réunion.

### Reporté
Les cartes de distance (elles ont besoin du script 02) et la carte des résidus (elle a besoin du script 04).

---

## Les 10 dernières minutes, ensemble

1. **Corriger `questions_reunion.md`** : la phrase d'ouverture, Q1 et Q5 reprennent les anciens chiffres. Les bons chiffres sont 2 268 SIRENE actifs, 1 292 OSM, 13 384 carreaux, 566 sites OSM dont 396 mémoriaux.
2. Ajouter à Q1 la médiane de la distance avec et sans mémoriaux (étape 2 de Jameson).
3. Avoir la carte 3 ouverte sur un écran pour la montrer pendant Q1, et la carte 2 pour Q5.
4. `git add`, `commit` et `push` de chaque script et des PNG.

## Si quelqu'un bloque

- Si une erreur de CRS apparaît, vérifier `st_crs()` : tout doit être en 2154 (seul le point de la place du Commerce part de 4326).
- Si `poly2nb` est lent sur 13 384 carreaux, c'est normal, compter une à deux minutes.
- Si on reste bloqué plus de 10 minutes sur une étape, on la saute, on la note comme question et on passe à la suivante.
