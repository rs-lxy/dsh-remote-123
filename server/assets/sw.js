// dsh-remote 极简 Service Worker：
// - 只预缓存离线页；
// - 导航请求网络优先，断网时退回离线页；
// - 其余请求原样透传（不缓存 dsh 的 API/流式响应，避免破坏实时性与登录状态）。
const CACHE = 'dsh-remote-shell-v1'
const OFFLINE = '/__pwa/offline.html'

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE).then(cache => cache.add(OFFLINE)).then(() => self.skipWaiting())
  )
})

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener('fetch', event => {
  const req = event.request
  if (req.method !== 'GET') return
  const url = new URL(req.url)
  if (url.origin !== self.location.origin) return
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).catch(() => caches.match(OFFLINE))
    )
    return
  }
  if (url.pathname.startsWith('/__pwa/')) {
    event.respondWith(
      caches.match(req).then(hit => hit || fetch(req).then(res => {
        const copy = res.clone()
        caches.open(CACHE).then(cache => cache.put(req, copy)).catch(() => {})
        return res
      }))
    )
  }
  // dsh 页面与 API：全透传，交给浏览器 HTTP 缓存（网关已对 ?rev= 资源加 immutable）
})
