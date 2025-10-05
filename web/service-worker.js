// Custom Service Worker for Attendo - Force Latest Version
const CACHE_VERSION = 'v1.0.0';
const CACHE_NAME = `attendo-cache-${CACHE_VERSION}`;

// Install event - clean old caches
self.addEventListener('install', (event) => {
  console.log('Service Worker: Installing new version...');
  self.skipWaiting(); // Force activation of new service worker
  
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Service Worker: Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

// Activate event - take control immediately
self.addEventListener('activate', (event) => {
  console.log('Service Worker: Activating new version...');
  event.waitUntil(
    clients.claim() // Take control of all clients immediately
  );
});

// Fetch event - network first, then cache
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Clone the response
        const responseToCache = response.clone();
        
        // Cache the fetched response
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseToCache);
        });
        
        return response;
      })
      .catch(() => {
        // If network fails, try cache
        return caches.match(event.request).then((response) => {
          return response || new Response('Offline - Please check your connection');
        });
      })
  );
});

// Message event - handle version check requests
self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
  }
  
  if (event.data === 'checkVersion') {
    event.ports[0].postMessage({
      version: CACHE_VERSION,
      updated: new Date().toISOString()
    });
  }
});
