# Cadrage du projet : restaurants, tourisme et agglomération

M2 ECAP – IAE Nantes – Économie géographique et urbaine appliquée

## 1. Sujet

**Les restaurants se localisent-ils près des sites touristiques, ou simplement près d'autres restaurants ?**
Une analyse à l'échelle de carreaux de 200 m à Nantes Métropole.

Rattachement : proposition n°9 de la consigne, adaptée pour séparer deux mécanismes (attraction touristique et économies d'agglomération).

## 2. Question de recherche et hypothèses

- **Question principale :** la proximité d'un site touristique est-elle associée à un plus grand nombre de restaurants, une fois pris en compte la population locale et la présence d'autres restaurants dans le voisinage ?
- **H1 (demande touristique) :** le nombre de restaurants par carreau diminue avec la distance au site touristique le plus proche.
- **H2 (agglomération) :** le nombre de restaurants d'un carreau augmente avec la densité de restaurants dans les carreaux voisins.
- **H3 (séparation des deux effets) :** l'effet touristique de H1 diminue (ou disparaît) quand on contrôle H2. Un résultat non significatif reste un résultat valide.

Mécanismes mobilisés : économies d'agglomération (partage, appariement, apprentissage), effet de la demande locale, localisation des commerces par rapport au flux de clients.

## 3. Zone d'étude et unité d'analyse

- **Zone :** Nantes Métropole (à confirmer selon la disponibilité des données ; repli possible sur la seule ville de Nantes).
- **Unité :** carreau de 200 m × 200 m (grille Insee), avec une variante à 500 m en test de robustesse.
- **Variable expliquée :** nombre de restaurants dans le carreau.

## 4. Données

| Donnée | Source | Usage |
|---|---|---|
| Restaurants | SIRENE géolocalisée (NAF 56.10A et 56.10C), ou OpenStreetMap (`amenity=restaurant`) | variable expliquée |
| Sites touristiques | OSM (`tourism=attraction`, `museum`, monuments) et/ou base Mérimée | distance au site le plus proche |
| Population | données carroyées Insee (Filosofi, 200 m) | contrôle de la demande locale |
| Fonds de carte | IGN Admin Express, limites communales | cartes |

À vérifier avant de démarrer : couverture des sites touristiques dans OSM pour la zone, noms exacts des colonnes SIRENE, présence des coordonnées.

## 5. Variables spatiales construites

1. **Distance** du centroïde du carreau au site touristique le plus proche (en mètres).
2. **Nombre de sites** touristiques dans un rayon de 500 m (variante).
3. **Densité de restaurants voisins :** nombre de restaurants dans les carreaux contigus (voisinage de type reine), **sans** le carreau lui-même.
4. **Distance au centre-ville** (contrôle).

## 6. Stratégie économétrique

- **Modèle principal :** régression de Poisson, ou binomiale négative en cas de surdispersion (test à faire), sur le nombre de restaurants par carreau.
- **Spécifications emboîtées :**
  1. restaurants ~ distance au site touristique
  2. + population du carreau
  3. + distance au centre-ville
  4. + densité de restaurants voisins
- **Interprétation :** coefficients en semi-élasticités (ou rapports de taux d'incidence), comparés entre les colonnes pour voir ce qui se passe quand on ajoute l'agglomération.
- **Robustesse :** carreaux de 500 m, autre définition des sites, exclusion des carreaux sans population, erreurs-types robustes ou clusterisées par commune.
- **Diagnostic spatial :** indice de Moran sur les résidus.

## 7. Cartes prévues

1. Zone d'étude : limites, carreaux, sites touristiques.
2. Distribution des restaurants (points) et densité par carreau.
3. Distance au site touristique le plus proche.
4. Population par carreau.
5. Résidus du modèle (zones sur- et sous-prédites).

## 8. Limites à discuter

- **Identification causale faible :** les sites touristiques sont surtout en centre-ville, où se trouvent aussi la population et les restaurants. La distance peut capter un effet centre plutôt qu'un effet touristique.
- **Biais mécanique de la densité voisine :** cette variable est corrélée au nombre de restaurants du carreau (autocorrélation spatiale). On la calcule sans le carreau, mais le problème d'endogénéité de la localisation reste.
- **Qualité des données :** SIRENE contient aussi des établissements non diffusibles ou des changements de SIRET sans ouverture réelle. OSM est inégalement complet.
- **Demande touristique non mesurée :** la fréquentation réelle des sites n'est pas observée, seule leur localisation l'est.
- **MAUP :** les résultats peuvent dépendre de la taille des carreaux, d'où le test à 500 m.

## 9. Reproductibilité

- Scripts R numérotés : `01_donnees.R`, `02_variables_spatiales.R`, `03_cartes.R`, `04_modeles.R`.
- Dossier `data/` pour les données brutes et `output/` pour les cartes et tableaux.
- Packages prévus : `sf`, `osmdata`, `dplyr`, `ggplot2`, `spdep`, `MASS` ou `fixest`.
- Fixer la date de téléchargement des données dans le rapport.

## 10. Plan de travail

1. Valider la zone d'étude et télécharger les données.
2. Construire la grille et les variables spatiales.
3. Produire les cartes descriptives.
4. Estimer les modèles et les tests de robustesse.
5. Rédiger l'interprétation et les limites.
6. Nettoyer le code et vérifier la reproductibilité.
