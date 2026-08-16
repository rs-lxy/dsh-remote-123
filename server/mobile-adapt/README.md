# dsh-mobile-adapt

让 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web GUI 在手机浏览器（视口 ≤ 767px）上自适应：

- **单列布局** — 聊天区占满全宽，三列 Grid 折叠为一列
- **全屏侧边栏抽屉** — 点击 ☰ 从左侧滑出全屏侧边栏（会话/工作区名称完整显示），图标变 ✕ 关闭
- **details 面板全屏化** — 工具调用详情从右侧全屏滑入，右上角 ✕ 关闭
- **设置界面全屏化** — 桌面居中模态改为全屏纵向布局，导航变顶部横向滚动条
- **输入栏换行** — 模型/推理等级/权限选项不再重叠，右侧组自动换到第二行
- **触控优化** — 隐藏拖拽手柄、输入框 ≥16px 防 iOS 聚焦缩放

桌面端和平板宽度（> 767px）完全不受影响。插件是纯 Client 端实现，不需要 Host 端服务。

## 安装

作为 out-of-tree 插件安装到 dsh profile：

```bash
# 1. 把插件包放入 profile 的 node_modules
mkdir -p ~/.dsh/profiles/web/node_modules/@dsh
cp -r dsh-mobile-adapt ~/.dsh/profiles/web/node_modules/@dsh/

# 2. 在 profile 的 patch 层挂载
cat >> ~/.dsh/profiles/web/cordis.patch.yml <<'YAML'
- insert:
    - id: mobile-adapt
      name: '@dsh/mobile-adapt'
YAML

# 3. 重启 dsh web
dsh web
```

安装后每次打开 GUI 自动生效（无需手动运行任何插件），刷新页面不丢失。

## 结构

```
package.json   # dsh.client 声明（platform: web + 加载顺序）
lib/index.js   # 空 host 半边（node 加载需要）
lib/client.js  # 浏览器 bundle：CSS 注入 + shell.overlay 浮动控件
```

`lib/client.js` 采用与 tsdown 产物一致的 `window.__ModuleLoader__.load({ id, factory })` 格式，
由 client-modules 服务通过 `/plugins/@dsh/mobile-adapt/client.js?rev=<hash>` 分发，
进入 boot manifest 后随页面加载。样式选择器基于稳定的 `data-slot` / `data-sidebar-collapsed`
等属性，不依赖 CSS Module 哈希类名。

## 自定义

改 `lib/client.js` 里的 `CSS` 常量即可调整断点、宽度、颜色（使用 `--dsw-*` 主题 token），
改完重启 `dsh web` 生效。

## 许可证

MIT
