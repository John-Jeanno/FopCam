# FopCam Frontend

Démarrage rapide (local dev):

```bash
cd frontend
npm install
NEXT_PUBLIC_API_URL=http://127.0.0.1:8000 npm run dev
```

Il y a des pages minimalistes : `/` catalogue, `/register`, `/login`.

## Application installable (PWA)

En production, la configuration Docker sert l'application sous `/fopcam` avec
`NEXT_BASE_PATH=/fopcam`. Le manifeste, les icônes et le service worker suivent
ce préfixe ; seules les ressources statiques Next.js sont mises en cache. Les
pages et les réponses API privées ne sont pas stockées hors ligne.

L'installation est proposée par les navigateurs compatibles après ouverture de
FopCam en HTTPS. Hors connexion, une page explicative s'affiche ; les contenus
du compte ne sont pas disponibles hors ligne.
