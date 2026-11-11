#!/usr/bin/env python3
import os
import django
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fopcam.settings')
django.setup()

from PIL import Image, ImageDraw
from core.models import Product

# Créer le répertoire media/products s'il n'existe pas
media_dir = BASE_DIR / 'media' / 'products'
os.makedirs(media_dir, exist_ok=True)

# Produits et leurs couleurs
products_info = [
    (1, "Poulets Bio", "#FF6B4A"),
    (2, "Fermiers", "#FF8C42"),
    (3, "Œufs Bio", "#FFB84D"),
    (4, "Œufs Cailles", "#FFC857"),
    (5, "Dinde", "#FFB84D"),
    (6, "Canards Gras", "#FF6B4A"),
    (7, "Pintades", "#FF8C42"),
    (8, "Aliment Bio", "#FFC857"),
    (9, "Minéral", "#FFB84D"),
    (10, "Pondeuses", "#FF6B4A"),
    (11, "Abri Premium", "#FF8C42"),
    (12, "Saucisses", "#FFB84D"),
    (13, "Pâté", "#FFC857"),
    (14, "Poussins", "#FF6B4A"),
    (15, "Dindonneaux", "#FF8C42"),
    (16, "Vaccination", "#FFB84D"),
    (17, "Conseil Bio", "#FFC857"),
    (18, "Oies Toulouse", "#FF6B4A"),
    (19, "Cailles", "#FF8C42"),
    (20, "Protéine Poisson", "#FFB84D"),
]

# Générer des images pour chaque produit
for product_id, name, color in products_info:
    try:
        # Créer une image simple
        img = Image.new('RGB', (300, 300), color=color)
        draw = ImageDraw.Draw(img)
        
        # Ajouter du texte
        text = name[:20]
        draw.text((30, 140), text, fill='white')
        
        # Sauvegarder l'image
        filename = f'product_{product_id}.png'
        filepath = os.path.join(media_dir, filename)
        img.save(filepath)
        print(f"✓ Image créée: {filename}")
        
        # Mettre à jour le produit dans la base de données
        product = Product.objects.filter(id=product_id).first()
        if product:
            product.image = f'products/{filename}'
            product.save()
            print(f"  → Produit {product_id} mis à jour")
        else:
            print(f"  → Produit {product_id} non trouvé")
    except Exception as e:
        print(f"✗ Erreur pour le produit {product_id}: {e}")

print("\n✓ Toutes les images ont été créées et assignées!")
