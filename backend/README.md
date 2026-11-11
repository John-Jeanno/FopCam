# Backend FopCam (Django)

Instructions rapides (dev local):

1. Créer un environnement virtuel:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

2. Initialiser le projet Django (déjà scaffold minimal fourni). Utiliser SQLite pour démarrer.

3. Installer Redis localement (macOS) :

```bash
brew install redis
brew services start redis
```

4. Lancer le serveur ASGI (Channels) :

```bash
python manage.py migrate
python manage.py runserver
```

Notes:

- Config actuelle : SQLite pour dev. Pour production, configurer PostgreSQL et Redis.
- Django utilise `REDIS_URL` dans `fopcam/settings.py` pour les Channels.
- Voir `fopcam/settings.py` pour variables d'environnement.
