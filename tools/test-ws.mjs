// WebSocket upgrade test through the dsh-remote gateway.
// Usage:
//   DSH_GATEWAY=http://127.0.0.1:8082 DSH_TOKEN=<password> node tools/test-ws.mjs
// or:
//   node tools/test-ws.mjs http://127.0.0.1:8082 <password>
const base = process.env.DSH_GATEWAY ?? process.argv[2] ?? 'http://127.0.0.1:8082'
const token = process.env.DSH_TOKEN ?? process.argv[3] ?? ''
if (!token) {
  console.error('usage: node tools/test-ws.mjs <gateway-base> <token>  (or set DSH_GATEWAY / DSH_TOKEN)')
  process.exit(2)
}
const url = base.replace(/^http/, 'ws') + '/api/events.host'
const ws = new WebSocket(url, { headers: { cookie: 'dsh_remote_config_token=' + encodeURIComponent(token) } })
const timer = setTimeout(() => { console.log('TIMEOUT: no open event'); process.exit(2) }, 10000)
ws.addEventListener('open', () => {
  clearTimeout(timer)
  console.log('WS OPEN OK ->', url)
  ws.close()
  process.exit(0)
})
ws.addEventListener('error', e => {
  clearTimeout(timer)
  console.log('WS ERROR', e.message ?? e)
  process.exit(1)
})
ws.addEventListener('close', e => {
  console.log('WS CLOSED', e.code, e.reason)
})
