// WebSocket test over a public HTTPS tunnel.
// Usage: node tools/test-ws-public.mjs <https-base-url> <token>
const base = process.argv[2]
const token = process.argv[3]
if (!base || !token) {
  console.error('usage: node tools/test-ws-public.mjs <https-base-url> <token>')
  process.exit(2)
}
const url = base.replace(/^http/, 'ws') + '/api/events.host'
const ws = new WebSocket(url, { headers: { cookie: 'dsh_remote_config_token=' + encodeURIComponent(token) } })
const timer = setTimeout(() => { console.log('TIMEOUT'); process.exit(2) }, 15000)
ws.addEventListener('open', () => {
  clearTimeout(timer)
  console.log('PUBLIC WSS OPEN OK ->', url)
  ws.close()
  process.exit(0)
})
ws.addEventListener('error', e => {
  clearTimeout(timer)
  console.log('WSS ERROR', e.message ?? e)
  process.exit(1)
})
ws.addEventListener('close', e => console.log('WSS CLOSED', e.code, e.reason))
