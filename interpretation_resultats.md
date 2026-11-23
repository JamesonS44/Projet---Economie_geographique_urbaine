# Interprétation des résultats (script 04, mise à jour du 20/11/2026)

Tous les chiffres sortent des scripts 02 → 03 → 04 (tableaux dans `output/tableaux/`, cartes dans `output/cartes/`).
Modèle : Poisson PPML (`fepois`), Y = nombre de restaurants SIRENE par carreau de 200 m, 13 384 carreaux.
Erreurs-types de Conley, seuil 1 km.

## Réglages retenus (validés le 20/11)
- **Restaurants SIRENE :** actifs au 30/09/2026, **sans les adresses empilées** (5 restaurants ou plus au même point GPS). On passe de 2 268 à 2 082 restaurants. Filtre fait dans 02 (et repris dans 03 pour les cartes). Voir section 9.
- **Distance au site en log** (`log_dist` = log de `dist_site_sans_mem`, en km, mémoriaux exclus). Le coefficient est une élasticité. L'effet se lit pour un doublement de la distance : 2^coef − 1.
- **Population** en centaines d'habitants.
- **Potentiel de fréquentation** = Σ entrées / distance, en centaines de milliers d'entrées par km, sur 15 lieux. Entrées : moyenne 2009-2019 ; années à 0 (lieu fermé) et 2020 (Covid) exclues ; cour du château seule (elle inclut déjà les visiteurs du musée) ; distance minimale de 100 m.
- Effets fixes commune et potentiel seulement en colonne (5).

## 0. Statistiques descriptives (`stats_descriptives.csv`)

| Variable | Moyenne | Écart-type | Médiane | Max |
| --- | --- | --- | --- | --- |
| Restaurants SIRENE | 0,16 | 1,25 | 0 | 52 |
| Restaurants OSM | 0,10 | 0,90 | 0 | 41 |
| Distance au site (km) | 1,73 | 1,87 | 1,28 | 15,2 |
| Distance place du Commerce (km) | 9,86 | 4,71 | 9,55 | 28,4 |
| Population | 46,9 | 110,2 | 0 | 3 247 |
| Restaurants voisins | 1,24 | 7,05 | 0 | 255 |
| Potentiel de fréquentation | 3,50 | 3,99 | 2,55 | 141,6 |

93,4 % des carreaux n'ont aucun restaurant ; 1 % des carreaux concentre 51 % des restaurants. Variance / moyenne de Y = 10,0 : il y a de la surdispersion, ce qui n'est pas gênant pour le PPML (il ne demande que la moyenne bien spécifiée).

## 1. Modèles principaux

| Variable | (1) | (2) | (3) | (4) | (5) EF commune |
| --- | --- | --- | --- | --- | --- |
| Distance au site ×2 | −55,7 %*** | −52,8 %*** | −38,1 %*** | −24,9 %*** | −20,1 %*** |
| Population (+100 hab.) | | +23,9 %*** | +16,0 %*** | +14,6 %*** | +13,7 %*** |
| Distance place du Commerce (+1 km) | | | −24,1 %*** | −22,3 %*** | −28,9 %*** |
| Restaurants voisins (+1) | | | | +1,1 %*** | +1,1 %*** |
| Potentiel de fréquentation (+1) | | | | | +0,2 % (n.s.) |
| Pseudo R² | 0,25 | 0,33 | 0,41 | 0,45 | 0,46 |

Coefficients bruts de `log_dist` : −1,18 ; −1,08 ; −0,69 ; −0,41 ; −0,32.

## 2. H1 : distance aux sites
- Le lien est négatif et significatif à 0,1 % dans les 5 colonnes, et significatif dans toutes les robustesses. C'est le résultat le plus solide.
- Colonne (4) : quand la distance au site le plus proche double, il y a 25 % de restaurants en moins, à population, centralité et voisins égaux (20 % avec les EF commune). C'est vrai à 100 m comme à 1 km. En mètres, la baisse est donc très forte près des sites et faible loin d'eux.
- La forme en log s'ajuste nettement mieux que la distance en km (BIC 8 884 contre 8 957). L'effet d'un site se joue sur les premières centaines de mètres : un restaurant cherche à être juste à côté du site, pas seulement dans le même quartier.
- La colonne (1) (−56 %) mélange l'effet des sites et l'effet du centre-ville, car les sites sont concentrés dans l'hypercentre.

## 3. Biais de variable omise : les 4 contrôles vont dans le sens prévu
Règle : biais = effet de Z sur Y × lien Z–X.

| Contrôle Z | Effet de Z sur Y | Lien de Z avec la distance | Biais attendu sans Z | Observé (coef. de `log_dist`) |
| --- | --- | --- | --- | --- |
| Population | + | faible | Faible | −1,18 → −1,08 : presque rien |
| Centralité (place du Commerce) | − | + (corr. 0,54, avec ln distance) | Distance trop négative | −1,08 → −0,69 (−36 %) |
| Restaurants voisins | + | − | Distance trop négative | −0,69 → −0,41 (−40 %) |
| Potentiel et EF commune | + | − (corr. −0,40) | Distance trop négative | −0,41 → −0,32 |

Les facteurs de confusion importants sont la centralité et la densité de restaurants autour, pas la population.

## 4. H2 : agglomération
- En Poisson, chaque restaurant voisin ajoute 1,1 % de restaurants. La variable va de 0 à 255. Pour les carreaux qui ont au moins un restaurant, passer de la médiane des voisins (3) au 90e centile (16) donne environ +16 % ; au 99e centile (152), environ ×5,5.
- En binomiale négative, les voisins ne sont plus significatifs (0,031, erreur-type 0,032). Explication :
  - 1 % des carreaux concentre 51 % des restaurants. Le PPML pèse les carreaux selon leur nombre de restaurants, donc l'hypercentre le domine ; la binomiale négative donne plus de poids aux carreaux à 0 ou 1 restaurant, où les voisins varient peu.
  - La binomiale négative prédit très mal les niveaux (corrélation au carré entre prédit et observé : 0,02 contre 0,56).
  - C'est un argument pour garder le PPML en principal, mais l'effet des voisins repose surtout sur les carreaux très denses.
- L'effet n'est pas causal. La causalité inverse est mécanique (chaque carreau est le voisin de ses voisins), et des chocs communs jouent sur les deux (passage piéton, loyers, zones piétonnes). On mesure une concentration, pas un effet d'agglomération démontré.

## 5. H3 : partiellement validée
- Ajouter les voisins fait baisser le coefficient de distance de 40 % (−0,69 → −0,41), mais il reste très significatif.
- Les voisins sont en partie un médiateur (les sites attirent des restaurants, qui en attirent d'autres). Une partie de la baisse est peut-être de l'effet des sites qui passe par les voisins : elle ne prouve pas que l'agglomération est la vraie cause.
- Formulation : « À densité de restaurants voisins donnée, la proximité d'un site reste associée à plus de restaurants. »

## 6. Colonne (5) : effets fixes commune et fréquentation
- La distance au site résiste aux EF commune (−0,32, p < 0,001). Le résultat ne vient pas seulement d'un écart entre Nantes et les autres communes.
- La distance à la place du Commerce reste forte (−29 %/km) à l'intérieur des communes, car Nantes compte à elle seule 1 646 carreaux, avec un vrai gradient entre centre et périphérie.
- **Le potentiel de fréquentation n'est pas significatif** (0,0016, erreur-type 0,0014). Lecture :
  - Avec le log, la distance capte déjà très bien la proximité immédiate des grands sites (château, Machines) : la fréquentation n'ajoute presque rien.
  - Il est corrélé à 0,65 avec les voisins, qui captent une partie de l'effet.
  - Il ne couvre que 15 lieux et oublie les sites gratuits (cathédrale, Jardin des Plantes, passage Pommeraye).
  - Conclusion : on ne trouve pas que la fréquentation d'un site compte en plus de sa proximité. Ce n'est pas une preuve que la fréquentation ne joue pas : notre mesure est trop partielle pour le montrer. Résultat non significatif mais rigoureux, ce que la consigne accepte.
- La fréquentation est endogène (exemple : l'île de Nantes a été réaménagée en même temps qu'on y installait les Machines et des restaurants). La moyenne 2009-2019 limite ce problème sans le supprimer.

## 7. Robustesses (sur la colonne 4)

| Version | Coefficient de distance | Lecture |
| --- | --- | --- |
| Principal (log, Conley 1 km) | −0,41*** | |
| Binomiale négative | −0,32** | Voisins non significatifs (voir section 4) |
| Sites anciens (Mérimée < 1800) | −0,37*** | Presque identique au principal. Argument principal contre la causalité inverse : ces monuments ont précédé les restaurants actuels, et ils donnent le même effet |
| Avec mémoriaux | −0,47*** | Un peu plus fort, car les mémoriaux sont très centraux (84 % à Nantes) |
| Carreaux habités | −0,41*** | Identique |
| OSM | −0,41*** | Identique, avec une autre source |
| Cluster commune | −0,41*** (SE 0,056) | Erreurs-types proches de Conley (0,061) |
| Conley 2 km | −0,41*** (SE 0,052) | La conclusion ne dépend pas du seuil |
| Distance en km | −0,63*** par km | Moins bon ajustement (BIC 8 957 contre 8 884) |

Toutes les variantes donnent un coefficient entre −0,32 et −0,47. Le résultat ne dépend ni de la source des restaurants, ni de la définition des sites, ni des carreaux retenus, ni du modèle, ni du calcul des erreurs-types.

## 7 bis. Robustesse en carreaux de 500 m (`05_robustesse_500m.R`, `robustesse_500m.txt`)
Grille de 500 m alignée sur l'INSEE : 2 129 carreaux. La population est agrégée depuis les carreaux de 200 m (on perd 0,1 % en bordure), et 2 078 restaurants sur 2 082 sont comptés. 77 % des carreaux sont sans restaurant (contre 93 % à 200 m).

| | (4) 200 m | (4) 500 m | (5) 200 m | (5) 500 m | (4) 500 m OSM |
| --- | --- | --- | --- | --- | --- |
| Coef. de `log_dist` | −0,41*** | −0,25*** | −0,32*** | −0,20** | −0,29*** |
| Distance ×2 | −24,9 % | −15,8 % | −20,1 % | −12,9 % | −18,0 % |
| Potentiel | | | n.s. | n.s. | |

- **Le signe et la significativité tiennent** : la distance aux sites reste négative et significative à 500 m, en colonne (4), en colonne (5) et avec OSM. Le résultat ne vient pas du découpage choisi (MAUP).
- **L'effet est plus faible à 500 m**, et c'est attendu. L'effet d'un site joue sur les premières centaines de mètres (c'est ce que montre le log). Un carreau de 500 m mélange des restaurants collés au site et d'autres à 400 m, et la distance mesurée depuis le centre du carreau est plus approximative. Les grands carreaux diluent donc un effet très local. Ce résultat confirme qu'il est très local.
- Les autres coefficients (population, voisins) ne se comparent pas directement entre les deux grilles : un carreau de 500 m fait 6,25 fois la surface d'un carreau de 200 m, donc « +100 habitants » ou « +1 voisin » n'ont pas le même poids.
- Le potentiel de fréquentation n'est toujours pas significatif. Moran sur les résidus : I = 0,065, du même ordre qu'à 200 m.

## 8. Résidus : Moran et cartes (`06_residus.png`, `06b_residus_centre.png`)
- Moran : autocorrélation significative mais faible (I = 0,070 en colonnes 4 et 5, p < 0,001). C'est un problème d'erreurs-types, que Conley corrige ; ce n'est un biais que si une variable omise corrélée dans l'espace est aussi liée à la distance.
- Les plus gros résidus sont maintenant des petits groupes de 2 à 8 restaurants en périphérie (Le Pellerin, Saint-Aignan-Grandlieu près de l'aéroport, Vertou, Couëron, Carquefou), là où le modèle prédit presque 0. Ce sont des **centralités locales** (centres-bourgs) et des **zones commerciales**, que la distance à la place du Commerce ne mesure pas. C'est la principale variable omise visible.
- On voit aussi des alignements de carreaux rouges le long de grands axes (sud de Rezé et Vertou) : restaurants de bord de route.
- Zoom sur le centre : on voit un damier de carreaux rouges et bleus juste à côté les uns des autres. Le modèle prédit beaucoup de restaurants dans tout l'hypercentre, à cause des voisins, alors que les restaurants se concentrent dans certaines rues (Bouffay). Les carreaux voisins sans restaurants (places, château, grands axes) sont alors surestimés. C'est une conséquence mécanique de la variable des voisins.
- Il y a 528 carreaux avec un résidu > 2 et seulement 12 avec un résidu < −2 : le modèle rate surtout des restaurants « inattendus », rarement des absences.

## 9. Adresses empilées dans SIRENE (retirées en principal)
- Avant le filtre, les 4 plus gros résidus étaient des carreaux où **tous les restaurants étaient au même point GPS** : 47 établissements à un seul point dans le nord de Nantes, 23 à un autre, 11 près d'Atlantis, 6 près de l'aéroport.
- Au point à 47 établissements : surtout de la restauration rapide (56.10C), créée presque entièrement en 2024-2026. Ce sont très probablement des **adresses de domiciliation** (camions-restaurants, cuisines pour la livraison, entreprises déclarées chez un domiciliataire), pas de vrais restaurants avec salle.
- Règle retenue : on retire les points GPS qui portent 5 restaurants ou plus, soit 18 points et **186 restaurants (8 %)**.
- Effet sur les résultats (colonne 4) : distance −0,35 → −0,41, corrélation au carré 0,49 → 0,56. Ces adresses étaient loin des sites et tiraient l'effet vers 0. Les conclusions ne changent pas.
- Limite à dire : le seuil de 5 est un choix. Mais les points concernés sont nets (47, 23, 13, 11…), et une vraie rue de restaurants a des adresses différentes, donc des points différents.

## 10. Avertissement de R
« VCOV matrix is not positive definite and was 'fixed' » pour la colonne (5). C'est fréquent avec les erreurs-types de Conley : fixest corrige la matrice en ramenant à 0 ses valeurs propres négatives. Les erreurs-types restent du même ordre que celles des autres méthodes, donc ce n'est pas un problème pour la conclusion. À citer en une ligne si on nous pose la question.

## 11. Limites
1. Associations, pas effets causaux : pas d'instrument, panel seulement cité comme piste.
2. On ne prend que la distance au site le plus proche, pas le nombre de sites autour.
3. Les voisins sont endogènes et en partie médiateurs.
4. La fréquentation est endogène, couvre 15 lieux et oublie les sites gratuits ; elle n'est pas significative.
5. Les résultats reposent beaucoup sur l'hypercentre (1 % des carreaux = 51 % des restaurants).
6. Variable omise visible sur les résidus : les centralités locales et les zones commerciales de périphérie.
7. SIRENE compte des établissements domiciliés : retirés avec un seuil de 5 au même point (choix arbitraire mais net).
8. Une part de la population Filosofi est imputée. Découpage (MAUP) : le résultat tient à 500 m, avec un effet plus faible (−16 % au lieu de −25 % par doublement).

## 12. Réponse à la question
Les restaurants se placent près des deux. La proximité des sites touristiques est un lien robuste et très local : quand la distance double, il y a 20 à 25 % de restaurants en moins. Il tient aux contrôles, aux effets fixes, à la source des données, au seuil de Conley, à la taille des carreaux (500 m) et aux monuments anciens, qui écartent l'essentiel de la causalité inverse. La concentration entre restaurants est très forte, mais elle repose sur l'hypercentre et ne peut pas être lue comme causale. La fréquentation des sites n'ajoute rien une fois la proximité prise en compte, mais notre mesure de la fréquentation est partielle.

## Reste à faire
- Slides, test de reproductibilité (01 → 04 sur une session vierge et chez Nassim).
