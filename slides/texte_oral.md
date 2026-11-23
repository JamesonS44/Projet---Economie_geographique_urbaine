# Texte de l'oral (26/11, 15 min + 5 min de questions)

Environ 1 minute par slide, 130 mots par minute en parlant calmement. Le texte est à dire avec ses mots, pas à lire. Répartition de la parole à faire.

## Slide 1. Titre (20 s)

Bonjour. Nous allons vous présenter notre projet sur la localisation des restaurants dans Nantes Métropole. La question est simple : quand un restaurant choisit où s'installer, est-ce qu'il suit les touristes, ou est-ce qu'il suit les autres restaurants ? Pour y répondre, on a découpé la métropole en carreaux de 200 mètres de côté, et on compte les restaurants dans chaque carreau.

## Slide 2. Question et hypothèses (1 min 15)

Il y a deux raisons possibles de s'installer à un endroit.
La première, ce sont les sites touristiques. Les visiteurs d'un musée ou d'un château mangent à proximité, et un site amène des piétons dans les rues autour.
La seconde, ce sont les autres restaurants. Une rue connue pour ses restaurants attire des clients qui viennent manger sans avoir choisi d'adresse, et qui comparent les cartes et les prix sur place. C'est l'agglomération : les restaurants gagnent à être ensemble, même s'ils sont concurrents.
On en tire trois hypothèses. H1 : il y a moins de restaurants quand on s'éloigne du site touristique le plus proche. H2 : il y a plus de restaurants quand les huit carreaux voisins en comptent beaucoup. H3 : les sites sont souvent au centre, là où il y a déjà beaucoup de restaurants. Donc si on contrôle les voisins, l'effet des sites devrait baisser. C'est ce qui nous permet de distinguer les deux logiques.

## Slide 3. Données (1 min 15)

On a croisé plusieurs sources géolocalisées, toutes ramenées aux 13 384 carreaux de la métropole.
Les restaurants viennent de SIRENE, l'annuaire des entreprises de l'INSEE : restauration traditionnelle et rapide, établissements actifs au 30 septembre 2026. OpenStreetMap sert seulement à vérifier le résultat.
Les sites touristiques viennent de quatre sources : OpenStreetMap, la base Mérimée des monuments historiques, Muséofile pour les musées, et les données du Département.
La population vient des carreaux Filosofi de l'INSEE, et la fréquentation des grands lieux vient de Nantes Métropole.
Trois choix de nettoyage. On a retiré 186 restaurants, soit 8 %, regroupés à plus de cinq sur le même point GPS : ce sont des domiciliations, pas de vrais restaurants. On a exclu 396 mémoriaux, des plaques et des stèles qui n'attirent personne. Et on a gardé les carreaux sans habitants, parce que les zones commerciales en font partie.

## Slide 4. Carte des restaurants (1 min)

Cette carte montre le nombre de restaurants par carreau.
Premier constat : 93 % des carreaux n'ont aucun restaurant. Ça aura une conséquence sur le choix du modèle.
Deuxième constat : la concentration est très forte. 1 % des carreaux regroupe la moitié des restaurants, surtout dans l'hypercentre et le Bouffay. On voit aussi un pôle secondaire vers Saint-Herblain et les zones commerciales.
On a comparé avec OpenStreetMap : OSM couvre bien le centre mais mal la périphérie, c'est pourquoi on garde SIRENE comme source principale.

## Slide 5. Distance au site (1 min)

Voici notre variable spatiale principale : la distance à vol d'oiseau entre le centre de chaque carreau et le site touristique le plus proche.
On avait 736 sites au départ ; sans les mémoriaux, il en reste 340.
La distance médiane est de 1,3 km. Elle est inférieure à 1 km dans le centre de Nantes et près des bourgs anciens, et dépasse 3 à 5 km dans l'ouest et le sud.
Cette forte variation est utile : c'est elle qui permet d'estimer l'effet. Dans le modèle, on prend la distance en logarithme, pour lire l'effet en pourcentage.

## Slide 6. Méthode (1 min 15)

Notre variable à expliquer est un nombre de restaurants : 0, 1, 2… avec énormément de zéros. On utilise donc un modèle de Poisson, estimé par PPML. Il reste fiable avec beaucoup de zéros et des écarts très forts entre carreaux, parce qu'il demande seulement que la moyenne soit bien modélisée. On vérifie avec une binomiale négative.
Le coefficient de la distance se lit simplement : quand la distance double, le nombre de restaurants change de deux puissance bêta moins un.
On construit le modèle en cinq colonnes, en ajoutant les contrôles un par un : la population, la distance à la place du Commerce pour la centralité, les restaurants voisins, puis la fréquentation des grands lieux avec des effets fixes commune. On voit ainsi comment l'effet de la distance bouge à chaque étape.
Enfin, des carreaux proches se ressemblent, donc leurs erreurs sont liées. On utilise des erreurs-types de Conley à 1 km pour ne pas surestimer la précision.

## Slide 7. Biais de variable omise (1 min 15)

Le premier risque, c'est d'oublier une variable qui joue à la fois sur les restaurants et sur la distance. Le sens du biais se déduit de deux signes : l'effet de la variable sur les restaurants, multiplié par son lien avec la distance.
La population augmente le nombre de restaurants mais est peu liée à la distance aux sites : le coefficient bouge peu, de −1,18 à −1,08.
La centralité, c'est le gros morceau. Plus on s'éloigne de la place du Commerce, moins il y a de restaurants, et les sites sont concentrés au centre. Sans ce contrôle, la distance aux sites prend une partie de l'effet du centre-ville : le coefficient passe de −1,08 à −0,69.
Même raisonnement pour les restaurants voisins, de −0,69 à −0,41, puis pour la fréquentation et les effets fixes commune, jusqu'à −0,32.
Les quatre corrections vont dans le sens prévu. Les vraies variables de confusion sont la centralité et les restaurants autour, pas la population.

## Slide 8. Causalité inverse (1 min 15)

Le second risque, c'est la causalité inverse : est-ce que ce sont les restaurants qui attirent les sites ? Un quartier animé peut obtenir plus facilement un musée, ou voir ses lieux mieux signalés.
Notre meilleur argument, ce sont les monuments d'avant 1800. Ils existaient bien avant les restaurants actuels, qui ne peuvent donc pas les avoir causés. Or, avec seulement ces monuments, on trouve le même effet : −0,37 contre −0,41. Ça va contre la causalité inverse pour H1, sans être une preuve.
Pour les restaurants voisins, en revanche, on ne peut rien dire de causal. Chaque carreau est le voisin de ses voisins, donc le lien va forcément dans les deux sens, et un même choc, comme une rue piétonne, augmente les restaurants partout autour.
La fréquentation est aussi endogène. Sur l'île de Nantes, les Machines, la rénovation du quartier et les nouveaux restaurants sont arrivés ensemble. On prend la moyenne 2009-2019 pour limiter le problème, sans le supprimer.

## Slide 9. Résultats H1 (1 min 30)

Voici les résultats, traduits en pourcentages.
Sans contrôle, quand la distance au site double, il y a 56 % de restaurants en moins. Cet effet est surestimé, pour les raisons vues juste avant.
Avec tous les contrôles en colonne 4, l'effet est de −25 % : un carreau deux fois plus loin d'un site a un quart de restaurants en moins. Avec les effets fixes commune, en colonne 5, c'est −20 %.
Les autres variables ont le signe attendu. 100 habitants de plus, c'est environ 14 % de restaurants en plus. Un kilomètre de plus depuis la place du Commerce, c'est 22 à 29 % de moins. Chaque restaurant voisin en plus est associé à 1 % de restaurants en plus dans le carreau.
Le potentiel de fréquentation n'est pas significatif : une fois la distance et le centre pris en compte, la fréquentation des grands lieux n'ajoute rien.
Tout le reste est significatif à 0,1 %. H1 est donc validée : l'effet est divisé par plus de deux avec les contrôles, mais il reste net.

## Slide 10. Résultats H2 et H3 (1 min 15)

Pour H2, chaque restaurant voisin est associé à 1,1 % de restaurants en plus. Mais ce résultat est fragile : il n'est plus significatif en binomiale négative, et il repose surtout sur l'hypercentre. On l'interprète comme une concentration des restaurants, pas comme un effet causal de l'agglomération.
Pour H3, quand on ajoute les voisins, le coefficient de distance baisse de 40 %, de −0,69 à −0,41. Une partie de l'effet apparent des sites passait donc par les restaurants autour. C'est logique : un site attire des restaurants, qui en attirent d'autres. Les voisins sont en partie un canal de l'effet des sites.
Mais l'effet de la distance reste très significatif. H3 est donc partiellement validée : l'effet baisse, mais il ne disparaît pas. Les restaurants suivent à la fois les sites et les autres restaurants.

## Slide 11. Robustesse (1 min)

On a vérifié que le résultat ne dépend pas de nos choix.
À 200 mètres, le coefficient reste entre −0,32 et −0,47, et toujours significatif, quelle que soit la variante : binomiale négative, monuments anciens seulement, avec les mémoriaux, seulement les carreaux habités, restaurants OpenStreetMap, erreurs-types par commune ou Conley à 2 km.
Avec des carreaux de 500 mètres, l'effet est plus faible, −16 % quand la distance double, mais reste significatif.
Ça nous dit que l'effet est très local : c'est la proximité immédiate du site qui compte. Avec des carreaux plus grands, on mélange des zones proches et éloignées, et l'effet se dilue.

## Slide 12. Résidus (1 min)

Les résidus montrent ce que le modèle n'explique pas.
L'indice de Moran sur les résidus vaut 0,07 : une autocorrélation faible mais significative. Ça veut d'abord dire que les erreurs-types classiques seraient trop optimistes ; c'est ce que corrige Conley. Ça ne crée un biais que si la variable oubliée est aussi liée à la distance aux sites.
Sur la carte, les gros résidus positifs sont dans les centres-bourgs des communes de la périphérie et dans les zones commerciales. Le modèle ne connaît que le centre de Nantes, alors que chaque commune a son propre petit centre. Ces centralités locales sont une variable omise visible. Les effets fixes commune en captent une partie, et le résultat tient avec eux.

## Slide 13. Discussion et limites (1 min)

Nos résultats sont des associations robustes, pas des effets causaux.
Nous n'avons pas d'instrument : le panel par année est resté une piste.
On mesure la distance au site le plus proche, pas le nombre de sites autour.
Les restaurants voisins sont endogènes, et en partie un canal de l'effet des sites.
La fréquentation ne porte que sur 15 grands lieux, et elle n'est pas significative. Or un petit monument peut attirer beaucoup de monde : la distance n'est pas la fréquentation.
L'hypercentre pèse très lourd : 1 % des carreaux, la moitié des restaurants.
Enfin, certains choix de données comptent : le seuil de cinq adresses pour les domiciliations, et une partie de la population Filosofi qui est imputée.

## Slide 14. Conclusion (45 s)

Pour conclure : les restaurants suivent les deux, et de très près.
Quand la distance au site touristique double, il y a 20 à 25 % de restaurants en moins, après contrôle de la population, du centre-ville et des restaurants voisins. Ce lien tient dans toutes nos variantes et il est très local.
Les restaurants sont aussi très concentrés entre eux, mais on ne peut pas dire que cette concentration soit causale.
Enfin, la fréquentation des grands lieux n'ajoute rien à la simple proximité.
Merci de votre attention, nous sommes prêts pour vos questions.
