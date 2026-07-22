# ABv1 兼容模式

ZeroBox 兼容 AstroBox v1（ABv1）插件格式。ABv1 插件使用 `.abp` 扩展名，通过内置
适配层将旧版 `AstroBox.*` API 翻译为当前的 `ZeroBox.*` Host API。

## 识别方式

ABv1 插件的 `manifest.json` 不声明 `runtime` 字段（或声明为不存在的值），
ZeroBox 自动将其识别为 `runtime: legacy`。插件 ID 由名称的 SHA256 前 12 位自动生成，
无需 manifest 中显式声明 `id`。

```json
{
  "name": "testplugin",
  "icon": "icon.png",
  "version": "1.0",
  "description": "测试插件",
  "author": "test",
  "entry": "main.js",
  "permissions": ["lifecycle", "native", "ui"]
}
```

## 入口方式

ABv1 插件使用 `lifecycle.onLoad` 注册启动回调，而非 `activate()`：

```js
AstroBox.lifecycle.onLoad(async () => {
  console.info('ABv1 plugin started');
});
```

运行时环境通过全局变量暴露：
- `RUNTIME` — 固定为 `"AstroBox"`
- `RUNTIME_VERSION` — ZeroBox 版本号
- `PLUGIN_NAME` — 插件名称
- `PLUGIN_PATH` — `"zerobox-plugin://<id>"`
- `PLUGIN_VERSION` — 插件版本

## API 映射表

适配层在 JS 侧注入 `AstroBox` 全局对象，将调用翻译为 `ZeroBox.*` host call：

| ABv1 API | 对应 ZeroBox API | 说明 |
|----------|-----------------|------|
| `AstroBox.config.readConfig()` | `ZeroBox.storage.get('__astrobox_config')` | JSON 字符串往返 |
| `AstroBox.config.writeConfig(json)` | `ZeroBox.storage.set('__astrobox_config', ...)` | |
| `AstroBox.filesystem.pickFile(opts)` | `ZeroBox.file.pick(opts)` | 返回 `{path, size, text_len}` |
| `AstroBox.filesystem.readFile(path, opts)` | `ZeroBox.file.read(path, opts)` | 支持 Text/Binary |
| `AstroBox.filesystem.unloadFile(path)` | `ZeroBox.file.remove(path)` | 删除临时文件 |
| `AstroBox.network.fetch(url, opts)` | `ZeroBox.network.fetch(url, opts)` | 直接透传 |
| `AstroBox.interconnect.sendQAICMessage(pkg, data)` | `ZeroBox.interconnect.send(pkg, data)` | |
| `AstroBox.event.addEventListener('onQAICMessage_<pkg>', fn)` | `ZeroBox.interconnect.onMessage(...)` | 自动订阅/退订 |
| `AstroBox.installer.addThirdPartyAppToQueue(path)` | `ZeroBox.device.install(path, {type:'app'})` | |
| `AstroBox.installer.addWatchFaceToQueue(path)` | `ZeroBox.device.install(path, {type:'watchface'})` | |
| `AstroBox.installer.addFirmwareToQueue(path)` | `ZeroBox.device.install(path, {type:'firmware'})` | |
| `AstroBox.thirdpartyapp.getThirdPartyAppList()` | `ZeroBox.device.apps.list()` | 字段名转换 |
| `AstroBox.thirdpartyapp.launchQA(app, page)` | `ZeroBox.device.apps.launch(pkg, {page})` | |
| `AstroBox.device.getDeviceList()` | `ZeroBox.device.list()` | |
| `AstroBox.device.getDeviceState(addr)` | `ZeroBox.device.list()` + 查找 | 模拟旧字段结构 |
| `AstroBox.device.disconnectDevice()` | `ZeroBox.device.disconnect()` | |
| `AstroBox.debug.sendRaw(data)` | `ZeroBox.protocol.send(data)` | |
| `AstroBox.ui.updatePluginSettingsUI(nodes)` | `ZeroBox.ui.update(nodes)` | 直接透传 |
| `AstroBox.ui.openPageWithNodes(nodes)` | `ZeroBox.ui.openPage(nodes)` | 直接透传 |
| `AstroBox.ui.openPageWithUrl(url)` | `ZeroBox.ui.openExternal(url)` | 直接透传 |
| `AstroBox.native.regNativeFun(fn)` | `ZeroBox.ui.callback(fn)` | 返回回调 ID |

## 路径重映射

ABv1 插件使用 `/package/` 和 `/tmp/` 前缀，适配层自动映射到 ZeroBox 沙箱路径：

| ABv1 路径 | ZeroBox 路径 |
|-----------|-------------|
| `/package/` | `/plugin/` |
| `/tmp/` | `/temp/` |

## 不支持的功能

以下 ABv1 API 在 ZeroBox 中不可用，调用会抛出错误：

- `AstroBox.device.modifyDeviceState()` — 不支持，ZeroBox 的设备状态只读
- `AstroBox.provider.registerCommunityProvider()` — 不支持，需用原生 `ZeroBox.provider.register()` 替代（但 ABv1 插件无法调用原生 API）

## 权限

ABv1 插件 manifest 中可能声明旧版权限（如 `lifecycle`、`native`），ZeroBox 在解析时忽略
不认识的权限名，只校验是否在已知集合内。实际运行时，适配层调用对应的 `ZeroBox.*` API，
权限校验走原生权限系统。例如 `AstroBox.interconnect.sendQAICMessage` 会触发
`interconnect:send` 的中等风险授权对话框。

## 封装建议

如需同时兼容 ZeroBox 原生和 ABv1 环境，可以在入口判断 `RUNTIME` 全局变量：

```js
if (typeof RUNTIME === 'string' && RUNTIME === 'AstroBox') {
  // ABv1 环境
  AstroBox.lifecycle.onLoad(async () => {
    // 使用 AstroBox.* API
  });
} else if (typeof ZeroBox !== 'undefined') {
  // ZeroBox 原生环境
  globalThis.activate = async (plugin) => {
    // 使用 ZeroBox.* API
  };
}
```

但建议直接使用 ZeroBox 原生格式（`.zbp` + `runtime: "js"` + `ZeroBox.*` API），
以获得完整功能和更好的性能。
