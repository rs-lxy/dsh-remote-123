#!/usr/bin/env python3
"""Generate XHS-ready promo posters for the dsh-remote repo."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'posters')
ICON = os.path.join(ROOT, 'server', 'assets', 'icons', 'icon-512.png')
os.makedirs(OUT, exist_ok=True)

W, H = 1080, 1440
DARK_TOP = (17, 17, 20)
DARK_BOT = (30, 41, 59)
BRAND = (65, 118, 230)
BRAND_LIGHT = (103, 158, 254)
CARD = (34, 36, 42)
TEXT = (249, 250, 251)
SUB = (173, 174, 178)
GREEN = (74, 222, 128)
AMBER = (251, 191, 36)

FONT_BOLD = os.path.join('C:\Windows\Fonts', 'msyhbd.ttc')
FONT = os.path.join('C:\Windows\Fonts', 'msyh.ttc')


def font(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT, size)


def gradient(size):
    top, bottom = DARK_TOP, DARK_BOT
    w, h = size
    base = Image.new('RGB', size, top).convert('RGBA')
    px = base.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(0, w, 2):
            px[x, y] = c
            if x + 1 < w:
                px[x + 1, y] = c
    return base


def glow_box(draw, box, fill, radius=32, alpha=0):
    layer = Image.new('RGBA', (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, layer.width - 1, layer.height - 1), radius=radius, fill=fill + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(18))
    base = draw._image
    base.alpha_composite(layer, (box[0], box[1]))


def card(draw, box, fill=CARD, radius=28, outline=(255, 255, 255, 26), glow=False):
    if glow:
        glow_box(draw, box, BRAND, radius=radius, alpha=120)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=2)


def wrap(draw, text, fnt, max_w):
    lines, cur = [], ''
    for ch in text:
        t = cur + ch
        if draw.textbbox((0, 0), t, font=fnt)[2] <= max_w or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = ch
    if cur:
        lines.append(cur)
    return lines


def text_block(draw, xy, text, fnt, color=TEXT, max_w=900, line_h=1.35):
    x, y = xy
    for line in wrap(draw, text, fnt, max_w):
        draw.text((x, y), line, font=fnt, fill=color)
        y += int(fnt.size * line_h)


def footer(draw):
    draw.text((80, H - 70), 'GitHub: rs-lxy/dsh-remote-123', font=font(30), fill=SUB)
    draw.text((W - 80, H - 70), 'dsh-remote', font=font(30, True), fill=BRAND_LIGHT, anchor='ra')


def icon_paste(base, box, radius=40):
    icon = Image.open(ICON).convert('RGBA').resize((box[2] - box[0], box[3] - box[1]), Image.LANCZOS)
    mask = Image.new('L', icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, icon.width - 1, icon.height - 1), radius=radius, fill=255)
    base.paste(icon, (box[0], box[1]), mask)


def header(base, title, subtitle):
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((70, 70, W - 70, 200), radius=32, fill=(18, 19, 23), outline=(255, 255, 255, 30), width=2)
    d.text((100, 102), 'DeepSeek Harness · 远程控制', font=font(28), fill=BRAND_LIGHT)
    d.text((100, 132), title, font=font(44, True), fill=TEXT)
    d.text((100, 190), subtitle, font=font(30), fill=SUB)


def bullet(draw, x, y, text, size=38, color=TEXT, bullet_color=BRAND_LIGHT, check=False, wrap_w=760):
    d = draw
    d.ellipse((x, y + 8, x + 26, y + 34), fill=bullet_color if not check else GREEN)
    d.text((x + 44, y), text, font=font(size), fill=color)
    return y + 80


# ---------- Poster 1: hero ----------
base = gradient((W, H))
d = ImageDraw.Draw(base)
header(base, 'DSH Remote', '把电脑上的 AI 装进手机')
icon_paste(base, (W // 2 - 140, 260, W // 2 + 140, 540), 70)
d.text((W // 2, 590), 'iPhone · iPad · Android', font=font(46, True), fill=TEXT, anchor='ma')
d.text((W // 2, 665), '三端同步，出门即用', font=font(38), fill=BRAND_LIGHT, anchor='ma')

card(d, (110, 760, W - 110, 1330), radius=36, glow=True)
bullets = [
    ('免签名：Safari 添加到主屏幕，就是独立 App', True),
    ('免 VPN：花生壳固定 HTTPS 域名直接访问', True),
    ('三端同步：会话/审批/工具执行与电脑一致', True),
    ('安全：口令登录 + 登录限速 + 回环隔离', True),
    ('流畅：历史接口 gzip 压缩提速 19 倍', True),
]
y = 830
for t, c in bullets:
    y = bullet(d, 180, y, t, size=40, check=c) + 30
footer(d)
base.save(os.path.join(OUT, 'poster-1-hero.png'), 'PNG')

# ---------- Poster 2: architecture ----------
base = gradient((W, H))
d = ImageDraw.Draw(base)
header(base, '一条链路，三种终端', '不用公网 IP，不用路由器端口映射')
icon_paste(base, (W // 2 - 80, 230, W // 2 + 80, 390), 36)
d.text((W // 2, 425), 'iPhone PWA · iPad PWA · Android APK', font=font(34), fill=TEXT, anchor='ma')

nodes = [
    ('手机 / 平板', 'Safari PWA 或 APK'),
    ('HTTPS 隧道', '花生壳 / localhost.run / Cloudflare / Tailscale'),
    ('DSH Remote 网关', '登录 · PWA 注入 · 信任围栏 · WebSocket · gzip'),
    ('dsh web', '127.0.0.1:3080（电脑上正在运行的实例）'),
]
y = 500
for i, (title, sub) in enumerate(nodes):
    box = (150, y, W - 150, y + 150)
    card(d, box, radius=26)
    d.ellipse((180, y + 42, 226, y + 88), fill=BRAND)
    d.text((246, y + 50), title, font=font(34, True), fill=TEXT)
    d.text((246, y + 92), sub, font=font(26), fill=SUB)
    if i < len(nodes) - 1:
        d.line((W // 2, y + 150, W // 2, y + 195), fill=BRAND_LIGHT, width=6)
        d.polygon([(W // 2 - 16, y + 186), (W // 2 + 16, y + 186), (W // 2, y + 216)], fill=BRAND_LIGHT)
    y += 195
card(d, (150, 1210, W - 150, 1320), radius=26, fill=(18, 19, 23))
d.text((W // 2, 1245), 'dsh 官方只绑回环，网关是唯一认证边界', font=font(30), fill=GREEN, anchor='ma')
footer(d)
base.save(os.path.join(OUT, 'poster-2-architecture.png'), 'PNG')

# ---------- Poster 3: quick start ----------
base = gradient((W, H))
d = ImageDraw.Draw(base)
header(base, '三步上手', '克隆仓库 → 一条命令 → 手机登录')
steps = [
    ('01', '电脑端', '运行 dsh web + 启动 DSH Remote 网关（零依赖 Node）'),
    ('02', '外网地址', '花生壳 / localhost.run / Cloudflare / Tailscale 任选其一'),
    ('03', '手机端', 'Safari 打开地址 → 输口令 → 添加到主屏幕；安卓装 APK'),
]
y = 250
for num, title, desc in steps:
    box = (120, y, W - 120, y + 270)
    card(d, box, radius=36, glow=(num == '01'))
    d.ellipse((170, y + 40, 280, y + 150), fill=BRAND)
    d.text((225, y + 55), num, font=font(56, True), fill=TEXT, anchor='ma')
    d.text((330, y + 40), title, font=font(40, True), fill=TEXT)
    text_block(d, (330, y + 100), desc, font(30), color=SUB, max_w=560, line_h=1.5)
    y += 320
card(d, (120, 1250, W - 120, 1340), radius=28, fill=(18, 19, 23))
d.text((W // 2, 1275), '克隆即用：github.com/rs-lxy/dsh-remote-123', font=font(32, True), fill=BRAND_LIGHT, anchor='ma')
footer(d)
base.save(os.path.join(OUT, 'poster-3-quickstart.png'), 'PNG')

print('posters written to', OUT)
