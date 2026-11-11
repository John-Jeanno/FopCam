# Template Admin Personnalisé FopCam

## Vue d'ensemble

L'interface admin de FopCam a été remplacée par un template totalement personnalisé et moderne, abandonnant Jazzmin pour plus de contrôle et de flexibilité.

## Caractéristiques

✨ **Design moderne et futuriste**

- Gradient sombre avec accents verts (couleur FopCam)
- Glassmorphism avec backdrop blur
- Responsive et accessible
- Dark mode par défaut

🎨 **Interface personnalisée**

- Sidebar avec navigation
- Topbar avec informations utilisateur
- Dashboard avec métriques clés
- Formulaires stylisés
- Tables élégantes

🔧 **Facile à maintenir et étendre**

- Code HTML/CSS simple et lisible
- Pas de dépendances externes complexes
- Structure modulaire
- Facilement customisable

## Fichiers de templates

```
core/templates/admin/
├── base.html          # Template de base
├── index.html         # Dashboard/accueil admin
└── login.html         # Page de connexion
```

## Personnalisation

### Modification des couleurs

Éditez les variables CSS dans `base.html` :

```css
:root {
  --color-fopcam: #22c55e; /* Couleur primaire */
  --color-fopcam-dark: #16a34a; /* Couleur secondaire */
  --color-future-900: #0f172a; /* Fond très sombre */
  --color-future-800: #1e293b; /* Fond sombre */
  /* ... */
}
```

### Ajout de nouvelles pages

1. Créez un nouveau fichier `template.html` dans `core/templates/admin/`
2. Hérité de `base.html` avec `{% extends "admin/base.html" %}`
3. Utilisez les blocs `{% block content %}` pour votre contenu

Exemple :

```html
{% extends "admin/base.html" %} {% block title %}Ma Page - FopCam Admin{% endblock %} {% block
title_display %}Ma Page{% endblock %} {% block content %}
<div class="card">
  <!-- Votre contenu ici -->
</div>
{% endblock %}
```

### Ajout de CSS personnalisé

Utilisez le bloc `{% block extra_css %}` dans vos templates :

```html
{% block extra_css %}
<style>
  .custom-class {
    color: var(--color-fopcam);
  }
</style>
{% endblock %}
```

## Composants réutilisables

### Cards

```html
<div class="card">
  <!-- Contenu -->
</div>
```

### Boutons

```html
<button class="btn btn-primary">Primaire</button>
<button class="btn btn-secondary">Secondaire</button>
<button class="btn btn-danger">Danger</button>
```

### Messages

```html
<div class="message success">Message de succès</div>
<div class="message error">Message d'erreur</div>
<div class="message warning">Message d'avertissement</div>
<div class="message info">Message d'information</div>
```

## Configuration Django

Dans `settings.py`, le dossier des templates est configuré :

```python
TEMPLATES = [
    {
        'DIRS': [BASE_DIR / 'core' / 'templates'],
        # ...
    }
]
```

## Performance

L'interface admin personnalisée est très légère :

- Pas de JavaScript lourd
- CSS minimaliste inline
- Pas de build tool nécessaire
- Charge instantanément

## Support

Pour modifier l'admin :

1. Éditez les templates dans `core/templates/admin/`
2. Modifiez `admin.py` pour les configurations ModelAdmin
3. Relancez le serveur Django

Les changements prennent effet immédiatement sans compilation.

## Migration depuis Jazzmin

Si vous veniez de Jazzmin, notez que :

- Les icônes Font Awesome ne sont pas disponibles (à ajouter si nécessaire)
- Les graphiques personnalisés ne sont pas inclus
- Vous pouvez les ajouter en éditant les templates
- La configuration se fait directement dans Django `admin.py`

---

**FopCam Admin** - Interface d'administration moderne et performante 🚀
