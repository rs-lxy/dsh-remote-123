# 外网通道详解：localhost.run / Cloudflare / Tailscale

dsh-remote 网关只监听电脑回环地址（127.0.0.1:8082）。手机从外网到达它有几种方式，
全部都是 HTTPS（dsh 官方 UI 依赖 Web Crypto 安全上下文，明文 HTTP 不可用）。

| 方案 | 手机要装 App？ | 域名 | 安全性 | 配置成本 | 结论 |
|---|---|---|---|---|---|
| **A. localhost.run（推荐）** | 否 | 免费随机 `*.lhr.life`，重连会变 | 靠强口令 | 极低（1 条命令，免注册） | 国内实测可用，即开即用 |
| B. Cloudflare 快速隧道 | 否 | 每次重启随机 `*.trycloudflare.com` | 靠强口令 | 极低 | 部分国内线路被边缘过滤，备选 |
| C. Cloudflare 固定域名隧道 | 否 | 自有域名，永久 | 靠强口令 | 中（需域名+一次配置） | 真公网、固定桌面图标 |
| D. Tailscale | 是（VPN App） | `机器名.tailnet.ts.net`，永久 | 最高（私有组网+口令） | 中（两设备登录同一账号） | 最安全，可选 |

---

## A. localhost.run（免注册、免 VPN，国内可用，推荐）

原理：Windows 自带 OpenSSH 客户端通过 SSH 反向隧道把电脑的 8082 端口暴露到
`https://xxxx.lhr.life`，localhost.run 服务器做 TLS 终止。不需要注册账号、
不需要手机装任何东西、不需要路由器映射。

```powershell
# 一条命令后台全包（网关 + 隧道 + 打印手机地址）
powershell -File server\scripts\start-remote.ps1

# 或前台窗口版（自己看 URL 和二维码）
powershell -File server\scripts\start-localhostrun.ps1
```

- 已在你的网络实测：登录页 200、口令登录 302、dsh 页面 200、
  `/api/session.list` 返回真实会话、WebSocket 握手成功；
- 免费 URL 随机，电脑/隧道重连后会变：重跑 `start-remote.ps1` 打印新地址即可；
  iPhone 主屏幕图标在换地址后需重新「添加到主屏幕」一次；
- 想要长期固定域名：可在 localhost.run 注册免费账号（它支持长期域名），
  或改用方案 C（Cloudflare 固定域名）。

## B. Cloudflare 快速隧道（零配置，备选）

```powershell
# 安装一次
powershell -File server\scripts\install-cloudflared.ps1
# 或：winget install Cloudflare.cloudflared

# 每次用（前台窗口版，URL 打印在窗口里）
powershell -File server\scripts\start-cloudflare-tunnel.ps1
```

电脑端 cloudflared 进程连到 Cloudflare 边缘，反向把公网 `https://xxxx.trycloudflare.com`
流量送回本机 8082。无需路由器端口映射、无需公网 IP。

缺点：**每次重启 URL 变**；`*.trycloudflare.com` 在部分国内网络线路下可能被
Cloudflare 边缘过滤（表现为 cloudflared 已注册但访问仍 404/530）。遇到这种情况
用方案 A（已验证）或 C。

## C. Cloudflare 固定域名隧道（真公网，永久地址）

要求：一个域名（可免费/几块钱），并把 DNS 托管到 Cloudflare。

一次性配置：

```powershell
cloudflared tunnel login
cloudflared tunnel create mydsh
# 编辑 %USERPROFILE%\.cloudflared\config.yml：
#   tunnel: <上一步打印的 tunnel id>
#   credentials-file: %USERPROFILE%\.cloudflared\<id>.json
#   ingress:
#     - hostname: mydsh.example.com
#       service: http://127.0.0.1:8082
#     - service: http_status:404
cloudflared tunnel route dns mydsh mydsh.example.com
```

日常启动：

```powershell
powershell -File server\scripts\start-gateway.ps1             # 窗口 1
powershell -File server\scripts\start-cloudflare-named.ps1 -TunnelName mydsh   # 窗口 2
```

手机地址永远不变：`https://mydsh.example.com/`。iPhone 添加到主屏幕后永远有效，
安卓 APK 地址也不用改。

## D. Tailscale（私有组网，最安全；你不想装可跳过）

1. 电脑装 Tailscale：https://tailscale.com/download ，登录账号；
2. iPhone App Store 装 Tailscale，登录**同一账号**；安卓同理；
3. 电脑运行：

```powershell
powershell -File server\scripts\start-tailscale.ps1
```

脚本执行 `tailscale serve --bg 8082`（Tailscale 给 `https://机器名.tailnet.ts.net/`
签发证书并转发到网关）。serve 配置持久，电脑重启自动恢复。

特点：地址永久固定；只有登录了你 tailnet 账号的设备能连，额外设备级认证；
手机需要保持 Tailscale App 的 VPN 连接。

## 组合建议

- **现在就用**：A（localhost.run，免注册免 VPN）；
- **长期固定地址**：C（Cloudflare 固定域名）；如愿意装 VPN 可选 D（Tailscale）；
- A/B/C/D 可同时开，网关只有一个，所有入口都指向同一个 dsh 实例。
