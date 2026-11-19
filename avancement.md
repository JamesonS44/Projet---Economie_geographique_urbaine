# Avancement du projet (mis à jour le 19/11/2026)

Restaurants et sites touristiques, Nantes Métropole, carreaux de 200 m. Binôme : Jameson + Nassim.
Consignes finales (validées, ne changeront plus) : `docs/consignes_finales.pdf`. **Il n'y a pas de dossier écrit à rendre.**

## Dates clés

| Date | Quoi |
| --- | --- |
| **Lundi 23/11/2026, 23h59** | Rendu : slides PDF + scripts + données |
| **Jeudi 26/11/2026, 10h40-11h00** | Oral, salle 304 : 15 min de présentation + 5 min de questions |

Il reste 4 jours avant le rendu, donc il faut prioriser : modèles (04) d'abord, puis slides.

## Ce qu'il faut rendre (le 23/11 à 23h59)
- [ ] Les slides en PDF, nommées `JamesonSAUSSEREAU_NassimIKHELEF.pdf` (format `PrenomNOM1_PrenomNOM2.pdf`)
- [ ] Les scripts de code, reproductibles et commentés
- [ ] Les données utilisées. Attention : `data/raw` pèse 1,6 Go et `data/clean` 9 Mo. Il faut choisir ce qu'on rend et comment (lien de téléchargement, ou seulement les données propres plus les URL de `DATES.txt` ?)

## Critères d'évaluation (consignes finales)

| Critère | Ce qu'on doit montrer |
| --- | --- |
| Raisonnement économique | Pertinence de la question, mécanismes (demande touristique, agglomération) |
| Données et géographie | Qualité des données, construction des variables géographiques, maîtrise des outils spatiaux |
| Économétrie | Pertinence du modèle, discussion des biais : **variables omises ET causalité inverse** |
| Résultats | Interprétation économique et statistique des coefficients |
| Oral | Clarté, réponses aux questions. **Chaque membre doit maîtriser tout le projet** |
| Code | Il s'exécute du début à la fin sans intervention (sauf les chemins) et reproduit **tous** les résultats des slides. Packages chargés en début de script. Étapes principales commentées |

## Vue d'ensemble

| Bloc | État |
| --- | --- |
| 1. Cadrage | Fait |
| 2. Données (01) | Fait |
| 3. Décisions de méthode | En cours |
| 4. Variables spatiales (02) | Fait en 200 m (reste 500 m, panel à décider) |
| 5. Cartes (03) | 4 cartes faites, reste distance et résidus |
| 6. Modèles (04) | À faire, **priorité** |
| 7. Code et reproductibilité | À faire |
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
- [x] Projet partagé sur GitHub (17/11) ; SIRENE, Mérimée et Filosofi (> 100 Mo) envoyés par WeTransfer
- [ ] Relire 01_donnees.R ensemble pour savoir l'expliquer (les deux doivent maîtriser le projet)
- [ ] Placer les 5 grands équipements à la main, seulement si le panel est gardé

## 3. Décisions de méthode
Réunion du 19/11 avec l'enseignante : voir `recap_reunion_enseignante.md`.
- [x] SIRENE en principal, OSM en robustesse (19/11 : corrélation par carreau 0,86)
- [x] Modèle : `fepois()` (PPML, fixest) en principal, binomiale négative en robustesse (réunion 19/11)
- [x] Effets fixes commune ajoutés (contrôlent une partie de la centralité) (19/11)
- [x] Tous les carreaux en principal, carreaux habités en robustesse (19/11, maintenu après la réunion : les carreaux sans population incluent des zones d'affaires)
- [x] Mémoriaux OSM exclus des sites (pas de logique économique) : `dist_site_sans_mem` en principal (19/11)
- [x] Fréquentation des sites ajoutée en contrôle, en coupe transversale (15 lieux NM, 2009-2020) (19/11)
- [x] Panel non estimé, cité comme piste dans les limites (19/11, manque de temps)
- [ ] Forme de la variable de fréquentation (potentiel Σ Fréq/distance, distance au site le plus fréquenté, année retenue)
- [ ] Colonnes où entrent les effets fixes commune et la fréquentation (toutes, ou une colonne (5))
- [ ] SE clusterisés par commune avec seulement 24 clusters : garder en signalant la limite ?
- [ ] Date d'analyse SIRENE (30/09/2026 gardé, non discuté en réunion)
- [ ] Présentation avec et sans restaurants voisins (non discuté en réunion : colonne (4), interprétation prudente)
- [ ] **Causalité inverse** (nouveau critère) : les restaurants peuvent-ils attirer ou créer des sites ? Les sites Mérimée anciens sont antérieurs aux restaurants actuels, mais pas les sites OSM (attractions, mémoriaux récents). Pour les voisins, la causalité inverse est évidente (chaque carreau est le voisin de ses voisins). À préparer pour l'oral

## 4. Variables spatiales (`02_variables_spatiales.R`, fait le 19/11)
Résultat : `data/clean/carreaux_variables.gpkg` (13 384 carreaux, 12 colonnes).
- [x] Nombre de restaurants par carreau : `n_sirene` (2 267), `n_osm` (1 292) ; 93 % de carreaux à 0, max 52 (Bouffay)
- [x] Distance au site le plus proche (km) en 3 versions : `dist_site_tous` (médiane 1,01), `dist_site_sans_mem` (1,28), `dist_site_ancien` (2,58)
- [x] Distance à la place du Commerce : `dist_commerce` (médiane 9,55 ; corrélée à 0,72 avec la distance au site)
- [x] Restaurants des 8 carreaux voisins : `voisins_sirene`, `voisins_osm` (vérifié à la main ; corr. 0,68 avec `n_sirene`)
- [ ] Même chose en carreaux de 500 m (robustesse)
- [ ] Variable de fréquentation des sites par carreau (coupe transversale)
- [ ] Tableau de statistiques descriptives (demandé dans la partie « Données » des slides)

## 5. Cartes (`03_cartes.R`, Nassim, 19/11)
Script relancé le 19/11 : il tourne en 12 s, reproductible (`output/cartes/`). Au moins une carte est obligatoire dans les slides.
- [x] Zone d'étude (`01_zone_etude.png`)
- [x] Restaurants SIRENE et OSM côte à côte (`02_restaurants_sirene_osm.png`)
- [x] Sites avec ou sans mémoriaux (`03_sites_memoriaux.png`) et zoom sur le centre (`03b_sites_memoriaux_centre.png`)
- [x] Population et carreaux imputés (`04_population.png`)
- [x] Une interprétation par carte (en commentaire dans le script), relue et corrigée le 19/11
- [x] Style du script : bandeaux décoratifs enlevés
- [ ] Distance au site le plus proche (avec `carreaux_variables.gpkg`)
- [ ] Résidus du modèle (après 04)

## 6. Modèles (`04_modeles.R`), priorité
- [ ] 4 colonnes emboîtées avec `fepois()` : (1) distance au site ; (2) + population ; (3) + distance place du Commerce ; (4) + restaurants voisins. Ajouter fréquentation et effets fixes commune (colonnes à fixer)
- [ ] Interprétation des coefficients (en IRR : effet de 1 km de plus en %)
- [ ] Robustesse : binomiale négative ; 500 m ; sites anciens ; carreaux habités ; OSM au lieu de SIRENE ; SE clusterisés par commune
- [ ] Moran sur les résidus
- [ ] Tableaux exportés dans `output/tableaux/` (ce sont eux qui iront dans les slides)

## 7. Code et reproductibilité
- [ ] La chaîne 01 → 02 → 03 → 04 s'exécute du début à la fin sans intervention, sur une session R vierge
- [ ] Tous les chiffres, cartes et tableaux des slides sortent des scripts (rien n'est calculé à la main)
- [ ] Packages chargés en tête de chaque script ; seul le chemin d'accès est à adapter
- [ ] Étapes principales commentées : import et nettoyage, construction des variables, estimations, production des résultats
- [ ] Tester la chaîne sur l'ordinateur de Nassim (vrai test de reproductibilité)

## 8. Slides (PDF, 15 min)
Structure conseillée par les consignes :
- [ ] 1. Introduction : contexte, question de recherche, mécanismes économiques, hypothèses H1 à H3
- [ ] 2. Données : sources, construction des variables géographiques, statistiques descriptives, carte(s)
- [ ] 3. Méthodologie : modèle (`fepois`, NB en robustesse), justification des variables, stratégie d'identification ; biais de variable omise (sens du biais pour chaque contrôle, effet de Z sur Y × lien Z–X) et causalité inverse
- [ ] 4. Résultats : tableau des 4 colonnes, interprétation des coefficients, robustesse
- [ ] 5. Discussion et conclusion : limites (voisins endogènes et médiateurs, fréquentation sur 15 lieux seulement et elle-même endogène, panel cité comme piste, corrélation spatiale des erreurs ≠ biais, Filosofi imputé, MAUP) et réponse à la question
- [ ] Choix des 2-3 cartes et du tableau principal
- [ ] Mise en forme, export PDF au bon nom

## 9. Oral (26/11, 10h40)
- [ ] Répartition de la parole entre Jameson et Nassim
- [ ] Répétition chronométrée : 15 min maximum
- [ ] Chacun maîtrise tout le projet, y compris la partie de l'autre (01-02 pour Nassim, 03 pour Jameson)
- [ ] Questions probables : pourquoi pas de VI, causalité inverse, causalité des voisins, choix des sites, mémoriaux, résultat non significatif
