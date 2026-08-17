# 免费地址为什么会变，以及稳定地址怎么选

## 一、先说结论

| 方式 | 地址 | 费用 | 会不会变 |
|---|---|---|---|
| localhost.run 匿名隧道 | `https://xxxx.lhr.life` | 免费 | **会**：电脑重启 / 网络重连 / 隧道重建都会换 |
| Cloudflare 快速隧道 | `https://xxxx.trycloudflare.com` | 免费 | **会**：每次重启都换，部分国内线路还被过滤 |
| Serveo 匿名隧道 | 随机域名 | 免费 | **会**：重连就换 |
| NATAPP VIP_1（推荐） | `https://你的名字.natapp.cn` | 9 元/月 | **不会** |
| 花生壳正式版 HTTPS 映射 | `https://xxx.vicp.fun` 等 | 付费 | **不会** |
| cpolar 基础版 | 保留二级域名 | 99 元/年 | **不会** |
| localhost.run Custom Domain | `yourdomain.lhr.rocks` | $9/月 | **不会** |
| Cloudflare named tunnel | 自有域名 | 免费（需域名） | **不会** |
| Tailscale Serve | `https://机器名.tailnet.ts.net` | 免费 | **不会**（手机需装 Tailscale） |

免费匿名服务没有固定域名绑定，断开重连就会分配新名字；这是服务商的免费策略，
任何脚本都无法让旧地址继续有效。本项目能做的补偿是：

- 隧道断了自动重连；
- 新地址自动写入 `~/.dsh/dsh-remote-url.txt`；
- 双击 `server\scripts\show-url.bat` 立即显示当前最新地址；
- 手机重新打开新地址并重新「添加到主屏幕」一次。

## 二、免费方案下，地址变了怎么办

1. 电脑上双击：`dsh-remote\server\scripts\show-url.bat`
2. 找到 `PHONE URL (localhost.run)` 那一行；
3. iPhone/iPad Safari 打开新地址 → 登录 → 分享 → 添加到主屏幕；
4. 安卓 APK 里把服务器地址改成新地址。

> 如果电脑刚重启，`show-url.bat` 可能要多等 20~40 秒让隧道重新注册，再运行一次即可。

## 三、推荐的付费稳定方案

### 1. NATAPP（最便宜，9 元/月）

- 固定二级域名 + HTTPS + 国内多线机房；
- 一条命令运行，无需域名、无需备案；
- 配置见 [docs/natapp-guide.md](natapp-guide.md)。

### 2. 花生壳正式版 HTTPS 映射

- 免费版网页映射有试用期，到期后需购买 HTTPS 映射/正式版；
- 优势是客户端图形化，适合不熟悉命令行的用户；
- 配置方法与免费版相同：HTTPS 映射 → `127.0.0.1:8082`。

### 3. cpolar 基础版（99 元/年）

- 保留二级子域名，固定不变；
- 适合按年付费、流量需求小的用户。

### 4. Cloudflare named tunnel + 自有域名（0 元，但需要域名）

- 如果你有一个域名，可把 DNS 托管到 Cloudflare，按
  [docs/tunnel-options.md](tunnel-options.md) 的“固定域名隧道”配置；
- 地址永久固定，无月费；缺点是部分网络访问 Cloudflare 控制台不稳定。

## 四、给本项目用户的建议

- 偶尔用 / 不想花钱：接受地址会变，配合 `show-url.bat` 使用；
- 每天都要用：上 NATAPP 9 元/月，一次配置永久固定，最省心。
