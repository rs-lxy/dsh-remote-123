# NATAPP 固定 HTTPS 域名配置（9 元/月，推荐）

> 适合每天都要远程使用、不想再折腾地址的用户。
> NATAPP VIP_1：固定二级域名 + HTTPS + 国内机房，9 元/月。

## 1. 注册并购买

1. 打开 https://natapp.cn/ ，注册账号（手机号）；
2. 登录控制台，购买一条 **VIP_1 型隧道**（9 元/月）；
3. 在「我的隧道」里为新隧道**绑定二级域名**，例如 `mydsh`；
   - 最终手机地址就是 `https://mydsh.natapp.cn`；
4. 复制隧道的 **authtoken**（重要，不要外传）。

## 2. 下载客户端

1. 打开 https://natapp.cn/download ，下载 Windows 64 位客户端；
2. 解压得到 `natapp.exe`，放到：
   `dsh-remote-123\tools\bin\natapp.exe`

## 3. 运行隧道（把 443 转发到本机网关）

在 `dsh-remote-123` 目录打开终端：

```powershell
tools\bin\natapp.exe -authtoken=你的authtoken
```

看到 `Tunnel Status: online` 即成功。保持窗口开着；电脑重启后重新运行一次。

## 4. 手机端

- iPhone / iPad：Safari 打开 `https://mydsh.natapp.cn` → 登录 → 添加到主屏幕（永久固定）；
- 安卓 APK：地址填 `https://mydsh.natapp.cn/mobile`。

## 5. 开机自启（可选）

把下面的快捷方式放入 `shell:startup` 启动文件夹：

```powershell
# 快捷方式目标
D:\dsh-remote-123\tools\bin\natapp.exe -authtoken=你的authtoken
```

或创建计划任务：

```powershell
schtasks /create /tn dsh-natapp /tr "D:\dsh-remote-123\tools\bin\natapp.exe -authtoken=你的authtoken" /sc onlogon
```

## 安全提醒

- NATAPP 隧道把公网 443 转发到**本机 127.0.0.1:8082**（登录网关），
  **不要**配置成本机 3080（dsh web），更不要改网关监听地址为 0.0.0.0；
- authtoken 等同隧道控制权，不要提交到公开仓库。
