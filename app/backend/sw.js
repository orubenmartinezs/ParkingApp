// Service Worker Placeholder
// This file exists to prevent 404 errors in browser logs when accessing the admin panel.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => self.clients.claim());
