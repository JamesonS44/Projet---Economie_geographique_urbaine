# À dire par slide (oral du 26/11, 15 min)

Environ 1 min par slide. Repères, pas de phrases à lire.

## 1. Titre (20 s)
- Binôme, M2 ECAP
- Sujet : localisation des restaurants à Nantes Métropole
- Unité d'analyse : carreau de 200 m
- Carte = distance au site touristique le plus proche (on y revient slide 5)

## 2. Question et hypothèses (1 min 15)
- Deux logiques de localisation
  - sites : demande des visiteurs, passage piéton
  - autres restaurants : agglomération (demande partagée, comparaison, clientèle attirée par la rue) malgré la concurrence
- Question précise, pas descriptive : laquelle des deux ? les deux ?
- H1 : distance au site ↑ → restaurants ↓
- H2 : restaurants des 8 voisins (reine, sans le carreau) ↑ → restaurants ↑
- H3 : effet de H1 baisse quand on contrôle H2 → test de la « vraie » cause

## 3. Données (1 min 15)
- SIRENE : NAF 56.10A (traditionnel) + 56.10C (rapide), actifs au 30/09/2026 → variable Y
- OSM : 1 292 restaurants, seulement en robustesse (corr. 0,86 avec SIRENE)
- Sites : 4 sources croisées (OSM, Mérimée, Muséofile, Département 44) → 736, dont 340 sans mémoriaux
- Filosofi 2019 : population par carreau, 13 384 carreaux (inhabités gardés)
- Fréquentation : 15 grands lieux, moyenne 2009-2019 (2020 Covid exclu)
- Nettoyage
  - adresses empilées : ≥ 5 restaurants au même point GPS = domiciliations, surtout restauration rapide créée en 2024-2026 → 186 retirés (8 %), 2 082 restants
  - mémoriaux OSM (plaques, stèles) : pas des attractions → exclus en principal

## 4. Carte des restaurants (1 min)
- 93 % des carreaux sans restaurant → beaucoup de zéros → modèle de comptage
- 1 % des carreaux = 51 % des restaurants (hypercentre, Bouffay)
- Pôle secondaire vers Saint-Herblain
- OSM couvre mal la périphérie et les zones d'activités → SIRENE en principal

## 5. Sites et distance (1 min)
- Variable spatiale principale : distance (km, vol d'oiseau) du centre du carreau au site le plus proche
- 396 mémoriaux sur 736 sites, très centraux (84 % à Nantes) → exclus en principal, remis en robustesse
- Médiane 1,28 km ; < 1 km dans le centre et près des bourgs anciens ; 3-5 km et plus dans l'ouest et le sud
- Forte variation → utile pour identifier l'effet
- Distance en log dans les modèles (élasticité)

## 6. Méthode (1 min 15)
- Y = nombre de restaurants par carreau → Poisson PPML (`fepois`)
  - convergent avec beaucoup de zéros et de la surdispersion (variance / moyenne = 10)
  - demande seulement que la moyenne soit bien spécifiée
  - binomiale négative en robustesse
- Lecture : ln(distance) → effet d'un doublement de la distance = 2^β − 1
- 5 colonnes, contrôles ajoutés un par un → on voit le biais bouger
  - (2) population (en centaines) ; (3) distance à la place du Commerce (centralité) ; (4) voisins ; (5) potentiel de fréquentation + EF commune
- Erreurs-types de Conley 1 km : carreaux proches corrélés
- Pas de VI (abandonné après retour) : on parle d'associations

## 7. Biais de variable omise (1 min 15)
- Règle : biais = effet de Z sur Y × lien Z–distance
- Population : lien faible avec la distance → biais faible (−1,18 → −1,08)
- Centralité : centre = moins de restaurants quand on s'en éloigne, et sites concentrés au centre (corr. 0,54) → sans elle, distance trop négative (−1,08 → −0,69)
- Voisins : + sur Y, − avec la distance → distance trop négative (−0,69 → −0,41)
- Potentiel + EF commune : même sens (−0,41 → −0,32)
- Les 4 corrections vont dans le sens prévu
- Message : les vraies confusions = centre-ville + densité de restaurants, pas la population

## 8. Causalité inverse (1 min 15)
- Risque : les restaurants attirent-ils les sites (ou le classement d'un lieu) ?
- Monuments d'avant 1800 (Mérimée) : bien antérieurs aux restaurants actuels → même coef. (−0,37 contre −0,41) → argument principal contre la causalité inverse
- Voisins : causalité inverse mécanique (chaque carreau est voisin de ses voisins) + chocs communs (passage, loyers, zones piétonnes) → pas d'effet causal de l'agglomération
- Fréquentation endogène : ex. île de Nantes réaménagée en même temps que les Machines et les restaurants → moyenne 2009-2019 limite sans supprimer

## 9. Résultats principaux, H1 (1 min 30)
- Distance au site : négatif, significatif à 0,1 % dans les 5 colonnes
- Col. (4) : distance ×2 → −25 % de restaurants, à population, centralité et voisins égaux
- Col. (5), EF commune : −20 % → pas seulement un écart Nantes / autres communes
- Col. (1) −56 % : mélange effet des sites et effet du centre
- Population : +100 hab. → +14 à +16 %
- Place du Commerce : +1 km → −22 à −29 % (vrai gradient même à l'intérieur de Nantes, 1 646 carreaux)
- Potentiel de fréquentation : n.s.
  - la distance en log capte déjà la proximité des grands sites
  - corrélé à 0,65 avec les voisins
  - 15 lieux payants seulement (oublie cathédrale, Jardin des Plantes, passage Pommeraye)
  - non significatif mais rigoureux : mesure trop partielle, pas preuve d'absence d'effet
- Log mieux que km : BIC 8 884 contre 8 957 → effet joué sur les premières centaines de mètres

## 10. H2 et H3 (1 min 15)
- H2 : +1,1 % par restaurant voisin (de la médiane 3 au 90e centile 16 → environ +16 %)
- Mais non significatif en binomiale négative
  - PPML pèse les carreaux denses (hypercentre), NB les carreaux à 0-1 restaurant
  - NB prédit très mal les niveaux (corr² 0,02 contre 0,56) → on garde PPML
- Concentration forte, pas effet causal d'agglomération (slide 8)
- H3 : coef. de distance −0,69 → −0,41 (−40 %) avec les voisins, reste très significatif
- Voisins en partie médiateurs (site → restaurants → autres restaurants) : la baisse ne prouve pas que l'agglomération est la vraie cause
- Formule : « à densité de voisins donnée, la proximité d'un site reste associée à plus de restaurants » → H3 partielle

## 11. Robustesse (1 min)
- Toutes sur la colonne (4)
- Coefficient entre −0,32 et −0,47 dans toutes les variantes à 200 m
  - NB −0,32 ; sites anciens −0,37 ; avec mémoriaux −0,47 (très centraux) ; habités, OSM, cluster commune, Conley 2 km : −0,41
- Distance en km : aussi significatif, moins bon ajustement
- 500 m (2 129 carreaux, MAUP) : −0,25, soit −16 % par doublement, toujours significatif
  - plus faible : un grand carreau mélange restaurants collés au site et à 400 m → confirme un effet très local

## 12. Résidus (1 min)
- Moran I = 0,070 : faible mais significatif
- Corrélation spatiale des erreurs ≠ biais : erreurs-types fausses, corrigées par Conley ; biais seulement si une variable omise spatiale est liée à la distance
- Gros résidus : petits groupes de 2 à 8 restaurants en périphérie (Le Pellerin, Vertou, Couëron, Carquefou, Saint-Aignan près de l'aéroport)
  - centres-bourgs et zones commerciales non mesurés par la place du Commerce → principale variable omise visible
- Alignements le long des grands axes (sud de Rezé, Vertou) : restaurants de bord de route
- 528 résidus > 2 contre 12 < −2 : le modèle rate surtout des restaurants inattendus

## 13. Limites (1 min)
- Associations, pas effets causaux : pas d'instrument ; panel (ouvertures × fréquentation) seulement en piste
- Site le plus proche seulement, pas le nombre de sites autour
- Voisins endogènes et en partie médiateurs
- Distance ≠ fréquentation (petit monument ≠ grande attraction) ; fréquentation partielle et n.s.
- Résultats tirés par l'hypercentre
- Choix de données : seuil de 5 adresses (arbitraire mais net : points à 47, 23, 13, 11), population Filosofi en partie imputée

## 14. Conclusion (45 s)
- Réponse : les deux
- Sites : lien robuste et très local, −20 à −25 % quand la distance double
- Tient aux contrôles, EF commune, source, seuil de Conley, 500 m, monuments anciens
- Restaurants : concentration très forte, mais pas causale et tirée par l'hypercentre
- Fréquentation : n'ajoute rien à la proximité, mais mesure partielle
- Merci, questions

## Questions probables
- Pourquoi pas de VI ? → instrument Mérimée < 1800 abandonné après retour ; on l'utilise en robustesse (même effet)
- Pourquoi PPML plutôt que NB ? → convergent si la moyenne est bien spécifiée ; NB prédit mal (corr² 0,02)
- Pourquoi retirer les mémoriaux ? → plaques et stèles, pas des attractions ; avec eux −0,47, même conclusion
- Adresses empilées ? → domiciliations, 186 restaurants ; avec elles distance −0,35, conclusions identiques
- Fréquentation n.s. ? → mesure partielle (15 lieux payants), corrélée aux voisins
- Effet plus faible à 500 m ? → effet très local dilué par les grands carreaux
- Avertissement « VCOV not positive definite » (col. 5) → fréquent avec Conley, corrigé par fixest, erreurs-types du même ordre
