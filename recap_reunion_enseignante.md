# Récap réunion avec l'enseignante (19/11/2026)

## Ce qu'elle a dit
- **Modèle** : tester `fepois()` (package fixest), c'est-à-dire un Poisson par pseudo-maximum de vraisemblance (PPML).
- **Carreaux** : ne pas prendre en compte les carreaux où il ne peut y avoir ni population ni restaurant (eau, forêts, champs), ou alors faire un tri méticuleux. Exclure aussi les carreaux à population nulle.
- **Site touristique ou densité de restaurants** : le mieux serait d'utiliser la fréquentation des sites touristiques, en variable de contrôle (en plus de la distance, pas à la place).

## Nos décisions (19/11)

| Point | Décision | Raison |
| --- | --- | --- |
| Modèle | `fepois()` en principal, binomiale négative en robustesse | La PPML reste valable avec de la surdispersion si les écarts-types sont robustes |
| Effets fixes | Ajout d'effets fixes commune | Contrôlent une partie de l'effet de centralité |
| Carreaux | Tous les carreaux en principal, carreaux habités en robustesse | Les carreaux sans population ne sont pas que de l'eau ou des forêts : zones d'affaires, zones commerciales (243 restaurants, 11 %) |
| Fréquentation | Ajoutée en contrôle, en coupe transversale | Le panel est trop long à faire avant le 23/11 ; 15 lieux de NM avec coordonnées (2009-2020) |
| Panel | Pas estimé, cité comme piste dans les limites | Manque de temps |
| Mémoriaux | Exclus des sites | Pas de logique économique (plaques, stèles, monuments aux morts) |

## Questions non traitées (on garde les choix actuels)
- Restaurants voisins avec ou sans (Q2) : colonne (4), interprétation prudente.
- Forme du panel (Q3) : remplacée par la fréquentation en coupe.
- Date d'analyse SIRENE (Q4) : actifs au 30/09/2026.
