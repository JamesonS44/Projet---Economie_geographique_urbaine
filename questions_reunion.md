# Questions réunion – projet éco. géo. urbaine (17/11/2026)

Phrase d'ouverture : 01_donnees.R écrit et testé, 1 849 restos SIRENE actifs, 1 331 OSM, 13 384 carreaux de 200 m.

| Temps | Question | Priorité |
| --- | --- | --- |
| 0-3 min | Q1 Mémoriaux dans les sites | Haute |
| 3-5 min | Q2 Modèle avec/sans restaurants voisins | Haute |
| 5-7 min | Q3 Panel léger : forme minimale | Haute |
| 7-9 min | Q4 Date d'analyse SIRENE | Moyenne |
| 9-11 min | Q5 SIRENE et OSM dans les modèles | Moyenne |
| 11-12 min | Q6 Rendu : format et date | Si temps |

## Q1. Mémoriaux OSM dans les sites touristiques
Sur 598 sites OSM, 409 sont des mémoriaux (plaques, stèles, monuments aux morts). Faut-il les garder comme « sites touristiques » ?
- Problème : ils sont partout, donc la distance au site le plus proche varie peu et H1 devient difficile à tester.
- Options : A tous inclus ; B exclus ; C exclus en principal, inclus en robustesse ; D exclus sauf ceux taggés attraction ou wikipedia.
- Relance : une règle de tri sur les tags OSM est-elle défendable à l'écrit ?

## Q2. Modèle avec ou sans restaurants voisins
Les restaurants voisins sont endogènes et en partie médiateurs. Colonnes (1)-(3) sans, (4) avec, et la baisse du coefficient de distance interprétée comme une simple corrélation : est-ce suffisant ?
- Relance : faut-il décaler les voisins (stock d'une année antérieure) ou juste discuter la limite ?

## Q3. Panel léger : forme minimale attendue
La fréquentation des grands équipements n'existe que pour 2007-2013. Quelle version minimale est attendue ?
- Options : ouvertures par carreau × année sur 2008-2014 avec effets fixes carreau + année ; ou une simple section « piste » sans estimation.
- Autre option : utiliser la fréquentation des lieux de visite de Loire-Atlantique (15 lieux dans NM, entrées annuelles 2009-2020, avec coordonnées) au lieu des grands équipements (5 équipements, 2007-2013, sans coordonnées). Panel plus long et plus de lieux.
- Relance : rayon 2-5 km imposé ou au choix ?

## Q4. Date d'analyse SIRENE
Établissements actifs au 30/09/2026 (date de mise à jour du fichier) ; 182 « fermés » sans date exclus. Ça convient ?

## Q5. SIRENE et OSM dans les modèles (à confirmer)
Notre choix (19/11) : SIRENE en principal, OSM en robustesse, car corrélation par carreau de 0,86. Juste confirmer.
SIRENE 1 849 restos, OSM 1 331. SIRENE en principal et OSM en robustesse, ou deux modèles au même niveau ?

## Q6. Rendu (si temps)
Format attendu (rapport, longueur), date de rendu, soutenance orale ou non ?

## Réponses (à remplir pendant la réunion)

| Question | Réponse | Action |
| --- | --- | --- |
| Q1 Mémoriaux | | |
| Q2 Restaurants voisins | | |
| Q3 Panel | | |
| Q4 Date SIRENE | | |
| Q5 SIRENE / OSM | | |
| Q6 Rendu | | |
