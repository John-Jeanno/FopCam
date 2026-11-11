# FopCam Mobile - Jeu natif (Flame)

Ce fichier décrit comment lancer et tester le jeu natif intégré (`FopcamGame`).

Pré-requis
- Flutter installé (stable compatible avec le projet)
- Les sons du jeu sont fournis dans `mobile/assets/sounds/` : ambiance musicale
  en boucle, impact de collision, sifflet de rétrogradation et effets de jeu.

Installer les dépendances

```bash
cd mobile
flutter pub get
```

Lancer sur un appareil ou émulateur connecté

```bash
flutter run -d <device-id>
# ou
flutter run
```

Notes
- Le jeu est accessible depuis l'application mobile en cliquant sur "Jouer" dans l'écran `Jeu FopCam` ou depuis l'entête principal.
- Avant une nouvelle partie, un écran explique les commandes, les collisions, les validations de niveau et la récompense finale. Le joueur démarre avec le bouton « Jouer maintenant ».
- Le bouton de pause permet de reprendre immédiatement ou de sauvegarder puis quitter. La reprise restaure le score et le niveau en cours sur cet appareil; une nouvelle partie remplace cette sauvegarde.
- Chaque niveau normal dispose de son propre compte à rebours : 45 s au niveau 1, puis +15 s par niveau jusqu’au niveau 8, et +20 s par niveau du niveau 9 au 12 (60, 75, 90, 105, 120, 135, 150, 170, 190, 210 et 230 s). Atteindre le score requis ne fait pas passer immédiatement au niveau suivant : il faut attendre la fin complète du compte à rebours, puis valider le niveau. Si le temps expire sans le score requis, le joueur perd 3 points et redescend d’un niveau (sauf au niveau 1), puis peut réessayer. Le temps restant est sauvegardé avec la partie. Les manches de défi restent limitées à 60 s.
- Les objectifs de score par niveau ont été raccourcis pour accélérer les manches. Les séries d'esquives et l'indicateur de progression rendent l'objectif visible pendant la partie.
- La difficulté monte progressivement : les obstacles accélèrent de façon régulière, avec une hausse légèrement plus importante à chaque niveau, tandis que leur fréquence et la probabilité des bonus diminuent par petits paliers.
- Une musique d'ambiance originale accompagne la partie et se met en pause avec le jeu. Chaque collision produit un impact; un sifflet signale une rétrogradation.
- Chaque niveau a son propre paysage illustré (verger, récoltes, terres rouges, savane, hautes plaines, marché et terres d'or, entre autres).
- Si vous n'avez pas encore ajouté les fichiers audio, le jeu fonctionnera sans son (mais les particules visuelles seront actives).
- La progression comporte 12 niveaux séquentiels (objectifs : 0, 6, 13, 22, 32, 44, 58, 74, 91, 110, 131 et 154 points; le niveau 12 requiert 177 points). Chaque niveau doit atteindre son objectif puis être validé explicitement avant de débloquer le suivant. Chaque collision fait perdre 1 point; deux collisions provoquent une rétrogradation d'un niveau (au minimum le niveau 1). La série de collisions est réinitialisée après validation d'un niveau. Ramasser le paquet cadeau ajoute 3 points au score et active un bouclier temporaire; le bonus jaune x2 double les points gagnés par esquive pendant 8 secondes.
- Après une rétrogradation, le niveau perdu peut être récupéré en dépensant le score courant : 50 points pour retrouver les niveaux 2 à 5, 100 points pour le niveau 6 et les suivants. Le coût est retiré du score avant de reprendre. Les points gagnés grâce aux bonus de jeu font partie de ce score dépensable.
- Le niveau 12 doit lui aussi être réussi et validé avant que l'application envoie le score à `POST /api/game/rewards/level-12/`.
- Les joueurs récompensés au niveau 12 apparaissent dans le classement `Légendes FopCam`, avec leur nom public, leur avatar et leur meilleur score.
- Une légende peut envoyer un défi à une autre. Après acceptation, chacun joue une manche de 60 secondes; le serveur compare les scores, détermine le vainqueur et conserve le résultat.
- Cette route exige une connexion. L'API enregistre le trophée personnalisé et les 500 points sur le compte, une seule fois; une erreur réseau peut être réessayée depuis l'application.
- Pour un nouvel environnement backend, appliquez les migrations Django avec `python manage.py migrate`.
- Pour intégrer des assets additionnels (images, sons), ajoutez-les dans `pubspec.yaml` sous la section `assets:` puis exécutez `flutter pub get`.

Raccourcis utiles
- Récupérer packages: `flutter pub get`
- Nettoyer le build: `flutter clean`
- Recompiler: `flutter run`
