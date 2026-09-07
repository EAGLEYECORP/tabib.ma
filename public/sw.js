const CACHE = 'tabib-v12-shell';
const SHELL = ['/', '/offline', '/doctors', '/login', '/register', '/manifest.webmanifest'];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET' || !req.url.startsWith(self.location.origin)) return;
  // Never cache API/auth responses: health and private data must remain network-only.
  if (new URL(req.url).pathname.startsWith('/api/')) return;
  event.respondWith(fetch(req).then(res => {
    if (res.ok && req.destination !== 'document') {
      const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy));
    }
    return res;
  }).catch(() => caches.match(req).then(cached => cached || caches.match('/offline'))));
});
