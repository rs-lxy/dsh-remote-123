# iPhone PWA 安装教程（无需签名，今天就能用）

DeepSeek Harness 官方没有 iOS 客户端。本项目把电脑上的 dsh 网页通过「登录网关」代理出来，
并注入 PWA 所需的 manifest / 图标 / Service Worker / 全屏 meta，因此 **iPhone Safari
「添加到主屏幕」之后就是独立全屏 App**：有自己的图标、独立任务卡、WebSocket 审批推送正常，
且不需要开发者账号、TestFlight 或 7 天重签。

> 原理说明：PWA 的页面就是电脑上正在运行的 `dsh web` 实例（经网关同源代理），
> 所以手机上看到/操作的会话与电脑端完全同步。

## 第一步：确认电脑端在运行

- dsh web（127.0.0.1:3080）和 dsh-remote 网关（127.0.0.1:8082）应已自启；
- 花生壳客户端应已登录并显示映射 `https://你的花生壳域名`；
- 查地址/口令：双击 `dsh-remote\server\scripts\show-url.bat`。

当前**固定 PHONE URL**：

```
https://你的花生壳域名
```

口令见 `~/.dsh\dsh-remote.auth` 的 `password=` 一行。

## 第二步：iPhone 上登录

1. 打开 **Safari**（必须 Safari，其他浏览器添加到主屏幕没有独立 App 体验）；
2. 输入 `PHONE URL`；
3. 出现登录页，输入口令，点「登录并进入」；
4. 看到 DeepSeek Harness 界面即成功。此时底部会提示「添加到主屏幕」。

## 第三步：添加到主屏幕

1. 点 Safari 底部**分享按钮**（方框↑箭头）；
2. 滑动菜单，点**「添加到主屏幕」**（Add to Home Screen）；
3. 名字可改成 `DSH`，点右上角**添加**；
4. 桌面出现蓝色 DSH 图标。以后点图标 → 全屏独立 App → 直接操作 dsh。

> 首次登录的 cookie 有效期 1 年，基本登录一次；换口令后重新登录一次即可。

## 日常使用

| 操作 | 说明 |
|---|---|
| 发消息 | 会话底部输入框；移动端适配生效后回车是换行、右下角箭头发送 |
| 会话列表 | 左上角 ☰ 全屏抽屉（@dsh/mobile-adapt 已生效） |
| 审批/提问弹窗 | WebSocket 实时推送，正常弹出可选 |
| 上传文件 | 走 iOS 系统文件选择器 |
| 修改模型/API Key/权限 | 网关注入 + Host 回环改写后，手机端设置面板可用 |
| 断开后重连 | App 内下拉刷新或重开 App；断网时显示离线页 |

## 固定桌面图标地址（已解决）

当前使用花生壳固定域名 `https://你的花生壳域名`，添加到主屏幕后**永久有效**，
无需再更换地址。备用通道（免费随机 localhost.run / Cloudflare 快速隧道）才会在
重连后换地址，日常不用。

## 已验证的 iOS 兼容点

- `apple-mobile-web-app-capable` + 独立图标 + 全屏启动；
- `viewport-fit=cover` + 安全区适配（刘海/底部手势条）；
- 输入框字体 16px，避免聚焦自动放大；
- `apple-touch-icon`（180px）与 manifest 图标（192/512）；
- 最小 Service Worker：断网退回离线提示页，不缓存 API 流（不影响实时性）；
- WebSocket 事件流走同源 HTTPS，无需特殊配置。

## 常见问题

| 现象 | 处理 |
|---|---|
| Safari 打开提示“打不开网页” | 电脑开机、dsh web 运行、网关运行、隧道运行（看 `start-remote.ps1` 输出） |
| 登录页提示口令不正确 | 核对 `~/.dsh/dsh-remote.auth` 的 `password=`；改过文件要重启网关 |
| 添加到主屏幕后是网页样式 | 确认是从登录后的 dsh 页面添加；旧 iOS（<16.4）靠 apple-touch-icon meta，同样支持 |
| 切后台回来要重新登录 | cookie 1 年有效，一般不会；如反复出现请反馈 |
| 手机端布局怪 | 重启一次 dsh web（mobile-fit 已挂载），左上角出现 ☰ 即正常 |
| 隧道地址换了 | 重新打开新地址 → 重新添加到主屏幕；或改用固定域名方案 |
