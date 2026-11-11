#!/bin/bash

# Script de lancement rapide FopCam
echo "🚀 Démarrage de FopCam - Marketplace Agricole Futuriste"
echo "======================================================"

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Vérification des prérequis
echo "📋 Vérification des prérequis..."

if ! command_exists python3; then
    echo "❌ Python 3 n'est pas installé. Veuillez l'installer."
    exit 1
fi

if ! command_exists node; then
    echo "❌ Node.js n'est pas installé. Veuillez l'installer."
    exit 1
fi

echo "✅ Prérequis vérifiés"

# Configuration du backend
echo ""
echo "🔧 Configuration du backend Django..."
cd backend

# Création de l'environnement virtuel si inexistant
if [ ! -d "venv" ]; then
    echo "📦 Création de l'environnement virtuel..."
    python3 -m venv venv
fi

# Activation de l'environnement virtuel
echo "🔄 Activation de l'environnement virtuel..."
source venv/bin/activate
BACKEND_DIR=$(pwd)
PYTHON_EXECUTABLE="$BACKEND_DIR/venv/bin/python"

# Installation des dépendances
echo "📥 Installation des dépendances Python..."
$PYTHON_EXECUTABLE -m pip install -r requirements.txt

# Migrations de la base de données
echo "🗄️ Application des migrations..."
$PYTHON_EXECUTABLE manage.py migrate

# Chargement des données de démonstration
echo "📊 Chargement des données de démonstration..."
$PYTHON_EXECUTABLE manage.py loaddata core/fixtures/*.json

echo "✅ Backend configuré"

# Lancement du backend en arrière-plan
echo "🚀 Lancement du serveur backend ASGI (avec WebSockets)..."

# Déterminer le port backend disponible (8000 par défaut, sinon 8002)
BACKEND_PORT=8000
if $PYTHON_EXECUTABLE -c "import socket,sys; s=socket.socket(); s.settimeout(0.5); \
try: s.connect(('127.0.0.1', int('${BACKEND_PORT}'))); sys.exit(0)
except: sys.exit(1)
finally: s.close()" >/dev/null 2>&1
then
  echo "⚠️  Port ${BACKEND_PORT} occupé, utilisation du port 8002 à la place."
  BACKEND_PORT=8002
fi

export BASE_URL="http://localhost:${BACKEND_PORT}"
export NEXT_PUBLIC_API_URL="http://localhost:${BACKEND_PORT}"
export PYTHONPATH="$BACKEND_DIR"

$PYTHON_EXECUTABLE -m uvicorn fopcam.asgi:application --host 0.0.0.0 --port ${BACKEND_PORT} &
BACKEND_PID=$!
cd ..

# Configuration du frontend
echo ""
echo "🎨 Configuration du frontend Next.js..."
cd frontend

# Installation des dépendances npm
echo "📥 Installation des dépendances Node.js..."
npm install

echo "✅ Frontend configuré"

# Lancement du frontend en arrière-plan
echo "🚀 Lancement du serveur frontend..."
npm run dev &
FRONTEND_PID=$!

# Retour au répertoire racine
cd ..

echo ""
echo "🎉 FopCam est maintenant opérationnel !"
echo "========================================"
echo ""
echo "🌐 Interfaces disponibles :"
echo "   • Frontend : http://localhost:3000"
echo "   • API Backend : http://localhost:8000/api/"
echo "   • Admin Django : http://localhost:8000/admin/"
echo ""
echo "👤 Comptes de test :"
echo "   • Admin : admin / Test-1234"
echo "   • Producteur : producer1 / password123"
echo "   • Acheteur : buyer1 / password123"
echo ""
echo "🛑 Pour arrêter les serveurs : Ctrl+C"
echo ""

# Fonction de nettoyage
cleanup() {
    echo ""
    echo "🧹 Arrêt des serveurs..."
    kill $BACKEND_PID 2>/dev/null
    kill $FRONTEND_PID 2>/dev/null
    echo "✅ Serveurs arrêtés. Au revoir !"
    exit 0
}

# Gestion du signal d'arrêt
trap cleanup SIGINT SIGTERM

# Attente
wait