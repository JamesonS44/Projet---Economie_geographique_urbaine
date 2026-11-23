# Avancement du projet (mis à jour le 20/11/2026)

Restaurants et sites touristiques, Nantes Métropole, carreaux de 200 m. Binôme : Jameson + Nassim.
Consignes finales (validées, ne changeront plus) : `docs/consignes_finales.pdf`. **Il n'y a pas de dossier écrit à rendre.**
**Résultats et interprétation complète : `interpretation_resultats.md`** (à lire par les deux pour l'oral).

## Dates clés

| Date | Quoi |
| --- | --- |
| **Lundi 23/11/2026, 23h59** | Rendu : slides PDF + scripts + données |
| **Jeudi 26/11/2026, 10h40-11h00** | Oral, salle 304 : 15 min de présentation + 5 min de questions |

Les modèles sont finis (20/11). Il reste les slides, la reproductibilité et l'oral.

## Ce qu'il faut rendre (le 23/11 à 23h59)
- [ ] Les slides en PDF, nommées `JamesonSAUSSEREAU_NassimIKHELEF.pdf` (format `PrenomNOM1_PrenomNOM2.pdf`)
- [ ] Les scripts de code, reproductibles et commentés (01 à 05)
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
| 3. Décisions de méthode | Fait (20/11) |
| 4. Variables spatiales (02) | Fait (200 m dans 02, 500 m dans 05) |
| 5. Cartes (03 + 04) | Fait : 8 cartes |
| 6. Modèles (04 + 05) | Fait (20/11) |
| 7. Code et reproductibilité | À faire |
| 8. Slides | À faire, **priorité** |
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

## 3. Décisions de méthode (fait)
Réunion du 19/11 avec l'enseignante : voir `recap_reunion_enseignante.md`.
- [x] SIRENE en principal, OSM en robustesse (19/11 : corrélation par carreau 0,86)
- [x] Modèle : `fepois()` (PPML, fixest) en principal, binomiale négative en robustesse (19/11)
- [x] Tous les carreaux en principal, carreaux habités en robustesse (19/11)
- [x] Mémoriaux OSM exclus des sites : `dist_site_sans_mem` en principal (19/11)
- [x] Panel non estimé, cité comme piste dans les limites (19/11)
- [x] **20/11 :** effets fixes commune et fréquentation en **colonne (5)** seulement ; les 4 colonnes prévues restent
- [x] **20/11 :** erreurs-types de **Conley** (seuil 1 km) ; cluster commune et Conley 2 km en robustesse
- [x] **20/11 :** fréquentation = **potentiel** Σ entrées / distance, **moyenne 2009-2019**, 15 lieux, pas de nouvelle source
- [x] **20/11 :** distance au site en **log** (meilleur ajustement : BIC −73) ; distance en km en robustesse
- [x] **20/11 :** population en centaines d'habitants
- [x] **20/11 :** **adresses empilées retirées** de SIRENE (5 restaurants ou plus au même point GPS = domiciliation : 18 points, 186 restaurants). On garde 2 082 restaurants
- [x] Date d'analyse SIRENE : 30/09/2026 (gardée)
- [ ] **Causalité inverse** : à préparer pour l'oral. Arguments dans `interpretation_resultats.md` (sites anciens = même effet ; voisins = causalité inverse mécanique ; fréquentation endogène)

## 4. Variables spatiales (fait)
- [x] `02_variables_spatiales.R` → `data/clean/carreaux_variables.gpkg` : nombre de restaurants (`n_sirene` 2 081, `n_osm` 1 292), distance au site en 3 versions, distance à la place du Commerce, restaurants des 8 voisins
- [x] Potentiel de fréquentation, commune, coordonnées pour Conley : calculés dans 04
- [x] Grille de 500 m : construite dans `05_robustesse_500m.R` (2 129 carreaux)
- [x] Statistiques descriptives : `output/tableaux/stats_descriptives.csv`

## 5. Cartes (fait)
- [x] Zone d'étude, restaurants SIRENE/OSM, sites avec/sans mémoriaux (+ zoom centre), population (`03_cartes.R`, Nassim)
- [x] Distance au site le plus proche : `05_distance_site.png` (dans 03)
- [x] Résidus du modèle complet : `06_residus.png` + zoom centre `06b_residus_centre.png` (dans 04)
- [x] La carte 02 utilise maintenant les 2 082 restaurants (sans adresses empilées)

## 6. Modèles (fait le 20/11)
Script `04_modeles.R` (9 s) ; tableaux dans `output/tableaux/` : `modeles_principaux.txt`, `effets_pourcent.csv`, `robustesse.txt`, `robustesse_500m.txt`.
- [x] 5 colonnes `fepois` : (1) log distance au site ; (2) + population ; (3) + distance place du Commerce ; (4) + restaurants voisins ; (5) + potentiel de fréquentation + EF commune
- [x] Robustesse : binomiale négative ; sites anciens ; avec mémoriaux ; carreaux habités ; OSM ; cluster commune ; Conley 2 km ; distance en km ; 500 m (script 05)
- [x] Moran sur les résidus
- [x] Interprétation complète : `interpretation_resultats.md`

Résultats clés :
- **H1** : quand la distance au site double, il y a −25 % de restaurants (col. 4), −20 % avec EF commune (col. 5), significatif à 0,1 %. Robustesses entre −0,32 et −0,47 ; à 500 m, l'effet est plus faible mais significatif (effet très local)
- **H2** : +1,1 % par restaurant voisin, mais non significatif en binomiale négative, et non causal
- **H3** : partiellement validée (le coefficient de distance baisse de 40 % avec les voisins, mais reste significatif)
- Potentiel de fréquentation **non significatif**

## 7. Code et reproductibilité
- [ ] La chaîne 01 → 02 → 03 → 04 → 05 s'exécute du début à la fin sans intervention, sur une session R vierge
- [ ] Tous les chiffres, cartes et tableaux des slides sortent des scripts (rien n'est calculé à la main)
- [x] Packages chargés en tête de chaque script ; seul le chemin d'accès est à adapter
- [x] Étapes principales commentées (23/11 : nettoyage de Nassim repris, commentaires courts, sans bandeaux ni `cat()`, code inchangé vérifié)
- [ ] Tester la chaîne sur l'ordinateur de Nassim (vrai test de reproductibilité)

## 8. Slides (PDF, 15 min), priorité
Structure conseillée par les consignes :
**23/11 : version 1 faite** dans `slides/` (14 slides, style « éditorial + cartes ») : `JamesonSAUSSEREAU_NassimIKHELEF.pptx` et `.pdf`, points à dire dans `slides/a_dire_par_slide.md`.
- [x] 1. Introduction : question, mécanismes, H1 à H3 (slide 2)
- [x] 2. Données : sources et nettoyage, carte des restaurants, carte des sites et de la distance (slides 3-5)
- [x] 3. Méthodologie : PPML, 5 colonnes, Conley ; variables omises ; causalité inverse (slides 6-8)
- [x] 4. Résultats : tableau des effets, H2/H3, robustesse, résidus (slides 9-12)
- [x] 5. Limites et conclusion (slides 13-14)
- [ ] Relecture par Jameson et Nassim, retouches
- [ ] Option : cartes sans titre ggplot (retoucher 03 et 04)
- [ ] Déposer le PDF final avant 23h59

## 9. Oral (26/11, 10h40)
- [ ] Répartition de la parole entre Jameson et Nassim
- [ ] Répétition chronométrée : 15 min maximum
- [ ] Chacun maîtrise tout le projet, y compris la partie de l'autre (01-02 et 04-05 pour Nassim, 03 pour Jameson)
- [ ] Questions probables : pourquoi pas de VI, causalité inverse, causalité des voisins, choix des sites, mémoriaux, adresses empilées, fréquentation non significative, effet plus faible à 500 m
