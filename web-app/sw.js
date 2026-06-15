/* よみたま Service Worker
 * ネットワーク優先（network-first）で、開くたびに最新を取得します。
 * オフライン時のみキャッシュから表示します。これにより
 * ホーム画面に追加したアプリ(PWA)でも更新が反映されます。
 */
const CACHE = 'yomitama-cache-v32';

self.addEventListener('install', () => {
  self.skipWaiting(); // 新しいSWをすぐ有効化
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // 古いキャッシュを削除
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  event.respondWith((async () => {
    try {
      // 常にサーバーへ確認しに行く（更新が必ず届くように）
      const fresh = await fetch(req, { cache: 'no-cache' });
      try {
        const cache = await caches.open(CACHE);
        cache.put(req, fresh.clone());
      } catch (_) { /* opaque等は無視 */ }
      return fresh;
    } catch (err) {
      // オフライン時はキャッシュ→無ければトップ
      const cached = await caches.match(req);
      if (cached) return cached;
      const fallback = await caches.match('./');
      if (fallback) return fallback;
      throw err;
    }
  })());
});
