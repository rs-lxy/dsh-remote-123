# 安卓安装与配置教程

`dist/android/` 里已放好两个社区现成 APK，都是从 GitHub 官方 Release 下载的原始文件：

| 文件 | 来源 | 大小 |
|---|---|---|
| `dsh-mobile-app-release.apk` | [hongshuxifan321/dsh-mobile-app](https://github.com/hongshuxifan321/dsh-mobile-app) v20260814-2037 | 约 17 KB |
| `deepseek-harness-remote-release.apk` | [joyfish666/deepseek-harness-remote](https://github.com/joyfish666/deepseek-harness-remote) v0.2.0 | 约 25 KB |

两者都是“WebView 壳”：加载的就是电脑上同一个 `dsh web` 实例，与 iPhone PWA、电脑浏览器三端同步。
APK 安装要求：Android 8.0+（API 26+）。把 APK 传到手机（微信/QQ 文件传输、数据线、网盘均可）点击安装，
允许“安装未知来源应用”。

## 当前固定地址（花生壳）

```
https://你的花生壳域名
```

## 方案 A：dsh-mobile-app APK（用户名 + 密码，推荐）

1. 电脑端确认 dsh web + 网关 + 花生壳客户端在线（双击 `server\scripts\show-url.bat` 查看）；
2. 打开 App → 首次启动自动弹出设置；
3. 填写：
   - 服务器地址：`https://你的花生壳域名/mobile`（**末尾带 /mobile**）
   - 用户名：`dsh`
   - 密码：`~/.dsh/dsh-remote.auth` 里 `password=` 的值
4. 保存即连。密码经 Android Keystore 加密保存在手机本地；
5. 之后每次打开直接进入 DSH，无需再登录（网关对 `/mobile` 返回 401 挑战，App 自动携带 Basic Auth）。

## 方案 B：joyfish APK（地址 + Token）

1. 电脑端确认服务在线；
2. 打开 App → 填写：
   - 访问地址：`https://你的花生壳域名/`（**不加 /mobile**）
   - Token：`~/.dsh/dsh-remote.auth` 里 `password=` 的值（网关兼容它预置的
     `dsh_remote_config_token` cookie，不会再弹登录页）
3. 点连接。

## 两种 APK 都支持的外网通道

- **花生壳固定域名（当前使用）**：`https://你的花生壳域名`（永久固定 ✅）
- localhost.run：`https://xxxx.lhr.life`（免费随机，仅紧急备用）
- Cloudflare 固定域名：`https://mydsh.example.com`
- Tailscale：`https://你的机器.tailnet.ts.net`（手机保持 Tailscale 连接）

## 下载更新/自行构建

如果 Release 有新版本或想自己改代码：

- dsh-mobile-app：Fork 仓库 → Actions → 手动运行 `Build APK` → Summary 下载 `app-release.apk`
- joyfish：`cd apk && ./gradlew assembleDebug`（需 JDK 17+ 与 Android SDK）

## 故障排查

| 现象 | 处理 |
|---|---|
| 显示“连接失败” | 电脑上 dsh web(3080)、网关(8082)、花生壳客户端都在线？ |
| 401 反复弹窗 | 用户名/密码与 `~/.dsh/dsh-remote.auth` 不一致；改过密码要重启网关 |
| joyfish APK 出现登录页 | Token 没填或填错；填 `password=` 的值即可 |
| 页面能开但点不动 | 确认 @dsh/mobile-adapt 已挂载（左上角 ☰ 抽屉） |
