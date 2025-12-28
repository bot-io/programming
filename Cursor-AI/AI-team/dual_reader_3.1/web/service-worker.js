// Service Worker for Dual Reader 3.1
// 
// IMPORTANT: Flutter automatically generates and registers its own service worker
// (flutter_service_worker.js) during the build process. This file is NOT automatically
// registered and is provided as a reference implementation.
//
// Flutter's service worker handles:
// - Automatic caching of Flutter assets
// - Offline support for the Flutter web app
// - Service worker updates and versioning
//
// If you need custom caching strategies beyond what Flutter provides, you can:
// 1. Register this service worker manually in index.html (not recommended)
// 2. Use Flutter's service worker API to extend functionality
// 3. Implement custom caching in your Dart code
//
// For production, Flutter's built-in service worker is recommended as it's
// optimized for Flutter web apps and handles asset versioning automatically.

const CACHE_VERSION = 'dual-reader-v3.1.0';
const CACHE_NAME = `${CACHE_VERSION}-cache`;
const RUNTIME_CACHE = `${CACHE_VERSION}-runtime`;
const OFFLINE_CACHE = `${CACHE_VERSION}-offline`;

// Core app files that should be cached immediately
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter.js',
  '/flutter_service_worker.js',
  '/favicon.png',
];

// Flutter assets that should be cached
const FLUTTER_ASSETS = [
  '/main.dart.js',
  '/assets/',
  '/canvaskit/',
];

// Cache strategies
const CACHE_STRATEGIES = {
  // Cache first, then network for app shell
  CACHE_FIRST: 'cache-first',
  // Network first, then cache for dynamic content
  NETWORK_FIRST: 'network-first',
  // Stale while revalidate for assets
  STALE_WHILE_REVALIDATE: 'stale-while-revalidate',
};

// Install event - cache essential files
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...', CACHE_VERSION);
  
  event.waitUntil(
    Promise.all([
      caches.open(CACHE_NAME).then((cache) => {
        console.log('[Service Worker] Precaching app shell');
        return cache.addAll(
          PRECACHE_URLS.map(url => {
            try {
              return new Request(url, { cache: 'reload' });
            } catch (e) {
              return url;
            }
          })
        ).catch((error) => {
          console.warn('[Service Worker] Some precache URLs failed:', error);
          // Continue even if some URLs fail
          return Promise.resolve();
        });
      }),
      // Create offline fallback page
      caches.open(OFFLINE_CACHE).then((cache) => {
        const offlinePage = new Response(
          `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Offline - Dual Reader</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      background-color: #121212;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    .offline-container {
      text-align: center;
      padding: 2rem;
    }
    h1 { margin-bottom: 1rem; }
    p { color: #aaa; }
  </style>
</head>
<body>
  <div class="offline-container">
    <h1>You're Offline</h1>
    <p>Dual Reader needs an internet connection to load. Please check your connection and try again.</p>
  </div>
</body>
</html>`,
          { headers: { 'Content-Type': 'text/html' } }
        );
        return cache.put('/offline.html', offlinePage);
      })
    ])
    .then(() => {
      // Force the waiting service worker to become the active service worker
      return self.skipWaiting();
    })
    .catch((error) => {
      console.error('[Service Worker] Install failed:', error);
    })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            // Delete old caches that don't match current version
            if (cacheName !== CACHE_NAME && 
                cacheName !== RUNTIME_CACHE && 
                cacheName !== OFFLINE_CACHE &&
                cacheName.startsWith('dual-reader-')) {
              console.log('[Service Worker] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        // Take control of all pages immediately
        return self.clients.claim();
      })
      .catch((error) => {
        console.error('[Service Worker] Activation failed:', error);
      })
  );
});

// Fetch event - implement caching strategies
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip cross-origin requests and non-GET requests
  if (url.origin !== location.origin || request.method !== 'GET') {
    return;
  }

  // Skip service worker requests (let Flutter's service worker handle them)
  // But allow manifest.json to be cached for offline access
  if (url.pathname.includes('service-worker.js') || 
      url.pathname.includes('flutter_service_worker.js')) {
    // Let Flutter's service worker handle these
    return;
  }
  
  // Allow manifest.json to be cached but handle it specially
  if (url.pathname.includes('manifest.json')) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // Determine caching strategy based on request type
  if (isAppShell(request)) {
    event.respondWith(cacheFirst(request));
  } else if (isFlutterAsset(request)) {
    event.respondWith(cacheFirst(request));
  } else if (isAsset(request)) {
    event.respondWith(staleWhileRevalidate(request));
  } else {
    event.respondWith(networkFirst(request));
  }
});

// Check if request is part of app shell
function isAppShell(request) {
  const url = new URL(request.url);
  return PRECACHE_URLS.some(precacheUrl => url.pathname === precacheUrl || url.pathname === precacheUrl + '/');
}

// Check if request is a Flutter asset
function isFlutterAsset(request) {
  const url = new URL(request.url);
  return FLUTTER_ASSETS.some(asset => url.pathname.startsWith(asset));
}

// Check if request is a static asset
function isAsset(request) {
  const url = new URL(request.url);
  return url.pathname.match(/\.(js|css|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot|ico|webp)$/);
}

// Cache first strategy - good for app shell
async function cacheFirst(request) {
  try {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.error('[Service Worker] Cache first failed:', error);
    // Return offline fallback page for navigation requests
    if (request.mode === 'navigate') {
      const offlineCache = await caches.open(OFFLINE_CACHE);
      const offlinePage = await offlineCache.match('/offline.html');
      if (offlinePage) {
        return offlinePage;
      }
    }
    return new Response('Offline', { 
      status: 503, 
      statusText: 'Service Unavailable',
      headers: { 'Content-Type': 'text/plain' }
    });
  }
}

// Network first strategy - good for dynamic content
async function networkFirst(request) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(RUNTIME_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.log('[Service Worker] Network failed, trying cache:', request.url);
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    // For navigation requests, return offline page
    if (request.mode === 'navigate') {
      const offlineCache = await caches.open(OFFLINE_CACHE);
      const offlinePage = await offlineCache.match('/offline.html');
      if (offlinePage) {
        return offlinePage;
      }
    }
    return new Response('Offline', { 
      status: 503, 
      statusText: 'Service Unavailable',
      headers: { 'Content-Type': 'text/plain' }
    });
  }
}

// Stale while revalidate - good for assets
async function staleWhileRevalidate(request) {
  const cache = await caches.open(RUNTIME_CACHE);
  const cachedResponse = await cache.match(request);
  
  const fetchPromise = fetch(request).then((networkResponse) => {
        if (networkResponse.ok) {
          cache.put(request, networkResponse.clone());
        }
        return networkResponse;
      })
      .catch(() => {
        // Network failed, return cached if available
        return cachedResponse || new Response('Offline', { status: 503 });
      });

  // Return cached version immediately, update in background
  return cachedResponse || fetchPromise;
}

// Handle messages from the app
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data && event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(RUNTIME_CACHE).then((cache) => {
        return cache.addAll(event.data.urls);
      })
    );
  }
});
