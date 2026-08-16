// 生成 dsh-remote 的 PWA 图标（纯 Node + zlib，无第三方依赖）。
// 输出：server/assets/icons/icon-192.png、icon-512.png、apple-touch-icon.png
import { deflateSync } from 'node:zlib'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const OUT = join(__dirname, '..', 'server', 'assets', 'icons')

// ── 最小 PNG 编码器 ──────────────────────────────────────────────────────
const CRC_TABLE = (() => {
  const t = new Uint32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    t[n] = c >>> 0
  }
  return t
})()

function crc32(buf) {
  let c = 0xffffffff
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const out = Buffer.alloc(8 + data.length + 4)
  out.writeUInt32BE(data.length, 0)
  out.write(type, 4, 'ascii')
  data.copy(out, 8)
  out.writeUInt32BE(crc32(Buffer.concat([Buffer.from(type, 'ascii'), data])), 8 + data.length)
  return out
}

function encodePng(size, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(size, 0)
  ihdr.writeUInt32BE(size, 4)
  ihdr[8] = 8   // bit depth
  ihdr[9] = 6   // RGBA
  const raw = Buffer.alloc(size * (size * 4 + 1))
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0 // filter: none
    rgba.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4)
  }
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))])
}

// ── 像素绘制：蓝紫渐变圆角底 + 白色对话气泡 + 三个蓝点 ─────────────────
function hex(c) {
  return [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)]
}

const top = hex('#4D7CFE')
const bottom = hex('#2F5BE7')

function lerp(a, b, t) { return a + (b - a) * t }

function inRoundedRect(x, y, x0, y0, x1, y1, r) {
  if (x < x0 || x > x1 || y < y0 || y > y1) return false
  const cx = Math.max(x0 + r, Math.min(x, x1 - r))
  const cy = Math.max(y0 + r, Math.min(y, y1 - r))
  const dx = x - cx
  const dy = y - cy
  return dx * dx + dy * dy <= r * r
}

function drawIcon(size) {
  const px = Buffer.alloc(size * size * 4)
  const R = size * 0.235
  const cx = size / 2
  const cy = size / 2
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4
      if (!inRoundedRect(x, y, 0, 0, size - 1, size - 1, R)) { px[i + 3] = 0; continue }
      const t = y / size
      const col = [lerp(top[0], bottom[0], t), lerp(top[1], bottom[1], t), lerp(top[2], bottom[2], t)]
      px[i] = col[0]; px[i + 1] = col[1]; px[i + 2] = col[2]; px[i + 3] = 255
    }
  }
  const set = (x, y, c, a = 255) => {
    if (x < 0 || y < 0 || x >= size || y >= size) return
    const i = (Math.round(y) * size + Math.round(x)) * 4
    const s = a / 255
    px[i] = Math.round(px[i] * (1 - s) + c[0] * s)
    px[i + 1] = Math.round(px[i + 1] * (1 - s) + c[1] * s)
    px[i + 2] = Math.round(px[i + 2] * (1 - s) + c[2] * s)
    px[i + 3] = 255
  }
  const white = [255, 255, 255]
  // 气泡主体（圆角矩形）
  const b = { x0: size * 0.18, y0: size * 0.30, x1: size * 0.82, y1: size * 0.66 }
  for (let y = b.y0; y <= b.y1; y++) {
    for (let x = b.x0; x <= b.x1; x++) {
      if (inRoundedRect(x, y, b.x0, b.y0, b.x1, b.y1, size * 0.12)) set(x, y, white)
    }
  }
  // 气泡尾巴（左下小三角）
  for (let t = 0; t <= size * 0.16; t++) {
    const y = b.y1 + t
    for (let x = b.x0 + size * 0.02; x <= b.x0 + size * 0.02 + t * 0.8; x++) set(x, y, white)
  }
  // 三个蓝点
  const dotColor = [47, 91, 231]
  const dotY = size * 0.48
  for (let d = 0; d < 3; d++) {
    const dotX = size * (0.38 + d * 0.12)
    const r = size * 0.036
    for (let y = dotY - r; y <= dotY + r; y++) {
      for (let x = dotX - r; x <= dotX + r; x++) {
        const dx = (x - dotX) / r
        const dy = (y - dotY) / r
        if (dx * dx + dy * dy <= 1) set(x, y, dotColor)
      }
    }
  }
  return px
}

mkdirSync(OUT, { recursive: true })
for (const size of [180, 192, 512]) {
  const file = size === 180 ? 'apple-touch-icon.png' : `icon-${size}.png`
  writeFileSync(join(OUT, file), encodePng(size, drawIcon(size)))
  console.log(`wrote ${file}`)
}
