# Gold Gambit

Addon hôte pour organiser des parties de gambling dans un groupe ou un raid WoW. 
Seul l'hôte a besoin de l'addon : les autres joueurs rejoignent avec `1` dans le chat et jouent avec `/rand X`.

## Installation

1. Copiez le dossier `GoldGambit` dans `World of Warcraft/_retail_/Interface/AddOns/`.
2. Relancez WoW ou exécutez `/reload`.
3. Activez l'addon dans la liste des addons du personnage.
4. Tapez `/gg` ou `/goldgambit` pour ouvrir la fenêtre.

Où installer avec Curse Forge.

La commande `/gg reset` efface uniquement l'historique et les statistiques, sans modifier les paramètres de l'addon.

Le fichier `GoldGambit.toc` affiche **Gold Gambit**. Pour utiliser la variante de développement, nommez le dossier `GoldGambitDev` : WoW chargera `GoldGambitDev.toc`, dont le titre est **Gold Gambit Dev**. N'activez qu'une seule des deux variantes à la fois.

## Déroulement d'une partie

1. L'hôte choisit le jet maximal, active ou non sa participation automatique, puis clique sur **Lancer**.
2. Les joueurs tapent `1` dans le canal annoncé. **Rappel** republie l'invitation.
3. **Clôturer** ferme les inscriptions à partir de deux joueurs et demande `/rand X`.
4. Seuls les jets `1-X` des participants sont acceptés, une fois par joueur et par manche.
5. Dès que tous les joueurs ont lancé, le plus haut jet gagne. Le plus bas lui doit la différence entre les deux jets.
6. En cas d'égalité sur le plus haut ou le plus bas jet, la manche entière est automatiquement relancée.

Le bouton **/rand** permet à l'hôte inscrit de lancer directement son jet. **Annuler** met fin à la partie sans écrire de statistiques.

## Statistiques

L'historique est stocké dans la variable de compte `GoldGambitDB`. Les filtres disponibles sont :

- Depuis le début
- Ce patch (déduit de la version courante de WoW, par exemple 12.1)
- Aujourd'hui

Pour chaque participant, l'addon calcule les golds gagnés et perdus, le total net, le winrate, le loserate, le némésis (destinataire principal de ses pertes) et le mécène (source principale de ses gains). Le classement peut être publié dans un canal choisi ; **Automatique** utilise Instance, Raid ou Groupe selon la formation actuelle.

## Remarques

- L'addon annonce la dette mais ne peut pas transférer automatiquement les golds.
- Une partie active n'est pas restaurée après `/reload`; seules les parties terminées sont persistantes.
- **Tout réinitialiser** supprime définitivement les paramètres et l'historique après confirmation.
- Compatibilité cible : WoW Retail 12.1 (`Interface: 120100`).

## Vérification rapide en jeu

1. Former un groupe de deux joueurs et ouvrir `/gg`.
2. Lancer une partie à 10K avec l'hôte inscrit automatiquement.
3. Faire taper `1` au second joueur, envoyer un rappel, puis clôturer.
4. Utiliser le bouton `/rand` côté hôte et `/rand 10000` côté second joueur.
5. Vérifier le message de résolution et la nouvelle ligne dans **Statistiques**.
6. Publier le classement avec chacun des trois filtres.
