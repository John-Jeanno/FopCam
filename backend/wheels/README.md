Instructions pour installer des wheels locaux

Si votre machine n'a pas d'accès sécurisé à PyPI, téléchargez les fichiers `.whl`
sur une machine avec Internet (même architecture et version Python), copiez-les
dans `backend/wheels/` puis installez-les localement.

1) Sur une machine avec Internet (exemple):

```bash
python3 -m pip download --only-binary=:all: --dest /tmp/wheels cryptography Pillow cffi
```

Vérifiez que les fichiers `.whl` correspondent à macOS (x86_64 ou arm64)
et à Python 3.14.

2) Transférez les fichiers dans le dépôt sur la machine hors-ligne:

Copiez les `.whl` dans `backend/wheels/` (ex: via `scp`, USB, SMB, etc.).

3) Sur la machine de développement, depuis la racine du projet:

```bash
source .venv/bin/activate
python -m pip install --no-index --find-links=backend/wheels cryptography Pillow cffi
```

4) Démarrer le serveur Django:

```bash
/Users/mac/FopCam/.venv/bin/python backend/manage.py runserver 127.0.0.1:8000
```

Remarques:
- Si un wheel binaire pour Python 3.14 n'existe pas pour un paquet, utilisez
  une version Python prise en charge (ex: 3.11/3.12) pour créer/obtenir les wheels.
- Installer les wheels manuellement évite les problèmes SSL et la compilation locale.
