#!/usr/bin/env bash
set -euo pipefail

# Script d'installation des wheels placés dans backend/wheels
# Usage: ./backend/install_wheels.sh

WHEELS_DIR="backend/wheels"
VENV_DIR=".venv"

if [ ! -d "$WHEELS_DIR" ]; then
  echo "Aucun répertoire $WHEELS_DIR trouvé. Copiez les .whl ici puis réessayez."
  exit 1
fi

if [ -f "$VENV_DIR/bin/activate" ]; then
  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"
fi

echo "Installation depuis $WHEELS_DIR..."
python -m pip install --no-index --find-links="$WHEELS_DIR" --force-reinstall cryptography Pillow cffi || \
  python -m pip install --no-index --find-links="$WHEELS_DIR" cryptography Pillow cffi

echo "Installation terminée. Pour démarrer le serveur Django :"
echo "  /Users/mac/FopCam/.venv/bin/python backend/manage.py runserver 127.0.0.1:8000"
