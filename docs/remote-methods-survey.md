# DeepSeek Harness 远程访问方案调研（GitHub / B 站 / 社区，2026-08）

调研问题：电脑上跑 `dsh web`（默认只绑 `127.0.0.1:3080`），人不在电脑前时，
手机 / 平板如何安全地远程控制它？

## 一、社区里的主流路线

| 方案 | 代表项目 | 原理 | 手机端 | 公网支持 |
|---|---|---|---|---|
| 插件内置二维码 + Cloudflare 快速隧道 | [shaobeichen/dsh-pocket](https://github.com/shaobeichen/dsh-pocket) | npm 插件在 dsh 设置页出「手机访问」，局域网二维码 + cloudflared 公网二维码 | 浏览器 / PWA | ✅（随机 URL，URL 即钥匙） |
| 插件内认证代理 + frpc | [@xiaosenho/dsh-plugin-remote-access](https://www.npmjs.com/package/@xiaosenho/dsh-plugin-remote-access) | 设置页开关，局域网监听 + 连接自建 frps，链接 token 换 HttpOnly Cookie | 浏览器 | ✅（需 frps/域名） |
| 局域网审批网关 | [hchao3335-maker/dsh-lan-gate](https://github.com/hchao3335-maker/dsh-lan-gate) | 进程内代理 `0.0.0.0:3088→127.0.0.1:3080`，新设备首次访问需本机批准 | 浏览器 | ❌（可再接隧道） |
| 测试版原生 iOS 客户端 + 配对中继 | [icodesign/orbis](https://github.com/icodesign/orbis) | dsh 插件 + TestFlight App，设备配对 + E2E 加密通道 | 原生 iOS | ✅ |
| WebView 壳 + 认证代理 + 隧道 | [hongshuxifan321/dsh-mobile-app](https://github.com/hongshuxifan321/dsh-mobile-app)、[joyfish666/deepseek-harness-remote](https://github.com/joyfish666/deepseek-harness-remote) | 安卓 WebView + Basic Auth/Token + mobile-fit；Cloudflare/Tailscale 外网 | Android | ✅ |
| 原生 SwiftUI 客户端 + 加密同步中继 | [stars2022/Dsh-macUI](https://github.com/stars2022/Dsh-macUI) | iOS/macOS 原生 UI + Node 中继端到端加密 | iOS | ✅ |
| PWA + 登录网关 + 多隧道（本项目） | [rs-lxy/dsh-remote-123](https://github.com/rs-lxy/dsh-remote-123) | iPhone/iPad Safari 添加到主屏幕；零依赖网关 + PWA 注入 + gzip；花生壳/lhr/Pinggy/Cloudflare/Tailscale | iPhone/iPad/Android | ✅ |

## 二、外网通道实测结论（本项目实测）

| 通道 | 费用 | 固定地址 | 国内手机网络实测 |
|---|---|---|---|
| **Pinggy 匿名 SSH** | 免费 | ❌ 约 60 分钟换一次 | ✅ 可用（当前默认备用通道） |
| localhost.run 匿名 SSH | 免费 | ❌ 重连就换 | ⚠️ 电脑可通，部分手机线路 no tunnel here |
| Cloudflare 快速隧道 | 免费 | ❌ 重启换 | ❌ 本网络边缘过滤 404 |
| Serveo 匿名 SSH | 免费 | ❌ 重连换 | 不稳定（时通时断） |
| 花生壳免费版 | 免费 | ✅ 固定域名 | ✅ 但网页映射是试用，到期需付费 |
| NATAPP VIP_1 | 9 元/月 | ✅ 固定二级域名 | ✅（国内机房，最省心） |
| OpenFRP | 免费/付费 | 需自有域名+备案（大陆节点） | 适合有域名的用户 |
| frp 自建（frps） | 服务器费用 | ✅ | 适合有 VPS 的用户 |
| Tailscale Serve | 免费 | ✅ | 手机需装 Tailscale |
| Cloudflare named tunnel | 免费 | ✅（需域名） | 部分网络打不开 CF 控制台 |

## 三、B 站 / 社区参考

- B 站视频：[【科技补全115】一个视频看懂 DeepSeek Harness…远程控制插件分享](https://www.bilibili.com/video/BV1PZby6VE8p/)
- V2EX 讨论：[手机远程控制 DeepSeek Harness](https://global.v2ex.co/t/1235021)
- dev.to 系列（dsh-pocket 作者）：
  - [Run DeepSeek Phone Harness in Five Minutes](https://dev.to/joey020907/run-deepseek-phone-harness-in-five-minutes-control-your-computer-from-your-phone-over-4g-3388)
  - [Remote-Controlling a Desktop Agent with Zero Dependencies](https://dev.to/joey020907/remote-controlling-a-desktop-agent-with-zero-dependencies-under-the-hood-71i)

## 四、本项目怎么用这些调研结果

- **Pinggy**：已做成自动重连 watchdog + GitHub Gist 自动发布 + 固定 `/go/` 跳转入口；
- **dsh-pocket 的“二维码即入口 + URL 即钥匙”思路**：本项目用固定 `/go/` 入口 + 网关口令实现；
- **dsh-lan-gate 的“首次访问批准”思路**：本项目当前用口令登录做同等安全边界，将来可加设备批准；
- **frp / 自有域名的用户**：本项目网关可直接放在 frps/nginx 后面，见 `docs/tunnel-options.md`；
- **公网红线**：无论用哪个通道，只映射到 `127.0.0.1:8082` 网关，绝不映射 `127.0.0.1:3080` 的 dsh web。

## 五、建议

- 白嫖到底：Pinggy + `/go/`（每 60 分钟自动换地址，手机只需打开固定入口）；
- 9 元/月永久固定：NATAPP（见 `docs/natapp-guide.md`）；
- 有域名/VPS：Cloudflare named tunnel 或自建 frps。
