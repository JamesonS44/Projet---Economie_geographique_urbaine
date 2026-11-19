# Déroulé du projet : du problème aux résultats

Restaurants et sites touristiques à Nantes Métropole. M2 ECAP, IAE Nantes, cours d'économie géographique et urbaine appliquée (G. Gambuli). Binôme : Jameson Saussereau et Nassim Ikhelef.

Ce fichier raconte le projet dans l'ordre : le problème de départ, ce qu'on a fait, ce qu'on a obtenu et pourquoi chaque choix a été fait. Il est mis à jour à chaque étape. Dernière mise à jour : 19/11/2026.

Les autres fichiers : `avancement.md` (liste des tâches, cochées ou non), `scripts/` (code R, à lancer dans l'ordre 01, 02, 03, 04), `data/raw/DATES.txt` (sources et dates de téléchargement).

---

## 1. Le problème de départ

### La consigne (24/09/2026)
Il fallait poser une **question précise, pas descriptive**, utiliser des **données géolocalisées** avec au moins **une variable spatiale construite**, faire des **cartes interprétées** et estimer **au moins un modèle économétrique**, en justifiant la spécification, en interprétant les coefficients et en discutant les limites d'identification. Le code R et les données devaient être reproductibles. Un résultat non significatif est accepté s'il est rigoureux.

Nous avons pris le sujet n°9 de la consigne, adapté.

### La question
**Les restaurants se localisent-ils près des sites touristiques, ou simplement près d'autres restaurants ?**

On voit beaucoup de restaurants autour des monuments, mais deux explications sont possibles :
- **la demande touristique** : les visiteurs ont besoin de manger, donc les restaurants s'installent près des sites ;
- **l'agglomération** : les restaurants s'installent là où il y a déjà des restaurants (clientèle partagée, quartier « où l'on sort », appariement). Les sites touristiques étant souvent dans ces mêmes quartiers, la proximité au site pourrait n'être qu'une coïncidence géographique.

### Les hypothèses
- **H1** : le nombre de restaurants d'un carreau baisse avec la distance au site touristique le plus proche.
- **H2** : il augmente avec le nombre de restaurants dans les 8 carreaux voisins (sans compter le carreau lui-même).
- **H3** : l'effet de H1 baisse, voire disparaît, quand on contrôle H2.

### L'unité d'analyse
Des **carreaux de 200 m × 200 m** sur toute Nantes Métropole (24 communes). C'est l'échelle de la grille Insee, et elle est assez fine pour qu'un carreau corresponde à un pâté de maisons. On refera tout en **500 m** en robustesse, car les résultats peuvent dépendre de la taille de la grille (problème du MAUP).

---

## 2. Le cadrage et le retour de l'enseignante (avant le 08/11)

### Ce qu'on avait proposé
Un modèle de comptage (Poisson) avec 4 colonnes emboîtées : (1) la distance au site seule, (2) + la population, (3) + la distance au centre-ville, (4) + les restaurants voisins. On avait aussi proposé une **variable instrumentale** (2SLS/GMM) : les monuments Mérimée construits avant 1800, avec l'idée que leur emplacement a été fixé il y a des siècles, indépendamment des restaurants actuels.

### Ce que l'enseignante a répondu
- Le cadrage est **validé dans l'ensemble**.
- **Abandonner la variable instrumentale** (décision du 08/11). Un instrument doit agir sur les restaurants *uniquement* via la distance au site. Or un monument ancien est situé dans le vieux centre, qui attire aussi des restaurants pour d'autres raisons (densité, sorties, commerces), donc la condition d'exclusion est difficile à défendre. Les monuments anciens sont gardés, mais seulement comme **définition alternative des sites**, en robustesse.
- **Biais de variable omise** : pour chaque contrôle, il faut préciser le **sens** du biais. La règle : biais = effet de Z sur Y × lien entre Z et X.
- **Les restaurants voisins sont à la fois endogènes et en partie médiateurs.** Si le site attire des restaurants, qui en attirent d'autres, une baisse du coefficient de distance dans la colonne (4) ne prouve pas que l'agglomération « cause » quoi que ce soit. Il faut comparer avec et sans les voisins, et rester prudent.
- **Il faut distinguer deux problèmes** : des erreurs corrélées dans l'espace (les écarts-types sont faux, mais il n'y a pas de biais) et un régresseur lié à des facteurs inobservés (là, il y a biais).
- **Limite** : la distance ne mesure pas la fréquentation. Un petit monument peut être très visité, et inversement.
- **Piste de panel** : suivre les ouvertures de restaurants par carreau et par année, en fonction de la fréquentation des sites l'année précédente, avec des effets fixes carreau et année.
- **Ne garder que les établissements SIRENE actifs** à la date d'analyse.

### Nos décisions du 09/11
- **On ajoute un panel léger** pour répondre à la piste de l'enseignante. Sa forme est encore à fixer.
- **Sites** : tous les sites en spécification principale, monuments Mérimée antérieurs à 1800 en robustesse.
- **Restaurants** : SIRENE et OSM tous les deux dans les modèles. Ce choix a été précisé le 19/11 (voir partie 4).

---

## 3. Les données (10/11 au 17/11), script `01_donnees.R`

### Les sources

| Donnée | Source | Rôle |
| --- | --- | --- |
| Restaurants | SIRENE géolocalisée (codes NAF 56.10A et 56.10C), mise à jour du 30/09/2026 | Variable expliquée (Y) |
| Restaurants | OpenStreetMap (`amenity=restaurant`) | Seconde source, pour comparer |
| Sites touristiques | OSM (musées, attractions, monuments, mémoriaux), Mérimée (monuments historiques), Muséofile (musées), sites de Loire-Atlantique (Département 44) | Distance au site le plus proche (X) |
| Population | Filosofi 2019, carreaux de 200 m (Insee) | Contrôle de la demande locale |
| Communes | geo.api.gouv.fr | Contour de la métropole, cartes |
| Fréquentation | Lieux de visite de Loire-Atlantique 2009-2020 ; grands équipements de NM 2007-2013 | Pour le panel éventuel |

Toutes les URL et dates de téléchargement sont dans `data/raw/DATES.txt`. Les fichiers bruts ne sont jamais modifiés. Toutes les couches propres sont en Lambert 93 (EPSG 2154), donc les distances sont en mètres.

### Les problèmes rencontrés et ce qu'on a décidé

- **La grille couvre toute la métropole (13 384 carreaux).** Filosofi ne fournit que les carreaux habités. Si on ne gardait qu'eux, on perdrait les zones commerciales, les quais ou les carreaux près des monuments sans habitants, alors que des restaurants peuvent s'y trouver. Les carreaux absents de Filosofi ont donc une population de 0.
- **Les données Filosofi sont en partie imputées** : 44 % des carreaux habités ont une population estimée par l'Insee (secret statistique). C'est une limite à signaler, et la colonne `imputé` le permet.
- **Le premier fichier SIRENE était tronqué.** Celui du 10/11 n'avait qu'environ 80 % des lignes : 1 849 restaurants actifs géolocalisés. On l'a retéléchargé le 17/11 et on obtient **2 268 restaurants actifs**. Tous les chiffres antérieurs au 17/11 sont donc faux.
- **Définition d'un restaurant « actif »** : établi au 30/09/2026, date de mise à jour du fichier. Les 182 établissements marqués « fermé » sans date de fermeture sont exclus. Les fermés ont des coordonnées à 98,6 %, ce qui rend un panel des ouvertures et fermetures possible depuis 2008.
- **Les sites Mérimée sans coordonnées** (93 sur 157) ont été géocodés à partir de leur adresse avec la Base adresse nationale (85 retrouvés). 113 des 148 sites Mérimée retenus sont antérieurs à 1800 (colonne `ancien`).
- **Mémoriaux OSM** : 396 des 566 sites OSM sont des plaques, des stèles ou des monuments aux morts. On les garde avec un indicateur (colonne `memorial`) pour pouvoir décider ensuite, en principal ou en robustesse. La question est posée à l'enseignante (Q1).

### Le résultat
6 couches dans `data/clean/` :

| Couche | Lignes |
| --- | --- |
| Communes | 24 |
| Carreaux | 13 384 |
| Restaurants SIRENE | 6 598, dont 2 268 actifs |
| Restaurants OSM | 1 292 |
| Sites | 736 : OSM 566, Mérimée 148, Département 44 18, Muséofile 4 |
| Fréquentation des lieux | 16 lieux, de 2009 à 2020 |

Le projet est partagé sur GitHub. Les fichiers de plus de 100 Mo (SIRENE, Mérimée, Filosofi) ont été envoyés par WeTransfer.

---

## 4. Les variables spatiales (19/11), script `02_variables_spatiales.R`

Résultat : `data/clean/carreaux_variables.gpkg`, avec une ligne par carreau et toutes les variables du modèle.

### 4.1 Nombre de restaurants par carreau (la variable Y)

| | SIRENE actifs | OSM |
| --- | --- | --- |
| Restaurants comptés | 2 267 sur 2 268 (un seul hors de la grille) | 1 292 |
| Carreaux sans aucun restaurant | 93 % | 96 % |
| Maximum dans un carreau | 52 (quartier Bouffay) | 41 |
| Moyenne / variance | 0,17 / 1,85 | 0,10 / 0,80 |

Même parmi les carreaux habités, 88 % n'ont aucun restaurant. Les restaurants sont très concentrés.

**Décision 1 : binomiale négative attendue plutôt que Poisson.**
- *Résultat* : la variance est environ 11 fois plus grande que la moyenne (8 fois pour OSM).
- *Raisonnement* : le Poisson suppose une variance égale à la moyenne. Ici la surdispersion est forte, parce que les restaurants se regroupent au lieu de se répartir au hasard. Une partie de cette surdispersion disparaîtra avec les variables explicatives, donc il faut un test sur le modèle estimé.
- *Suite* : estimer les deux modèles dans le script 04 et trancher avec un test de surdispersion ou l'AIC.

**Décision 2 : tous les carreaux en spécification principale, les carreaux habités seulement en robustesse.**
- *Résultat* : 243 restaurants SIRENE, soit 11 % du total, sont dans des carreaux sans habitants.
- *Raisonnement* : un restaurant près d'un monument n'a pas besoin d'habitants à côté. Exclure ces carreaux retirerait une partie de ce qu'on cherche à expliquer. La limite : beaucoup de carreaux inhabités sont « impossibles » (Loire, champs, forêts) et gonflent les zéros. C'est pourquoi on fait la robustesse sur les 6 681 carreaux habités.

**Décision 3 : SIRENE en spécification principale, OSM en robustesse.**
- *Résultat* : les comptes SIRENE et OSM par carreau sont corrélés à 0,86.
- *Raisonnement* : les deux sources montrent la même géographie, donc deux modèles « au même niveau » répéteraient la même chose. SIRENE est plus complet, administratif, daté, et permet un panel grâce aux dates d'ouverture et de fermeture. OSM est contributif et inégal selon les quartiers. Mais SIRENE contient des établissements sans salle (sièges, domiciliations), donc OSM en robustesse vérifie que ce biais ne change pas les résultats.
- *Statut* : à confirmer avec l'enseignante (Q5).

### 4.2 Distance au site touristique le plus proche (la variable X)

Distance en km, mesurée depuis le centre du carreau, en trois versions :

| Version | Nombre de sites | Médiane | Médiane des carreaux avec restaurant | Corrélation avec la version « tous » |
| --- | --- | --- | --- | --- |
| `dist_site_tous` (principale) | 736 | 1,01 | 0,41 | 1 |
| `dist_site_sans_mem` (sans mémoriaux) | 340 | 1,28 | 0,78 | 0,98 |
| `dist_site_ancien` (Mérimée avant 1800) | 113 | 2,58 | 1,61 | 0,76 |

La version « monuments anciens » ne contient que des sites Mérimée, puisque seule cette source a une date de construction.

**Constat pour la question des mémoriaux (Q1).** On pensait que les mémoriaux, présents partout, rendaient la distance presque constante. Ce n'est pas le cas : sans eux, la médiane passe seulement de 1,01 à 1,28 km, et les deux versions sont corrélées à 0,98. La question des mémoriaux est donc surtout **conceptuelle** (une plaque commémorative est-elle un site touristique ?) plutôt que statistique. À noter aussi : la version avec mémoriaux est un peu plus liée aux restaurants (corrélation de rang -0,23 contre -0,17), sans doute parce que beaucoup de mémoriaux sont dans le centre.

### 4.3 Distance à la place du Commerce (le contrôle « centre-ville »)

- Médiane de 9,55 km. La position du point (lon -1.5584, lat 47.2131) est approximative, mais quelques dizaines de mètres d'écart ne changent rien.
- **Elle est corrélée à 0,72 avec la distance au site.** C'est la raison principale de la colonne (3) : les sites sont surtout dans le centre, comme les restaurants. Sans ce contrôle, la distance au site capterait probablement une partie de l'effet « centre-ville » (biais de variable omise, dont le sens est à écrire dans le dossier).

### 4.4 Restaurants des 8 carreaux voisins (pour H2 et H3)

- Voisinage de type **reine** (les 8 carreaux qui touchent, y compris par les coins). On fait une **somme** des restaurants des voisins (poids binaires), sans le carreau lui-même. 12 308 carreaux ont bien 8 voisins, les 1 076 autres sont en bordure de la métropole.
- Vérification à la main sur le carreau de Bouffay : 172 restaurants autour, le même chiffre que celui calculé par le script.
- `voisins_sirene` : médiane 0, maximum 255. 72 % des carreaux n'ont aucun restaurant autour.
- **Corrélation de 0,68 avec le nombre de restaurants du carreau** : cette variable va absorber beaucoup de variance dans la colonne (4). Ça montre que les restaurants se regroupent, pas qu'un restaurant en attire d'autres.
- **Corrélation de rang de -0,40 avec la distance au site** : c'est la condition pour que le coefficient de distance baisse dans la colonne (4). Reste à savoir comment présenter cette baisse : comme une **médiation** (le site attire des restaurants, qui en attirent d'autres) ou comme une **confusion** (les deux viennent du centre-ville). Nos données ne permettent pas de les distinguer, d'où la question posée à l'enseignante (Q2).

### Corrélations brutes avec le nombre de restaurants
Corrélations de rang entre `n_sirene` et les distances : -0,23 (site), -0,26 (place du Commerce). Elles sont faibles à cause des 93 % de zéros, et annoncent des effets probablement modestes.

---

## 5. Les cartes descriptives (19/11), script `03_cartes.R`

Réalisées par Nassim, en parallèle du script 02. Elles n'utilisent que les couches de `data/clean/`. Les PNG sont dans `output/cartes/`. Le script a été relancé le 19/11 pour vérifier qu'il est reproductible : il tourne en 12 s et redonne les mêmes images.

| Carte | Fichier | Ce qu'elle montre | Utilité |
| --- | --- | --- | --- |
| Zone d'étude | `01_zone_etude.png` | 24 communes, grille de 13 384 carreaux de 200 m | Présenter le terrain |
| Restaurants SIRENE et OSM | `02_restaurants_sirene_osm.png` | Restaurants par carreau, même échelle pour les deux sources | Q5 : choix de la source |
| Sites, mémoriaux ou non | `03_sites_memoriaux.png` et zoom `03b_sites_memoriaux_centre.png` | 736 sites, couleur selon `memorial`, forme selon la source | Q1 : les mémoriaux |
| Population | `04_population.png` | Population Filosofi, carreaux imputés entourés en orange | Contrôle de la demande locale, limite des données imputées |

### Ce qu'on en retient
- **Restaurants** : les deux sources montrent la même polarisation sur l'hypercentre et les grands axes, ce qui est cohérent avec la corrélation de 0,86. OSM sous-couvre les zones d'activités et les centres-bourgs de périphérie. C'est un argument de plus pour SIRENE en principal.
- **Population** : elle est concentrée dans Nantes et les centres secondaires, et une grande partie de la périphérie est inhabitée. Les carreaux imputés sont surtout en zone peu dense. Le cœur de l'analyse (le centre) est donc peu touché par l'imputation.
- **Sites** : les monuments Mérimée forment un noyau serré sur le centre historique et les quais, alors que les mémoriaux sont éparpillés dans tout le centre. Le zoom a été ajouté parce que, sur la carte entière, les points du centre se superposaient.

### Une interprétation corrigée : les mémoriaux ne sont pas « en périphérie »
La première interprétation de la carte 3 disait que les mémoriaux étaient dispersés dans toute la métropole et qu'ils raccourcissaient artificiellement la distance en périphérie. **Les chiffres disent l'inverse** :

| | Part dans la commune de Nantes | Distance médiane à la place du Commerce |
| --- | --- | --- |
| Mémoriaux OSM (396) | 84 % | 1,1 km |
| Autres sites (340) | 69 % | 2,3 km (sites OSM non mémoriaux) |

Les mémoriaux sont donc **plus centraux** que les autres sites. Ça explique le résultat du script 02 : les retirer ne change presque pas la distance au site le plus proche (médiane de 1,01 à 1,28 km, corrélation de 0,98). La question des mémoriaux n'est pas un problème de variation de la distance. C'est une question de **définition** : une plaque commémorative est-elle un site touristique ?

Leçon de méthode : une impression visuelle sur une carte chargée doit être vérifiée par un chiffre avant d'être écrite.

Autre correction : l'interprétation de la carte 2 parlait d'un « modèle avec excès de zéros ». Ce choix n'est pas fait (la binomiale négative est attendue, et le test sera fait dans le script 04), donc la mention a été retirée.

---

## 6. Les consignes finales (19/11)

Lors de la séance du 19/11, l'enseignante a donné les consignes définitives (`docs/consignes_finales.pdf`). Elles ne changeront plus.

- **Pas de dossier écrit.** Le projet est évalué sur les slides, le code et l'oral.
- **Rendu le lundi 23/11/2026 à 23h59** : les slides en PDF (`JamesonSAUSSEREAU_NassimIKHELEF.pdf`), les scripts reproductibles et commentés, et les données.
- **Oral le jeudi 26/11/2026, de 10h40 à 11h00, salle 304** : 15 min de présentation et 5 min de questions.
- **Structure conseillée** : introduction (question, mécanismes, hypothèses), données (sources, variables géographiques, statistiques descriptives, carte), méthodologie (modèle, identification), résultats (coefficients, robustesse), discussion (limites, réponse à la question).
- **Critères** : raisonnement économique, données et outils spatiaux, économétrie, avec une discussion des biais de **variables omises et de causalité inverse**, interprétation des coefficients, oral (chacun doit maîtriser tout le projet), et code exécutable du début à la fin qui reproduit tous les résultats des slides.

### Ce que ça change pour nous
- Tout ce qui était prévu pour le dossier (biais de variable omise, limites) passe dans les slides et la préparation de l'oral.
- **La causalité inverse** devient un point à traiter explicitement. Les monuments anciens (Mérimée avant 1800) sont antérieurs aux restaurants actuels, mais pas toujours les sites OSM. Pour les restaurants voisins, la causalité va dans les deux sens par construction.
- **Avec 4 jours avant le rendu et 15 minutes d'oral**, il faut décider si le panel est gardé ou seulement cité comme piste.
- **Les données brutes pèsent 1,6 Go.** Il faut choisir ce qu'on rend.

---

## 7. En cours et à venir

- **Décisions** : panel gardé ou non ; données à rendre ; mémoriaux ; date d'analyse SIRENE.
- **Cartes restantes** : distance au site le plus proche (avec `carreaux_variables.gpkg`), puis résidus du modèle après le script 04.
- **Carreaux de 500 m et panel** : à faire après la réunion.
- **Modèles** (`04_modeles.R`, priorité) : les 4 colonnes emboîtées, le test entre Poisson et NB, les robustesses, l'indice de Moran sur les résidus.
- **Reproductibilité** : chaîne 01 → 04 sur une session vierge et chez Nassim.
- **Slides** (rendu le 23/11) **et oral** (26/11).
