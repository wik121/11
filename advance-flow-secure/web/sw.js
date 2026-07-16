/* Advance Flow Secure service worker — makes the app fully offline once visited.
   Caches the page and the AI library files (cdn.jsdelivr.net) on first use.
   Whisper model files are cached separately by transformers.js itself.
   This file must sit next to advance-flow-secure.html and be served over HTTPS
   (e.g. GitHub Pages); when the page is opened as a plain local file the
   app simply runs without it. */
const CACHE = "advance-flow-secure-v1";

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);
  const cacheable = url.origin === self.location.origin || url.hostname === "cdn.jsdelivr.net";
  if (!cacheable) return;

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const hit = await cache.match(event.request);
      if (hit) return hit;
      const response = await fetch(event.request);
      if (response.ok || response.type === "opaque") {
        cache.put(event.request, response.clone());
      }
      return response;
    })
  );
});
