# ZeroBox 插件系统

ZeroBox 插件是一个 `.zbp` 文件，本质是 ZIP 压缩包。根目录必须包含 `manifest.json`
和入口脚本。插件运行在沙箱化的 QuickJS 环境中，通过全局 `ZeroBox` 对象访问宿主能力。

## 快速开始：Hello World

创建一个计数器插件——点击按钮累加次数，显示当前计数。

### 1. 创建 manifest.json

```json
{
  "id": "com.example.counter",
  "name": "计数器",
  "version": "1.0.0",
  "author": "你的名字",
  "description": "一个简单的计数器插件",
  "api_level": 1,
  "runtime": "js",
  "entry": "main.js",
  "permissions": ["ui"],
  "icon": "icon.png"
}
```

| 字段 | 说明 |
|------|------|
| `id` | 唯一标识，反向域名格式：`[a-z][a-z0-9]*([.-][a-z0-9]+)+` |
| `name` | 插件显示名称 |
| `version` | 语义化版本号 |
| `runtime` | `js` / `wasm` / `hybrid` |
| `entry` | 入口文件名，默认 `main.js` |
| `permissions` | 能力声明：`ui` `file` `network` `interconnect` `provider` `device` `protocol` `appside` |
| `icon` | 可选，PNG 图标路径 |

### 2. 创建 main.js

```js
// ZeroBox 加载插件后自动调用 activate
globalThis.activate = async (plugin) => {
  let count = 0;

  const { Column, Text, Button } = ZeroBox.ui;
  const render = () => ZeroBox.ui.render(
    Column({ gap: 12, padding: 16 }, [
      Text(`计数器: ${count}`),
      Button('点我 +1', {
        onClick: ZeroBox.ui.action(() => count++, render),
      }),
    ]),
  );

  await render();
};
```

关键点：
- 入口是全局函数 `activate(plugin)`，`plugin` 包含 `{id, name, version, runtimeVersion}`
- UI 通过 `ZeroBox.ui.render(tree)` 渲染组件树
- 组件事件直接接收函数；异步状态操作使用 `ZeroBox.ui.action(fn, render)`
- `render()` 应返回 `ZeroBox.ui.render()` 的 Promise

### 3. 准备图标

将一张 PNG 图片命名为 `icon.png` 放在同一目录。

### 4. 打包

将 `manifest.json`、`main.js`、`icon.png` 打包成 ZIP（扩展名 `.zbp`）：

```bash
zip counter.zbp manifest.json main.js icon.png
```

### 5. 安装

在 ZeroBox 插件页点击「导入插件」，选择 `counter.zbp` 即可。

## Plugin UI

原生插件使用 `Column`、`Row`、`Text`、`Button`、`TextField`、`Image` 等组件工厂构建 UI 树。完整组件和属性见 [ui.md](ui.md)。AstroBox v1 插件兼容范围另见 [legacy.md](legacy.md)。

## API 文档

| 命名空间 | 文档 | 说明 |
|---------|------|------|
| storage | [storage.md](storage.md) | 键值持久化存储 |
| file | [file.md](file.md) | 沙箱文件系统 |
| network | [network.md](network.md) | HTTP 请求 |
| device | [device.md](device.md) | 设备管理与安装 |
| watchface | [watchface.md](watchface.md) | 表盘管理 |
| interconnect | [interconnect.md](interconnect.md) | 跨插件消息 |
| protocol | [protocol.md](protocol.md) | 原始设备协议 |
| provider | [provider.md](provider.md) | 资源提供者 |
| os | [os.md](os.md) | 宿主环境信息 |
| ui | [ui.md](ui.md) | 插件界面渲染 |
| appside | [appside.md](appside.md) | Zepp OS AppSide 管理 |
| — | [legacy.md](legacy.md) | ABv1 兼容模式说明 |
