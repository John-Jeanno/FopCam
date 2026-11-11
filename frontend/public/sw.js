const CACHE_NAME = 'fopcam-static-v1'
const APP_SCOPE = '/fopcam/'
const STATIC_PATH = '/fopcam/_next/static/'
const OFFLINE_PAGE = '/fopcam/offline.html'

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.add(OFFLINE_PAGE))
  )
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith('fopcam-static-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  )
  self.clients.claim()
})

self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = new URL(request.url)

  if (request.method !== 'GET' || url.origin !== self.location.origin) return

  if (url.pathname.startsWith(STATIC_PATH)) {
    event.respondWith(
      caches.open(CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(request)
        if (cached) return cached

        const response = await fetch(request)
        if (response.ok && response.type === 'basic') {
          await cache.put(request, response.clone())
        }
        return response
      })
    )
    return
  }

  if (request.mode === 'navigate' && url.pathname.startsWith(APP_SCOPE)) {
    event.respondWith(
      fetch(request).catch(async () => {
        const offlinePage = await caches.match(OFFLINE_PAGE)
        return offlinePage || Response.error()
      })
    )
  }
})
