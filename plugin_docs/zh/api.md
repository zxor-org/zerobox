# ZeroBox JavaScript Host API v1

所有路径必须位于插件自己的 `/plugin`、`/data`、`/cache` 或 `/temp`。
`/plugin` 只读；其余目录可写。二进制参数和返回值使用 Base64。

## storage

```js
await ZeroBox.storage.get(key)
await ZeroBox.storage.set(key, jsonValue)
await ZeroBox.storage.remove(key)
await ZeroBox.storage.clear()
```

## file

```js
await ZeroBox.file.read(path, { encoding: "base64", offset: 0, length: 1024 })
await ZeroBox.file.write(path, base64, { encoding: "base64", append: false })
await ZeroBox.file.list(path)
await ZeroBox.file.stat(path)
await ZeroBox.file.mkdir(path)
await ZeroBox.file.copy(source, destination)
await ZeroBox.file.move(source, destination)
await ZeroBox.file.remove(path)
await ZeroBox.file.pick(options)
await ZeroBox.file.unload(path, { suggestedName: "export.bin" })
```

`pick` 将宿主文件导入 `/temp/picker/...`，返回 `{name, path, size}`。
`unload` 将沙箱文件导出到宿主原生环境。

## network

```js
const response = await ZeroBox.network.fetch(url, {
  method: "GET",
  headers: {},
  body: base64
});
await ZeroBox.network.download(url, "/data/model.wasm", {
  method: "GET",
  headers: {},
  append: false
});
```

`fetch` 返回 `{status, headers, contentType, body}`，其中 `body` 是 Base64。
`download` 直接流式写入沙箱，返回 `{path, bytesWritten, status}`。

## interconnect

```js
const stop = await ZeroBox.interconnect.onMessage(({ packageName, data }) => {});
await ZeroBox.interconnect.send(packageName, data);
await stop();
```

Host 只提供可靠的原始消息基础设施，不规定文件切片、确认或业务协议。

## device

```js
await ZeroBox.device.list()
await ZeroBox.device.info()
await ZeroBox.device.connect(deviceId)
await ZeroBox.device.disconnect()
await ZeroBox.device.apps.list()
await ZeroBox.device.apps.launch(packageName, { page: "" })
await ZeroBox.device.apps.uninstall(packageName)
await ZeroBox.device.install("/data/app.bin", {
  type: "app", // app | watchface | firmware
  fileName: "app.bin"
})
```

## protocol

```js
const stop = await ZeroBox.protocol.observe(({ data }) => {
  // data is Base64; observation does not replace the normal dispatcher.
});
await ZeroBox.protocol.send(base64Payload);
await stop();
```

原始观察是旁路，只读且不暂停正常协议。原始发送可能影响正在执行的设备业务，
因此每个目标都按高风险操作授权。

## provider

```js
await ZeroBox.provider.register({
  id: "org.example.source",
  name: "Example Source",
  categories: async () => [{ id: "watch", name: "手表" }],
  query: async (query) => ({ items: [], hasMore: false, total: 0 }),
  detail: async ({ id }) => ({
    id, name: id, type: "quickApp", paidType: "free",
    authors: [], supportedDevices: [], files: [],
    content: { format: "plainText", value: "" }
  }),
  download: async ({ id, fileId, targetDevice }) => ({
    path: "/cache/download.bin",
    fileName: "download.bin"
  })
});
```

资源类型为 `quickApp`、`watchface`、`firmware`、`fontpack` 或 `iconpack`。
provider 下载结果必须是本插件沙箱中的文件。

## ui

```js
await ZeroBox.ui.update(nodes)
await ZeroBox.ui.openPage(nodes)
await ZeroBox.ui.openExternal(url)
const callbackId = ZeroBox.ui.callback(async (value) => {})
```

当前节点格式使用 `node_id`、`visibility`、`disabled` 和
`content: {type, value}`。支持 `Text`、`HtmlDocument`、`Button`、`Input`、
`Dropdown`；交互节点通过 `callback_fun_id` 绑定回调。

## Hybrid WASM

```js
const module = await ZeroBox.wasm.load("/plugin/model.wasm", { wasi: true });
const result = await module.call("run", 1, 2);
await module.writeMemory(0, base64);
const bytes = await module.readMemory(0, 64);
await module.dispose();
```
