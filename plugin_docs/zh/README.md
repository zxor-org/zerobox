# ZeroBox 插件系统 v1

ZeroBox 插件使用 `.zbp` 扩展名。文件本身是 ZIP，根目录必须包含
`manifest.json`。插件可选择 JavaScript、WASM 或 Hybrid 运行时。

## Manifest

```json
{
  "id": "org.example.ebook-sync",
  "name": "电子书同步",
  "version": "1.0.0",
  "author": "Example Developer",
  "description": "同步电子书到设备",
  "api_level": 1,
  "runtime": "hybrid",
  "entry": "main.js",
  "permissions": [
    "ui",
    "file",
    "network",
    "interconnect",
    "provider",
    "device",
    "protocol"
  ],
  "website": "https://example.org",
  "icon": "assets/icon.png"
}
```

- `id`：稳定的反向域名标识，只允许小写字母、数字、点和连字符。
- `version`：插件自身版本。
- `api_level`：当前固定为 `1`。
- `runtime`：`js`、`wasm` 或 `hybrid`。
- `entry`：独立入口。Hybrid 插件的入口是 JavaScript，WASM 模块由插件按需加载。
- `permissions`：粗粒度能力声明。未声明的能力无法调用。

## 权限

`file` 沙箱读写和 `ui` 渲染属于低风险：Host 校验 manifest 后直接执行。
文件选择/导出、联网、interconnect、provider 和设备只读操作属于中风险。
连接、安装、卸载、启动应用和发送原始协议数据属于高风险。

中高风险操作会阻断调用并显示授权对话框：允许本次、本次运行中允许、
始终允许或拒绝。始终允许按具体操作和目标保存；卸载插件时一并删除。

## 运行时

JavaScript 入口导出或定义全局 `activate(plugin)`：

```js
globalThis.activate = async (plugin) => {
  console.info(`Starting ${plugin.id} ${plugin.version}`);
};
```

`PLUGIN` 包含 `id`、`name`、`version` 和 `runtimeVersion`。Host API 位于全局
`ZeroBox`。Hybrid 与 JavaScript 使用相同入口，额外通过 `ZeroBox.wasm.load()`
加载 `/plugin`、`/data` 或网络下载到沙箱中的 WASM。

纯 WASM 插件使用独立 ABI，见 [wasm.md](wasm.md)。完整 JS API 见
[api.md](api.md)。ABv1 兼容边界见 [legacy.md](legacy.md)。
