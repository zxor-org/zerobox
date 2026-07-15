# ZeroBox JavaScript Host API v1

Plugin paths are restricted to `/plugin`, `/data`, `/cache`, and `/temp`.
`/plugin` is read-only. Binary values use Base64.

## Storage and files

```js
await ZeroBox.storage.get(key)
await ZeroBox.storage.set(key, jsonValue)
await ZeroBox.storage.remove(key)
await ZeroBox.storage.clear()

await ZeroBox.file.read(path, { encoding: "base64", offset: 0, length: 1024 })
await ZeroBox.file.write(path, base64, { encoding: "base64", append: false })
await ZeroBox.file.list(path)
await ZeroBox.file.stat(path)
await ZeroBox.file.mkdir(path)
await ZeroBox.file.copy(source, destination)
await ZeroBox.file.move(source, destination)
await ZeroBox.file.remove(path)
await ZeroBox.file.pick(options) // imports into /temp and returns {name,path,size}
await ZeroBox.file.unload(path, { suggestedName: "export.bin" })
```

## Network and interconnect

```js
await ZeroBox.network.fetch(url, { method: "GET", headers: {}, body: base64 })
await ZeroBox.network.download(url, "/data/model.wasm", { headers: {} })

const stop = await ZeroBox.interconnect.onMessage(({ packageName, data }) => {});
await ZeroBox.interconnect.send(packageName, data);
await stop();
```

Interconnect is raw messaging infrastructure. ZeroBox does not impose a file
transfer, chunking, or acknowledgement protocol.

## Device and protocol

```js
await ZeroBox.device.list()
await ZeroBox.device.info()
await ZeroBox.device.connect(deviceId)
await ZeroBox.device.disconnect()
await ZeroBox.device.apps.list()
await ZeroBox.device.apps.launch(packageName, { page: "" })
await ZeroBox.device.apps.uninstall(packageName)
await ZeroBox.device.install("/data/app.bin", { type: "app", fileName: "app.bin" })

const stopRaw = await ZeroBox.protocol.observe(({ data }) => {});
await ZeroBox.protocol.send(base64Payload);
await stopRaw();
```

Raw observation is read-only and does not replace the normal protocol
dispatcher. Raw sending is high-risk because it can interfere with active
device operations.

## Provider

```js
await ZeroBox.provider.register({
  id: "org.example.source",
  name: "Example Source",
  categories: async () => [{ id: "watch", name: "Watch" }],
  query: async (query) => ({ items: [], hasMore: false, total: 0 }),
  detail: async ({ id }) => ({
    id, name: id, type: "quickApp", paidType: "free",
    authors: [], supportedDevices: [], files: [],
    content: { format: "plainText", value: "" }
  }),
  download: async ({ id, fileId, targetDevice }) => ({
    path: "/cache/download.bin", fileName: "download.bin"
  })
});
```

Resource types are `quickApp`, `watchface`, `firmware`, `fontpack`, and
`iconpack`. Downloads must return a path in the provider plugin's sandbox.

## UI and Hybrid WASM

```js
await ZeroBox.ui.update(nodes)
await ZeroBox.ui.openPage(nodes)
await ZeroBox.ui.openExternal(url)
const callbackId = ZeroBox.ui.callback(async (value) => {})

const module = await ZeroBox.wasm.load("/plugin/model.wasm", { wasi: true });
await module.call("run", 1, 2);
await module.dispose();
```

UI nodes use `node_id`, `visibility`, `disabled`, and `content: {type,value}`.
Supported types are `Text`, `HtmlDocument`, `Button`, `Input`, and `Dropdown`.
