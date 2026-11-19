# Avancement du projet (mis à jour le 19/11/2026)

Restaurants et sites touristiques, Nantes Métropole, carreaux de 200 m. Binôme : Jameson + Nassim.
Date de rendu, format du dossier et oral : inconnus, à demander (Q6 de `questions_reunion.md`).

## Vue d'ensemble

| Bloc | État |
| --- | --- |
| 1. Cadrage | Fait |
| 2. Données | Fait |
| 3. Décisions de méthode | En cours (réunion) |
| 4. Variables spatiales (02) | Fait en 200 m (reste 500 m et panel) |
| 5. Cartes (03) | En cours (Nassim) |
| 6. Modèles (04) | À faire |
| 7. Dossier écrit | À faire |
| 8. Slides | À faire |
| 9. Oral | À faire |

## 1. Cadrage (fait)
- [x] Consigne reçue (24/09)
- [x] Cadrage rédigé en binôme, retour de l'enseignante reçu
- [x] VI abandonnée (08/11), panel léger ajouté, sites « tous » en principal et Mérimée < 1800 en robustesse, SIRENE et OSM dans les modèles (09/11)

## 2. Données (fait le 17/11)
- [x] Téléchargement de toutes les sources, une seule fois, avec les URL dans `data/raw/DATES.txt`
- [x] SIRENE retéléchargé (le fichier du 10/11 était tronqué)
- [x] `scripts/01_donnees.R` lancé en entier : 6 couches dans `data/clean/`
    - communes (24), carreaux (13 384, population Filosofi)
    - resto_sirene (6 598 dont 2 268 actifs au 30/09/2026), resto_osm (1 292)
    - sites (736 : OSM, Mérimée, Muséofile, Département 44), frequentation_lieux (16 lieux, 2009-2020)
- [x] Projet partagé sur GitHub (17/11) ; SIRENE, Mérimée et Filosofi (> 100 Mo) envoyés par WeTransfer, à mettre dans `data/raw/`
- [x] Questions pour la réunion préparées (`questions_reunion.md`, en local chez Jameson)
- [ ] Relire 01_donnees.R ensemble pour savoir l'expliquer
- [ ] Placer les 5 grands équipements à la main, seulement si l'enseignante retient ce panel

## 3. Décisions de méthode
- [ ] Réunion avec l'enseignante (`questions_reunion.md`)
- [ ] Mémoriaux OSM : tous, exclus, ou en robustesse (396 sites sur 566 OSM)
- [ ] Date d'analyse SIRENE (30/09/2026 provisoire)
- [ ] Forme du panel : grands équipements 2007-2013 ou lieux 44 2009-2020, ou simple piste
- [ ] Présentation avec/sans restaurants voisins
- [x] SIRENE en principal, OSM en robustesse (19/11 : corrélation par carreau 0,86), à confirmer en réunion
- [x] Binomiale négative attendue (19/11 : variance/moyenne ≈ 11), test formel dans 04
- [x] Tous les carreaux en principal, carreaux habités en robustesse (19/11)

## 4. Variables spatiales (`02_variables_spatiales.R`, fait le 19/11)
Résultat : `data/clean/carreaux_variables.gpkg` (13 384 carreaux, 12 colonnes).
- [x] Nombre de restaurants par carreau : `n_sirene` (2 267), `n_osm` (1 292) ; 93 % de carreaux à 0, max 52 (Bouffay)
- [x] Distance au site le plus proche (km) en 3 versions : `dist_site_tous` (médiane 1,01), `dist_site_sans_mem` (1,28), `dist_site_ancien` (2,58)
- [x] Distance à la place du Commerce : `dist_commerce` (médiane 9,55 ; corrélée à 0,72 avec la distance au site)
- [x] Restaurants des 8 carreaux voisins : `voisins_sirene`, `voisins_osm` (vérifié à la main ; corr. 0,68 avec `n_sirene`)
- [ ] Même chose en carreaux de 500 m (robustesse)
- [ ] Panel si retenu : ouvertures par carreau × année, fréquentation des lieux

## 5. Cartes (`03_cartes.R`)
- [ ] Zone d'étude
- [ ] Restaurants / densité par carreau
- [ ] Distance au site le plus proche
- [ ] Population
- [ ] Résidus du modèle (après 04)
- [ ] Une interprétation écrite par carte

## 6. Modèles (`04_modeles.R`)
- [ ] 4 colonnes emboîtées : (1) distance au site ; (2) + population ; (3) + distance place du Commerce ; (4) + restaurants voisins
- [ ] Test de surdispersion, choix Poisson ou NB
- [ ] Robustesse : 500 m ; sites anciens ; sans carreaux inhabités ; SE clusterisés par commune ; OSM au lieu de SIRENE
- [ ] Moran sur les résidus
- [ ] Panel léger si retenu
- [ ] Tableaux exportés dans `output/tableaux/`

## 7. Dossier écrit
- [ ] Introduction et question de recherche (H1, H2, H3)
- [ ] Revue rapide de la littérature (agglomération, tourisme et localisation des commerces)
- [ ] Données : sources, dates, nettoyage, limites (géocodage Mérimée, doublons entre sources, Filosofi imputé)
- [ ] Stratégie empirique : spécification, choix Poisson/NB
- [ ] Biais de variable omise : sens du biais pour chaque contrôle (effet de Z sur Y × lien Z–X)
- [ ] Résultats : cartes et coefficients interprétés
- [ ] Robustesse
- [ ] Limites d'identification : voisins endogènes et médiateurs, distance ≠ fréquentation, corrélation spatiale des erreurs ≠ biais
- [ ] Conclusion
- [ ] Annexe : code R et données reproductibles

## 8. Slides
- [ ] Plan des slides (question, données, cartes, modèle, résultats, limites)
- [ ] Choix des 2-3 cartes et du tableau principal
- [ ] Mise en forme

## 9. Oral
- [ ] Répartition de la parole entre Jameson et Nassim
- [ ] Répétition chronométrée
- [ ] Questions probables : pourquoi pas de VI, causalité des voisins, choix des sites, mémoriaux
