// Verify the gateway passes the dsh trust fence.
// Usage:
//   DSH_GATEWAY=http://127.0.0.1:8082 DSH_TOKEN=<password> node tools/test-api.mjs
// or:
//   node tools/test-api.mjs http://127.0.0.1:8082 <password>
const base = process.env.DSH_GATEWAY ?? process.argv[2] ?? 'http://127.0.0.1:8082'
const token = process.env.DSH_TOKEN ?? process.argv[3] ?? ''
if (!token) {
  console.error('usage: node tools/test-api.mjs <gateway-base> <token>  (or set DSH_GATEWAY / DSH_TOKEN)')
  process.exit(2)
}
const user = process.env.DSH_USER ?? 'dsh'
const cookie = 'dsh_remote_config_token=' + encodeURIComponent(token)

async function post(path, headers = {}) {
  const res = await fetch(base + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify({ type: 'client-request', rpcId: 'test-' + Math.random().toString(16).slice(2), method: 'session.list', payload: {} }),
  })
  const text = await res.text()
  return { status: res.status, body: text.slice(0, 300) }
}

console.log('via gateway (cookie):', await post('/api/session.list', { cookie }))

const directBase = process.env.DSH_UPSTREAM ?? 'http://127.0.0.1:3080'
const direct = await fetch(directBase + '/api/session.list', {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ type: 'client-request', rpcId: 'test-direct', method: 'session.list', payload: {} }),
})
console.log('direct (loopback)   :', direct.status, (await direct.text()).slice(0, 300))

// Basic Auth compatibility (dsh-mobile-app APK path)
const auth = Buffer.from(`${user}:${token}`).toString('base64')
const res = await fetch(base + '/', { headers: { authorization: 'Basic ' + auth } })
console.log('basic auth GET /     :', res.status, (await res.text()).slice(0, 60))
