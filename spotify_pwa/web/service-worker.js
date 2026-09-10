const CACHE_NAME = 'spotify-pwa-flutter-v2';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/styles.css',
  '/app.js',
  '/manifest.json',
  '/offline.html',
];

// Install: cache static assets
self.addEventListener('install', (event) => {
  console.log('Service Worker: Installing');
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    }).then(() => self.skipWaiting())
  );
});

// Activate: clean up old caches
self.addEventListener('activate', (event) => {
  console.log('Service Worker: Activating');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch: network first for Spotify, cache first for app shell
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Spotify API/content: network first
  if (url.hostname.includes('spotify.com')) {
    event.respondWith(
      fetch(event.request)
        .catch(() => {
          return caches.match(event.request).then((response) => {
            return response || new Response(
              `<html><body style="background:#191414;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;padding:0">
                <div style="text-align:center">
                  <h1 style="color:#1DB954">Offline</h1>
                  <p>Spotify content unavailable without internet.</p>
                  <button onclick="location.reload()" style="background:#1DB954;border:none;color:#000;padding:12px 32px;border-radius:24px;font-weight:600;cursor:pointer">Retry</button>
                </div>
              </body></html>`,
              {
                status: 503,
                headers: { 'Content-Type': 'text/html' },
              }
            );
          });
        })
    );
  }
  // App shell: cache first
  else {
    event.respondWith(
      caches.match(event.request).then((response) => {
        return response || fetch(event.request).then((response) => {
          if (!response || response.status !== 200) {
            return response;
          }
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
          return response;
        });
      })
    );
  }
});
