// Verify the privileged settings plane through the gateway.
// Usage: node tools/test-settings.mjs <gateway-base> <token> [upstream-base]
const base = process.argv[2] ?? 'http://127.0.0.1:8082'
const token = process.argv[3] ?? ''
const upstream = process.argv[4] ?? 'http://127.0.0.1:3080'
if (!token) {
  console.error('usage: node tools/test-settings.mjs <gateway-base> <token> [upstream-base]')
  process.exit(2)
}
const cookie = 'dsh_remote_config_token=' + encodeURIComponent(token)

async function post(origin, path, extraHeaders = {}) {
  const res = await fetch(origin + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...extraHeaders },
    body: JSON.stringify({ type: 'client-request', rpcId: 't-' + Math.random().toString(16).slice(2), method: 'settings.describe', payload: {} }),
  })
  return { status: res.status, body: (await res.text()).slice(0, 260) }
}

console.log('gateway settings.describe:', await post(base, '/api/settings.describe', { cookie }))
console.log('direct  settings.describe:', await post(upstream, '/api/settings.describe'))
