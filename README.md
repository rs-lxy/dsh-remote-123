# DSH Remote —— 用手机远程控制你电脑上的 DeepSeek Harness

把电脑上正在运行的 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`dsh web`，默认 `127.0.0.1:3080`）安全地搬到手机上：

- **iPhone / iPad**：Safari「添加到主屏幕」即成为独立全屏 PWA App（无需签名 / TestFlight / 越狱）；
- **安卓**：`dist/android/` 内置两个现成 WebView 壳 APK，装上填地址即用；
- **三端同步**：手机操作的就是电脑上同一个 `dsh web` 实例，会话、审批、工具执行实时同步；
- **出门可用**：支持花生壳固定 HTTPS 域名、localhost.run、Cloudflare Tunnel、Tailscale 多种外网通道；
- **登录保护**：口令登录 + HttpOnly cookie + Basic Auth 兼容 + 登录限速；
- **移动端 UI**：集成 `@dsh/mobile-adapt`（单列布局、全屏侧边栏抽屉、全屏设置/详情、输入栏换行、防 iOS 聚焦缩放）；
- **慢链路优化**：网关自动 gzip 压缩大 JSON（`session.history` 从 4.4MB/27s 压到 0.35MB/1.4s）。

---

## 架构

```
iPhone PWA / 安卓 APK / 浏览器
        │  HTTPS（花生壳 / localhost.run / cloudflared / tailscale）
        ▼
dsh-remote 登录网关（默认 127.0.0.1:8082，只绑回环）
  ① 口令登录 / Basic Auth，HttpOnly cookie，登录限速
  ② 注入 PWA manifest / 图标 / Service Worker / 移动端 CSS
  ③ Host/Origin 改写为 loopback → 通过 dsh 官方信任围栏，远程也能打开设置
  ④ 透传 /api/* 与 /api/events.mux|host WebSocket（审批推送）
  ⑤ 对 JSON/文本/HTML 响应自动 gzip（免费 1Mbps 隧道也能流畅加载历史）
        │
        ▼
dsh web（127.0.0.1:3080，官方进程，保持回环绑定不变）
```

设计原因：dsh 官方**拒绝绑定 0.0.0.0**（防止把可执行命令接口暴露到网络），且 `trustedHosts`
官方明确说**不是认证层**。因此本项目把认证放在独立网关上，dsh 永远只绑回环，外网只通过 HTTPS 隧道到达网关。

## 目录结构

```
dsh-remote/
├── server/
│   ├── gateway.mjs               # 零依赖 Node 网关（登录 + PWA 注入 + 反代 + WS + gzip）
│   ├── assets/                   # 登录页、manifest、SW、离线页、移动 CSS、图标
│   ├── mobile-adapt/             # 移动端适配插件（juanlian583/dsh-mobile-adapt, MIT）
│   ├── mobile-fit/               # 旧版移动端适配插件（joyfish, MIT，可选回退）
│   └── scripts/                  # 一键启动 / 隧道 / 自启 / 停止 / 地址查询脚本
├── tools/                        # 图标生成、自测脚本、cloudflared 下载器
├── dist/android/                 # 现成安卓 APK × 2
├── docs/                         # iPhone PWA、安卓、隧道选型、花生壳教程
├── LICENSE                       # MIT
├── THIRD_PARTY_NOTICES.md
└── README.md
```

## 快速开始（拉下来 5 分钟跑通）

### 0. 前置

- Windows / macOS / Linux 电脑，已装 Node.js（建议 ≥ 18，本项目零 npm 依赖）；
- 电脑上 `dsh web` 可正常启动：
  ```bash
  npx @deepseek-ai/dsh web        # 默认监听 http://127.0.0.1:3080
  ```

### 1. 克隆并启动网关

```powershell
git clone https://github.com/rs-lxy/dsh-remote-123.git
cd dsh-remote-123

# 启动登录网关（前台窗口，Ctrl+C 停止）
powershell -NoProfile -ExecutionPolicy Bypass -File server\scripts\start-gateway.ps1
```

首次启动自动生成口令，写入 `~/.dsh/dsh-remote.auth`（`user=dsh` + `password=随机值`）。
自定义口令：编辑该文件里的 `password=` 行，重启网关生效。

### 2. 开一个外网通道（任选其一）

| 通道 | 命令 | 地址 | 说明 |
|---|---|---|---|
| **localhost.run（免注册）** | `start-remote.ps1` | 免费随机 `*.lhr.life`，重连会变 | 零账号快速体验，紧急备用 |
| **花生壳免费版（国内固定）** | 见 [docs/oray-guide.md](docs/oray-guide.md) | 固定 `*.vicp.fun` 等 | 需手机号注册+实名，HTTPS 自动证书 |
| Cloudflare 快速隧道 | `install-cloudflared.ps1` + `start-cloudflare-tunnel.ps1` | 随机 `*.trycloudflare.com` | 部分国内线路被边缘过滤 |
| Cloudflare 固定域名 | `start-cloudflare-named.ps1 -TunnelName mydsh` | 自有域名固定 | 最稳的公网固定地址（需域名） |
| Tailscale | `start-tailscale.ps1` | 固定 `*.ts.net` | 手机需装 Tailscale App |

> 网关默认只绑 `127.0.0.1`。所有公网入口都由上面的隧道把 8082 转发出去，**不要**
> 设置 `DSH_REMOTE_BIND=0.0.0.0` 直接暴露网关。

### 3. 安装移动端适配插件（可选但强烈推荐）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File server\scripts\install-mobile-adapt.ps1
# 重启 dsh web 生效：
# 关闭 dsh web 窗口后重新运行 npx @deepseek-ai/dsh web
```

### 4. iPhone / iPad 使用

1. Safari 打开你的公网地址（例如 `https://xxx.lhr.life` 或花生壳固定域名）；
2. 输入口令登录；
3. 分享按钮 → **添加到主屏幕**；
4. 桌面出现 DSH 图标，以后点开就是全屏独立 App。

详见 [docs/ios-pwa-guide.md](docs/ios-pwa-guide.md)。

### 5. 安卓使用

安装 `dist/android/dsh-mobile-app-release.apk`（或 `deepseek-harness-remote-release.apk`），
填地址 + 用户名/口令（Token）。详见 [docs/android-guide.md](docs/android-guide.md)。

### 6. 开机自启（可选）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File server\scripts\install-autostart.ps1
```

注册计划任务：`dsh-web`（如已存在则保留）、`dsh-remote-gateway`、按需的隧道任务。
花生壳客户端在其自身设置/注册表 Run 中自启。

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `DSH_REMOTE_PORT` | `8082` | 网关监听端口 |
| `DSH_REMOTE_BIND` | `127.0.0.1` | 网关监听地址 |
| `DSH_REMOTE_UPSTREAM` | `http://127.0.0.1:3080` | dsh web 地址 |
| `DSH_REMOTE_TOKEN` | 读认证文件/自动生成 | 登录口令 |
| `DSH_REMOTE_USER` | `dsh` | Basic Auth 用户名 |
| `DSH_REMOTE_AUTH_FILE` | `~/.dsh/dsh-remote.auth` | 认证文件路径 |

## 安全说明

- **口令就是唯一边界**：拿到口令 = 拿到电脑上 dsh 的执行能力，请改成强口令；
- 网关只绑回环；公网必须走 HTTPS 隧道；
- 登录限速：同一 IP 连续失败 5 次锁 10s，指数翻倍至 5 分钟；
- 会话 cookie HttpOnly；WS 只放行 dsh 的 `events.mux/host` 通道；
- 网关改写 Host/Origin 为 loopback 后，远程也能修改模型/API Key/权限——这是本项目设计目标，
  风险由网关口令抵消；
- 花生壳免费版约 1Mbps / 月 1GB 流量；大文件请使用带宽更大的方案。

## 实测验证记录

在 `dsh 0.1.0-rc.6`（Node 24，Windows）上实际通过：

| 项目 | 结果 |
|---|---|
| 登录页 / 口令错误 401 / 登录成功 Set-Cookie | ✅ |
| Basic Auth（dsh-mobile-app APK 路径）与 `/mobile` 302 | ✅ |
| PWA 注入（manifest / 图标 / SW / viewport / WS 引导） | ✅ |
| `/api/session.list`、`/api/settings.describe` 经网关可用 | ✅ |
| WebSocket `events.mux` / `events.host` 升级握手 | ✅ |
| `@dsh/mobile-adapt` boot manifest 加载 | ✅ |
| gzip：`session.history` 4.45MB → 0.35MB，27.6s → 1.4s | ✅ |
| 花生壳 HTTPS 固定域名全链路（登录/页面/API/WSS） | ✅ |

## 我们参考了什么 / 做了什么

### 参考与借用的开源项目

| 项目 | 参考内容 |
|---|---|
| [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) | 官方 dsh 本体、信任围栏与插件机制 |
| [hongshuxifan321/dsh-mobile-app](https://github.com/hongshuxifan321/dsh-mobile-app) | 安卓 WebView 壳 + Basic Auth 认证代理 + loopback Host 改写 + 大 JSON gzip 的思路；其 Release APK 收录于 `dist/android` |
| [joyfish666/deepseek-harness-remote](https://github.com/joyfish666/deepseek-harness-remote) | mobile-fit 移动适配（MIT）、boot manifest 重排、WS cookie/token 技术；其 Release APK 收录于 `dist/android` |
| [juanlian583/dsh-mobile-adapt](https://github.com/juanlian583/dsh-mobile-adapt) | 当前默认移动端 UI 插件（MIT，纯 client 端，`data-slot` 稳定选择器） |
| [citrusli2026/dsh-mobile-shell](https://github.com/citrusli2026/dsh-mobile-shell) | 调研参考：Capacitor 双端壳 + token 网关的安全模型 |
| [icodesign/orbis](https://github.com/icodesign/orbis) | 调研参考：设备配对 + E2E 加密的远程控制思路 |
| [stars2022/Dsh-macUI](https://github.com/stars2022/Dsh-macUI) | 调研参考：原生 SwiftUI iOS 客户端与加密中继方案 |

### 本项目自己实现的部分

- 零依赖 `gateway.mjs`：登录页 + cookie/Basic Auth 双认证、登录限速、PWA 全套注入、
  Host/Origin loopback 改写、WebSocket 代理、HTML 重写、自动 gzip；
- 一键脚本族：`start-gateway / start-remote / start-localhostrun / start-tailscale /
  start-cloudflare-* / install-autostart / show-url / stop-remote`；
- mobile-fit → mobile-adapt 自动挂载/切换/卸载脚本；
- PWA 资源（manifest、Service Worker、离线页、自绘图标）与移动端兜底 CSS；
- 花生壳 / localhost.run / Cloudflare / Tailscale 四通道中文教程；
- 本 README 与全套故障排查文档。

## 许可证

- 本项目自有代码：MIT（见 `LICENSE`）；
- `server/mobile-adapt`：MIT，来自 juanlian583/dsh-mobile-adapt；
- `server/mobile-fit`：MIT，来自 joyfish666/deepseek-harness-remote；
- `dist/android/*.apk`：原样收录自上游 Release，版权归原仓库所有；
- 详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目与 DeepSeek AI 无隶属关系，非官方产品。
