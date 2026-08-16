#!/usr/bin/env node
// dsh-remote gateway — DeepSeek Harness 手机远程登录网关 + PWA 注入
//
// 链路：
//   iPhone PWA / 安卓 APK / 任意浏览器
//     → https://<公网隧道或 Tailscale 域名>/   (cloudflared / tailscale serve, HTTPS)
//     → 127.0.0.1:DSH_REMOTE_PORT              (本网关, 只绑 loopback)
//     → 127.0.0.1:3080                          (dsh web, 官方进程, 只绑 loopback)
//
// 功能：
//   1) 认证：登录页 + HttpOnly 会话 cookie；同时兼容 Basic Auth（dsh-mobile-app APK）
//      和 joyfish APK 预置的 dsh_remote_config_token cookie；
//   2) PWA：向 dsh 的 HTML 注入 manifest / apple-touch-icon / SW，iPhone Safari
//      「添加到主屏幕」后获得独立全屏 App 体验；
//   3) 移动端适配：注入 window.__DSH_PROXY__ 并按 boot manifest 重排 mobile-fit
//      插件行（该部分逻辑源自 joyfish666/deepseek-harness-remote, MIT）；
//   4) 信任围栏：把 Host/Origin 统一改写为 loopback 拼写——dsh 官方信任围栏放行，
//      且 settings/credentials 等特权平面在手机上可用（密码即边界，见 README 安全说明）；
//   5) WebSocket：透传 /api/events.mux|host，审批/实时事件可用；对浏览器 WS 不带
//      Authorization 的问题，注入脚本换取一次性 WS token。
//
// 环境变量：
//   DSH_REMOTE_PORT      监听端口，默认 8082
//   DSH_REMOTE_BIND      监听地址，默认 127.0.0.1（隧道/Serve 在本机转发即可）
//   DSH_REMOTE_UPSTREAM  上游地址，默认 http://127.0.0.1:3080
//   DSH_REMOTE_TOKEN     登录口令；缺省时读认证文件，再没有则自动生成
//   DSH_REMOTE_USER      Basic Auth 用户名，默认 dsh
//   DSH_REMOTE_AUTH_FILE 认证文件路径，默认 ~/.dsh/dsh-remote.auth

import http from 'node:http'
import { randomBytes, timingSafeEqual } from 'node:crypto'
import { readFileSync, existsSync, writeFileSync, mkdirSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createGzip, gzipSync } from 'node:zlib'

// ──────────────────────────────────────────────────────────────────────────
// 配置与凭证
// ──────────────────────────────────────────────────────────────────────────
const __dirname = dirname(fileURLToPath(import.meta.url))
const PORT = Number(process.env.DSH_REMOTE_PORT ?? 8082)
const BIND = process.env.DSH_REMOTE_BIND ?? '127.0.0.1'
const UPSTREAM = new URL(process.env.DSH_REMOTE_UPSTREAM ?? 'http://127.0.0.1:3080')
const USER = process.env.DSH_REMOTE_USER ?? 'dsh'
const COOKIE_NAME = 'dsh_remote_config_token' // joyfish APK 兼容
const WS_COOKIE_NAME = 'dsh_ws_auth'
const COOKIE_MAX_AGE = 31536000

const AUTH_FILE = process.env.DSH_REMOTE_AUTH_FILE ?? join(homedir(), '.dsh', 'dsh-remote.auth')
const LEGACY_AUTH_FILE = join(homedir(), '.dsh', 'mobile-remote.auth') // dsh-mobile-app 插件兼容

function loadCredentials(file) {
  if (!existsSync(file)) return null
  const lines = readFileSync(file, 'utf8').split(/\r?\n/).map(l => l.trim()).filter(Boolean)
  const creds = {}
  for (const line of lines) {
    const p = line.indexOf('=')
    if (p > 0) {
      const k = line.slice(0, p).trim().toLowerCase()
      if (k === 'user' || k === 'password') creds[k] = line.slice(p + 1).trim()
    }
  }
  if (creds.password) return { user: creds.user ?? USER, password: creds.password }
  if (lines.length === 1) return { user: USER, password: lines[0] } // 旧格式：单行密码
  return null
}

let PASSWORD = process.env.DSH_REMOTE_TOKEN ?? ''
let credFileUsed = null
if (!PASSWORD) {
  let cred = loadCredentials(AUTH_FILE) ?? loadCredentials(LEGACY_AUTH_FILE)
  credFileUsed = existsSync(AUTH_FILE) || !cred ? AUTH_FILE : (existsSync(LEGACY_AUTH_FILE) ? LEGACY_AUTH_FILE : AUTH_FILE)
  if (!cred) {
    PASSWORD = randomBytes(12).toString('base64url')
    mkdirSync(dirname(AUTH_FILE), { recursive: true })
    writeFileSync(AUTH_FILE, `user=${USER}\npassword=${PASSWORD}\n`, { mode: 0o600 })
    credFileUsed = AUTH_FILE
  } else {
    PASSWORD = cred.password
    if (cred.user) process.env.DSH_REMOTE_USER = process.env.DSH_REMOTE_USER ?? cred.user
  }
}
const FINAL_USER = process.env.DSH_REMOTE_USER ?? USER

// ──────────────────────────────────────────────────────────────────────────
// 小工具
// ──────────────────────────────────────────────────────────────────────────
const HOP_BY_HOP = new Set([
  'connection', 'keep-alive', 'proxy-connection', 'transfer-encoding', 'upgrade',
])

const ASSET_RE = /\.(?:js|mjs|cjs|css|map|png|jpe?g|gif|svg|ico|webp|woff2?|ttf|otf|json|webmanifest|txt)(?:[?#]|$)/i

function log(line) {
  process.stdout.write(`${new Date().toISOString()} dsh-remote ${line}\n`)
}

function safeEqual(a, b) {
  const left = Buffer.from(String(a))
  const right = Buffer.from(String(b))
  if (left.length !== right.length) return false
  return timingSafeEqual(left, right)
}

function cookieValue(req, name) {
  const raw = req.headers.cookie ?? ''
  for (const part of raw.split(';')) {
    const eq = part.indexOf('=')
    if (eq < 0) continue
    if (part.slice(0, eq).trim() === name) {
      try { return decodeURIComponent(part.slice(eq + 1).trim()) } catch { return part.slice(eq + 1).trim() }
    }
  }
  return undefined
}

function encodeCookieValue(value) {
  return encodeURIComponent(value)
}

function isSecure(req) {
  const proto = String(req.headers['x-forwarded-proto'] ?? '')
  return proto.split(',')[0].trim() === 'https'
}

function sessionCookieAttributes(req) {
  // Chromium/WebView 不把 SameSite=Lax cookie 带到 WebSocket 握手；HTTPS 链路上
  // 用 None+Secure 是经过验证的组合。纯 HTTP（仅限本机测试）退化为 Lax，WS 由
  // 注入脚本改用 query token 兜底。
  if (isSecure(req)) return `Path=/; HttpOnly; SameSite=None; Secure; Max-Age=${COOKIE_MAX_AGE}`
  return `Path=/; HttpOnly; SameSite=Lax; Max-Age=${COOKIE_MAX_AGE}`
}

function basicCredentials(req) {
  const auth = req.headers.authorization ?? ''
  const m = auth.match(/^Basic\s+(.+)$/i)
  if (!m) return null
  try {
    const decoded = Buffer.from(m[1], 'base64').toString('utf8')
    const sep = decoded.indexOf(':')
    if (sep < 0) return { user: '', password: '' }
    return { user: decoded.slice(0, sep), password: decoded.slice(sep + 1) }
  } catch {
    return null
  }
}

function isAuthed(req) {
  const cookie = cookieValue(req, COOKIE_NAME)
  if (cookie !== undefined && safeEqual(cookie, PASSWORD)) return true
  const basic = basicCredentials(req)
  const expected = `${FINAL_USER}:${PASSWORD}`
  if (basic) {
    const given = `${basic.user}:${basic.password}`
    if (safeEqual(given, expected)) return true
  }
  return false
}

// ── 登录失败限速（按来源 IP，指数退避） ─────────────────────────────────
const failCount = new Map()
const FAIL_LIMIT = 5
const LOCK_BASE_MS = 10_000
const LOCK_MAX_MS = 300_000

function clientIp(req) {
  return String(req.headers['cf-connecting-ip'] ?? req.socket.remoteAddress ?? 'unknown')
}

function rateLimited(ip) {
  const rec = failCount.get(ip)
  if (!rec) return false
  if (rec.lockedUntil > Date.now()) return true
  if (rec.lockedUntil !== 0) failCount.delete(ip)
  return false
}

function recordFailure(ip) {
  const rec = failCount.get(ip) ?? { count: 0, lockedUntil: 0 }
  rec.count += 1
  if (rec.count >= FAIL_LIMIT) {
    const lock = Math.min(LOCK_BASE_MS * 2 ** (rec.count - FAIL_LIMIT), LOCK_MAX_MS)
    rec.lockedUntil = Date.now() + lock
    rec.count = 0
    log(`IP ${ip} 认证失败过多，锁定 ${Math.round(lock / 1000)}s`)
  }
  failCount.set(ip, rec)
}

function recordSuccess(ip) { failCount.delete(ip) }
setInterval(() => {
  const now = Date.now()
  for (const [ip, rec] of failCount) {
    if (rec.lockedUntil !== 0 && rec.lockedUntil <= now) failCount.delete(ip)
  }
}, 60_000).unref()

// ── WS token（一次性换取，12 小时有效） ──────────────────────────────────
const wsTokens = new Map()
function issueWsToken() {
  const token = randomBytes(24).toString('hex')
  wsTokens.set(token, Date.now() + 12 * 3600e3)
  return token
}
function wsTokenOk(token) {
  if (!token) return false
  const exp = wsTokens.get(token)
  if (!exp) return false
  if (Date.now() > exp) { wsTokens.delete(token); return false }
  return true
}
function wsCookieOk(req) {
  return wsTokenOk(cookieValue(req, WS_COOKIE_NAME))
}
setInterval(() => {
  const now = Date.now()
  for (const [token, exp] of wsTokens) if (exp <= now) wsTokens.delete(token)
}, 600_000).unref()

// ──────────────────────────────────────────────────────────────────────────
// 静态资源
// ──────────────────────────────────────────────────────────────────────────
function loadText(rel) {
  try { return readFileSync(join(__dirname, rel), 'utf8') } catch { return '' }
}
function loadBytes(rel) {
  try { return readFileSync(join(__dirname, rel)) } catch { return null }
}

const MOBILE_CSS = loadText('assets/mobile.css')
const LOGIN_HTML = loadText('assets/login.html')
const MANIFEST_JSON = loadText('assets/manifest.webmanifest')
const SW_JS = loadText('assets/sw.js')
const OFFLINE_HTML = loadText('assets/offline.html')
const ICON_192 = loadBytes('assets/icons/icon-192.png')
const ICON_512 = loadBytes('assets/icons/icon-512.png')
const APPLE_ICON = loadBytes('assets/icons/apple-touch-icon.png')

// ── HTML 注入（PWA + mobile-fit 激活 + WS token + 移动端兜底 CSS） ──────
const WS_AUTH_SCRIPT = [
  '<script data-dsh-remote-ws>',
  '(function(){',
  '  fetch("/__dsh_ws_token",{credentials:"include"})',
  '    .then(function(r){return r.ok?r.json():null})',
  '    .then(function(d){',
  '      if(!d||!d.wsToken)return;',
  '      if(window.__DSH_WS_PATCHED__)return;',
  '      window.__DSH_WS_PATCHED__=true;',
  '      var NativeWS=window.WebSocket;',
  '      window.WebSocket=function(url,protocols){',
  '        if(typeof url==="string"){',
  '          var abs;',
  '          try{abs=new URL(url,window.location.href);}catch(e){abs=null;}',
  '          if(abs&&abs.origin===window.location.origin&&/\\/api\\/events\\.(mux|host)/.test(abs.pathname)){',
  '            abs.search+=((abs.search)?"&":"?")+"dsh_ws="+encodeURIComponent(d.wsToken);',
  '            url=abs.pathname+abs.search+abs.hash;',
  '          }',
  '        }',
  '        return protocols===undefined?new NativeWS(url):new NativeWS(url,protocols);',
  '      };',
  '      window.WebSocket.prototype=NativeWS.prototype;',
  '      window.WebSocket.CONNECTING=NativeWS.CONNECTING;',
  '      window.WebSocket.OPEN=NativeWS.OPEN;',
  '      window.WebSocket.CLOSING=NativeWS.CLOSING;',
  '      window.WebSocket.CLOSED=NativeWS.CLOSED;',
  '    }).catch(function(){});',
  '  if(navigator.serviceWorker){navigator.serviceWorker.register("/__pwa/sw.js").catch(function(){});}',
  '})();',
  '</script>',
].join('\n')

const PWA_INSTALL_HINT = [
  '<script data-dsh-remote-hint>',
  '(function(){',
  '  var iOS=/iPhone|iPad|iPod/.test(navigator.userAgent);',
  '  if(!iOS||window.navigator.standalone===true)return;',
  '  try{if(sessionStorage.getItem("dsh-pwa-hint-dismissed"))return;}catch(e){}',
  '  function show(){',
  '    if(document.getElementById("dsh-pwa-hint"))return;',
  '    var d=document.createElement("div");',
  '    d.id="dsh-pwa-hint";',
  '    d.innerHTML="<span>📲 像 App 一样用：点 Safari 分享按钮 → 添加到主屏幕</span><button aria-label=\\"close\\">×</button>";',
  '    d.style.cssText="position:fixed;left:12px;right:12px;bottom:calc(12px + env(safe-area-inset-bottom,0px));z-index:2147483000;display:flex;align-items:center;gap:8px;padding:10px 12px;background:rgba(20,20,24,0.95);color:#f9fafb;font:13px/1.5 -apple-system,BlinkMacSystemFont,Segoe UI,Roboto,PingFang SC,sans-serif;border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,0.35);";',
  '    d.querySelector("button").style.cssText="flex:none;width:32px;height:32px;border:none;border-radius:50%;background:rgba(255,255,255,0.15);color:#fff;font-size:18px;line-height:1;";',
  '    d.querySelector("button").addEventListener("click",function(){d.remove();try{sessionStorage.setItem("dsh-pwa-hint-dismissed","1");}catch(e){}});',
  '    (document.body||document.documentElement).appendChild(d);',
  '    setTimeout(function(){if(d.parentNode)d.remove();},15000);',
  '  }',
  '  if(document.body)show();else document.addEventListener("DOMContentLoaded",show);',
  '})();',
  '</script>',
].join('\n')

function injectHeadExtras(html) {
  let out = html
  const extras = [
    '<meta name="viewport" data-dsh-remote-viewport content="width=device-width, initial-scale=1, viewport-fit=cover, interactive-widget=resizes-content">',
    '<link rel="manifest" data-dsh-remote-manifest href="/__pwa/manifest.webmanifest">',
    '<link rel="icon" type="image/png" sizes="192x192" href="/__pwa/icons/icon-192.png">',
    '<link rel="apple-touch-icon" data-dsh-remote-ati href="/__pwa/icons/apple-touch-icon.png">',
    '<meta name="theme-color" data-dsh-remote-theme content="#4176E6">',
    '<meta name="mobile-web-app-capable" data-dsh-remote-mwac content="yes">',
    '<meta name="apple-mobile-web-app-capable" data-dsh-remote-amwac content="yes">',
    '<meta name="apple-mobile-web-app-status-bar-style" data-dsh-remote-sb content="default">',
    '<meta name="apple-mobile-web-app-title" data-dsh-remote-amwat content="DSH">',
    `<style data-dsh-remote-css>${MOBILE_CSS}</style>`,
    `<script data-dsh-remote-flag>window.__DSH_PROXY__=true</script>`,
    WS_AUTH_SCRIPT,
    PWA_INSTALL_HINT,
  ].join('\n')
  if (out.includes('data-dsh-remote-manifest')) return out
  // 官方已带 viewport meta 时替换之，避免两个 meta 里第一个生效
  const replaced = out.replace(/<meta[^>]*name=["']viewport["'][^>]*>/i, extras.match(/<meta name="viewport"[^>]*>/)[0])
  if (replaced !== out) {
    out = replaced
    const rest = extras.slice(extras.indexOf('>') + 1)
    out = out.replace(/<\/head>/i, `${rest}</head>`)
  } else {
    out = out.replace(/<\/head>/i, `${extras}</head>`)
  }
  return out
}

// boot manifest 重排：把 mobile-fit 行移到 dsh-client-connection 之后并加 inject 边。
// 该逻辑与 joyfish666/deepseek-harness-remote 的 remote-config-proxy 一致（MIT）。
const CONNECTION_ROW_ID = '@deepseek-ai/dsh-client-connection'

function reorderBootManifest(html) {
  if (!html.includes('window.__DSH_PROXY__')) return html
  const markerAt = html.indexOf('__DSH_BOOT__')
  if (markerAt < 0) return html
  const assignAt = html.indexOf('=', markerAt)
  const jsonStart = html.indexOf('{', assignAt)
  const scriptEnd = html.indexOf('</script>', jsonStart)
  if (assignAt < 0 || jsonStart < 0 || scriptEnd <= jsonStart) return html
  let raw = html.slice(jsonStart, scriptEnd).trim()
  if (raw.endsWith(';')) raw = raw.slice(0, -1)
  let manifest
  try { manifest = JSON.parse(raw) } catch { return html }
  const entries = manifest?.entries
  if (!Array.isArray(entries)) return html
  const mobileFit = entries.findIndex(e => e?.id === 'mobile-fit')
  const connection = entries.findIndex(e => e?.id === CONNECTION_ROW_ID)
  if (mobileFit < 0 || connection < 0 || mobileFit === connection) return html
  const row = entries.splice(mobileFit, 1)[0]
  row.inject = [CONNECTION_ROW_ID]
  entries.splice(connection + 1, 0, row)
  const patched = JSON.stringify(manifest)
  if (patched === raw) return html
  log('boot manifest 已重排：mobile-fit 行移到 connection 之后')
  return html.slice(0, jsonStart) + patched + html.slice(scriptEnd)
}

function rewriteHtml(body) {
  let html = injectHeadExtras(body.toString('utf8'))
  html = reorderBootManifest(html)
  return html
}

// ──────────────────────────────────────────────────────────────────────────
// 登录页 / PWA 静态路由
// ──────────────────────────────────────────────────────────────────────────
function text(res, status, body, extraHeaders = {}) {
  res.writeHead(status, { 'content-type': 'text/plain; charset=utf-8', ...extraHeaders })
  res.end(body)
}

function html(res, status, body, extraHeaders = {}) {
  res.writeHead(status, { 'content-type': 'text/html; charset=utf-8', ...extraHeaders })
  res.end(body)
}

function serveLogin(res, error) {
  const page = LOGIN_HTML.replace('__ERROR__', error
    ? '<div class="error">⚠ 口令不正确。Invalid token.</div>'
    : '<div class="error" style="display:none"></div>')
  html(res, error ? 401 : 200, page, { 'cache-control': 'no-store' })
}

function handleLogin(req, res) {
  const ip = clientIp(req)
  if (rateLimited(ip)) {
    res.writeHead(429, { 'Retry-After': '60' })
    res.end('429 Too Many Requests')
    return
  }
  const chunks = []
  let size = 0
  req.on('data', chunk => {
    size += chunk.length
    if (size > 8192) { req.destroy(); return }
    chunks.push(chunk)
  })
  req.on('end', () => {
    const body = Buffer.concat(chunks).toString('utf8')
    const m = /(?:^|&)(token|password)=([^&]*)/.exec(body)
    const given = m ? decodeURIComponent(m[2].replace(/\+/g, ' ')) : ''
    if (!safeEqual(given, PASSWORD)) {
      recordFailure(ip)
      log(`login 被拒绝  ${ip}`)
      return serveLogin(res, true)
    }
    recordSuccess(ip)
    log(`login 成功  ${ip}`)
    res.writeHead(302, {
      location: '/',
      'set-cookie': `${COOKIE_NAME}=${encodeCookieValue(PASSWORD)}; ${sessionCookieAttributes(req)}`,
      'cache-control': 'no-store',
    })
    res.end()
  })
  req.on('error', () => res.destroy())
}

const PWA_ROUTES = {
  '/__pwa/manifest.webmanifest': { type: 'application/manifest+json; charset=utf-8', body: MANIFEST_JSON, cache: 'no-cache' },
  '/__pwa/sw.js': { type: 'application/javascript; charset=utf-8', body: SW_JS, cache: 'no-cache' },
  '/__pwa/offline.html': { type: 'text/html; charset=utf-8', body: OFFLINE_HTML, cache: 'no-cache' },
  '/__pwa/icons/icon-192.png': { type: 'image/png', body: ICON_192, cache: 'public, max-age=86400' },
  '/__pwa/icons/icon-512.png': { type: 'image/png', body: ICON_512, cache: 'public, max-age=86400' },
  '/__pwa/icons/apple-touch-icon.png': { type: 'image/png', body: APPLE_ICON, cache: 'public, max-age=86400' },
}

function servePwaAsset(req, res) {
  const route = PWA_ROUTES[req.url?.split('?')[0]]
  if (!route || !route.body) return false
  res.writeHead(200, { 'content-type': route.type, 'cache-control': route.cache, 'content-length': Buffer.byteLength(route.body) })
  res.end(route.body)
  return true
}

// ──────────────────────────────────────────────────────────────────────────
// 反代转发
// ──────────────────────────────────────────────────────────────────────────
function forwardHeaders(req, { identityHtml }) {
  const headers = {}
  for (const [name, value] of Object.entries(req.headers)) {
    if (HOP_BY_HOP.has(name) || name === 'host' || name === 'origin') continue
    if (value !== undefined) headers[name] = value
  }
  if (identityHtml) headers['accept-encoding'] = 'identity'
  return headers
}

const upstreamHost = UPSTREAM.port ? `${UPSTREAM.hostname}:${UPSTREAM.port}` : UPSTREAM.hostname

function maybeDocumentGet(req) {
  if (req.method !== 'GET') return false
  const pathname = (req.url ?? '/').split('?')[0]
  if (pathname.startsWith('/api')) return false
  if (pathname === '/' || pathname === '/mobile') return true
  return !ASSET_RE.test(pathname)
}

function acceptsGzip(req) {
  return /(?:^|,|\s)gzip(?:;|,|$)/i.test(String(req.headers['accept-encoding'] ?? ''))
}

function appendVary(headers) {
  const vary = String(headers.vary ?? '')
  if (!/(?:^|,\s*)accept-encoding/i.test(vary)) {
    return { ...headers, vary: vary ? `${vary}, Accept-Encoding` : 'Accept-Encoding' }
  }
  return headers
}

function proxyRequest(req, res) {
  const identityHtml = maybeDocumentGet(req)
  const proxyReq = http.request({
    protocol: UPSTREAM.protocol,
    host: UPSTREAM.hostname,
    port: UPSTREAM.port || undefined,
    method: req.method,
    path: req.url,
    headers: {
      ...forwardHeaders(req, { identityHtml }),
      host: upstreamHost,
      ...(req.headers.origin ? { origin: `http://${upstreamHost}` } : {}),
    },
  }, upstream => {
    const type = String(upstream.headers['content-type'] ?? '')
    // 带 ?rev= 的 bundle 是内容哈希，可安全长缓存（joyfish 同款处理）
    const revQuery = req.url !== undefined && /[?&]rev=[0-9a-fA-F]+/.test(req.url)
    let headers = upstream.headers
    if (revQuery && String(headers['cache-control'] ?? '') !== '') {
      headers = { ...headers, 'cache-control': 'public, max-age=31536000, immutable' }
    }
    const isHtml = type.includes('text/html')
    const noEncoding = String(upstream.headers['content-encoding'] ?? '') === ''
    const wantGzip = acceptsGzip(req)
    if (req.method === 'GET' && isHtml && noEncoding && upstream.statusCode === 200) {
      const chunks = []
      upstream.on('data', c => chunks.push(c))
      upstream.on('end', () => {
        const rewritten = { ...headers }
        delete rewritten['content-length']
        rewritten['cache-control'] = 'no-cache' // 注入内容会变，禁止设备缓存旧 HTML
        const body = Buffer.from(rewriteHtml(Buffer.concat(chunks)))
        if (wantGzip) {
          res.writeHead(upstream.statusCode ?? 502, appendVary({ ...rewritten, 'content-encoding': 'gzip' }))
          res.end(gzipSync(body))
        } else {
          res.writeHead(upstream.statusCode ?? 502, rewritten)
          res.end(body)
        }
        log(`req ${req.method} ${req.url} -> ${upstream.statusCode} (html, 已注入${wantGzip ? ', gzip' : ''})`)
      })
      upstream.on('error', () => res.destroy())
      return
    }
    // 花生壳免费带宽只有约 1Mbps：session.history 等大 JSON 不压缩会 20~30s
    // 才传完，iPad Safari 直接 fetch 超时（历史加载失败）。网关压缩后体积
    // 通常降到 10% 以下，与 dsh-mobile-app 原仓库的实测一致。
    const compressible = noEncoding &&
      upstream.statusCode !== 204 &&
      upstream.statusCode !== 304 &&
      /json|text|javascript|xml/i.test(type)
    if (wantGzip && compressible) {
      const gzipHeaders = appendVary({ ...headers, 'content-encoding': 'gzip' })
      delete gzipHeaders['content-length']
      res.writeHead(upstream.statusCode ?? 502, gzipHeaders)
      upstream.pipe(createGzip()).pipe(res)
      log(`req ${req.method} ${req.url} -> ${upstream.statusCode} (gzip)`)
      return
    }
    res.writeHead(upstream.statusCode ?? 502, headers)
    upstream.pipe(res)
  })
  proxyReq.on('error', error => {
    log(`upstream 错误  ${req.method} ${req.url}  ${error.message}`)
    if (!res.headersSent) text(res, 502, 'bad gateway')
    else res.destroy()
  })
  req.pipe(proxyReq)
}

function unauthorized(req, res) {
  const pathname = (req.url ?? '/').split('?')[0]
  const ip = clientIp(req)
  if (rateLimited(ip)) {
    res.writeHead(429, { 'Retry-After': '60' })
    res.end('429 Too Many Requests')
    return
  }
  // iPhone/浏览器：给登录页；安卓 dsh-mobile-app APK 配置的 /mobile：给 401 挑战，
  // 让 WebView 的 HttpAuthHandler 自动带上保存的账号密码。
  if (req.method === 'GET' && pathname === '/') {
    res.writeHead(302, { location: '/login' })
    res.end()
    return
  }
  if (req.method === 'GET' && pathname === '/login') {
    serveLogin(res, false)
    return
  }
  recordFailure(ip)
  if (pathname.startsWith('/mobile') || pathname === '/') {
    res.writeHead(401, { 'WWW-Authenticate': 'Basic realm="DSH Remote"' })
    res.end('401 Unauthorized')
    return
  }
  if (pathname.startsWith('/__pwa')) {
    res.writeHead(401, { 'WWW-Authenticate': 'Basic realm="DSH Remote"' })
    res.end('401 Unauthorized')
    return
  }
  text(res, 401, 'unauthorized', { 'WWW-Authenticate': 'Basic realm="DSH Remote"' })
}

// ──────────────────────────────────────────────────────────────────────────
// HTTP 服务器
// ──────────────────────────────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  const pathname = (req.url ?? '/').split('?')[0]

  // PWA 静态资源无需登录（manifest/图标是安装元数据）
  if (servePwaAsset(req, res)) return

  if (!isAuthed(req)) {
    if (req.method === 'POST' && pathname === '/login') return handleLogin(req, res)
    return unauthorized(req, res)
  }

  recordSuccess(clientIp(req))

  // WS 认证 token 换取端点（页面加载即 fetch，带 Basic Auth 或会话 cookie）
  if (pathname === '/__dsh_ws_token') {
    const token = issueWsToken()
    res.writeHead(200, {
      'content-type': 'application/json; charset=utf-8',
      'set-cookie': `${WS_COOKIE_NAME}=${token}; Path=/; HttpOnly; SameSite=None; Secure; Max-Age=43200`,
      'cache-control': 'no-store',
    })
    res.end(JSON.stringify({ ok: true, wsToken: token }))
    return
  }

  // 旧 /mobile 入口（dsh-mobile-app APK 兼容）→ 官方 UI 首页
  if (pathname.startsWith('/mobile')) {
    res.writeHead(302, { location: '/' })
    res.end()
    return
  }

  if (pathname === '/login') {
    // 已登录访问 /login：直接回首页
    res.writeHead(302, { location: '/' })
    res.end()
    return
  }

  proxyRequest(req, res)
})

// WebSocket 升级代理（dsh 事件通道 events.mux / events.host）
server.on('upgrade', (req, socket, head) => {
  const authed = isAuthed(req) || wsCookieOk(req) ||
    (() => {
      const m = /[?&]dsh_ws=([^&]+)/.exec(req.url ?? '')
      return m ? wsTokenOk(decodeURIComponent(m[1])) : false
    })()
  if (!authed) {
    log(`upgrade 拒绝  ${req.url}  ${clientIp(req)}`)
    socket.end('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n')
    return
  }
  const pathname = (req.url ?? '').split('?')[0]
  if (!/^\/api\/events\.(mux|host)/.test(pathname)) {
    socket.end('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n')
    return
  }
  const proxyReq = http.request({
    protocol: UPSTREAM.protocol,
    host: UPSTREAM.hostname,
    port: UPSTREAM.port || undefined,
    method: req.method,
    path: req.url,
    agent: false,
    headers: {
      ...forwardHeaders(req, { identityHtml: false }),
      host: upstreamHost,
      ...(req.headers.origin ? { origin: `http://${upstreamHost}` } : {}),
      connection: 'Upgrade',
      upgrade: req.headers.upgrade ?? 'websocket',
    },
  })
  proxyReq.on('upgrade', (upstream, upstreamSocket, upstreamHead) => {
    log(`upgrade 建立  ${pathname}`)
    socket.write('HTTP/1.1 101 Switching Protocols\r\n')
    const raw = upstream.rawHeaders
    for (let i = 0; i + 1 < raw.length; i += 2) socket.write(`${raw[i]}: ${raw[i + 1]}\r\n`)
    socket.write('\r\n')
    if (head.length > 0) upstreamSocket.write(head)
    if (upstreamHead.length > 0) socket.write(upstreamHead)
    upstreamSocket.pipe(socket).pipe(upstreamSocket)
    upstreamSocket.on('error', () => socket.destroy())
    socket.on('error', () => upstreamSocket.destroy())
  })
  proxyReq.on('error', error => {
    log(`upgrade 错误  ${req.url}  ${error.message}`)
    socket.destroy()
  })
  proxyReq.end()
})

server.on('error', error => {
  if (error.code === 'EADDRINUSE') {
    console.error(`[dsh-remote] 端口 ${PORT} 被占用。请先关闭旧进程，或设置 DSH_REMOTE_PORT 换端口。`)
  } else {
    console.error(`[dsh-remote] 服务器错误: ${error.message}`)
  }
  process.exit(1)
})

server.listen(PORT, BIND, () => {
  const line = '─'.repeat(56)
  console.log(line)
  console.log('  DSH Remote 网关已启动')
  console.log(`  监听    : http://${BIND}:${PORT}  ->  ${UPSTREAM.href}`)
  console.log(`  登录用户: ${FINAL_USER}`)
  console.log(`  口令    : ${PASSWORD}`)
  console.log(`  口令文件: ${credFileUsed ?? '(环境变量 DSH_REMOTE_TOKEN)'}`)
  console.log('')
  console.log('  手机访问（二选一，在电脑上另开窗口运行）：')
  console.log('    A. 公网隧道 : powershell -File scripts\\start-cloudflare-tunnel.ps1')
  console.log('    B. Tailscale: powershell -File scripts\\start-tailscale.ps1')
  console.log('')
  console.log('  iPhone: 用 Safari 打开公网地址 → 输口令登录 → 分享 → 添加到主屏幕')
  console.log(line)
  log('gateway listening')
})

function shutdown() {
  log('shutting down')
  server.close(() => process.exit(0))
  setTimeout(() => process.exit(0), 2000).unref()
}
process.on('SIGINT', shutdown)
process.on('SIGTERM', shutdown)
