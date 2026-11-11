# Mobile FopCam (Flutter)

Instructions rapides:

1. Initialiser le projet Flutter:

```bash
flutter create mobile
cd mobile
```

2. Ajouter packages: `http`, `provider`, `flutter_local_notifications`, `geolocator`, etc.

3. Utiliser REST API du backend et WebSocket (socket_io_client ou web_socket_channel) pour temps réel.

## Utilisation hors ligne

Les réponses API consultables sont conservées dans Hive (IndexedDB sur le Web)
et réutilisées si le réseau échoue. Les données privées sont isolées par compte,
et les réponses les plus anciennes sont supprimées au-delà de 400 entrées.
Les modifications de profil, publications, commentaires, produits et boutiques
sans média peuvent être mises en file puis synchronisées à la reconnexion.
Le bandeau de l’application indique l’état réseau et le nombre de modifications
en attente. Les paiements, commandes, suppressions, appels, directs et actions
de jeu temps réel nécessitent toujours une connexion ; les créations avec média
autres que les statuts ne sont pas mises en file hors ligne.
