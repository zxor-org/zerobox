# ABv1 Compatibility Mode

ZeroBox is compatible with AstroBox v1 (ABv1) plugin packages. ABv1 plugins use
the `.abp` extension and run through a built-in adapter that translates the legacy
`AstroBox.*` API into current `ZeroBox.*` host calls.

## Detection

ABv1 plugins do not declare a `runtime` field in `manifest.json`. ZeroBox
automatically treats them as `runtime: legacy`. The plugin ID is auto-generated
from the SHA256 hash of the plugin name (first 12 hex chars) — no explicit `id`
is needed.

```json
{
  "name": "testplugin",
  "icon": "icon.png",
  "version": "1.0",
  "description": "Test plugin",
  "author": "test",
  "entry": "main.js",
  "permissions": ["lifecycle", "native", "ui"]
}
```

## Entry Point

ABv1 plugins use `lifecycle.onLoad` instead of `activate()`:

```js
AstroBox.lifecycle.onLoad(async () => {
  console.info('ABv1 plugin started');
});
```

Runtime globals:
- `RUNTIME` — always `"AstroBox"`
- `RUNTIME_VERSION` — ZeroBox version
- `PLUGIN_NAME` — plugin name
- `PLUGIN_PATH` — `"zerobox-plugin://<id>"`
- `PLUGIN_VERSION` — plugin version

## API Mapping

The adapter injects an `AstroBox` global object in JS that translates calls:

| ABv1 API | ZeroBox API | Notes |
|----------|-------------|-------|
| `AstroBox.config.readConfig()` | `ZeroBox.storage.get('__astrobox_config')` | JSON round-trip |
| `AstroBox.config.writeConfig(json)` | `ZeroBox.storage.set('__astrobox_config', ...)` | |
| `AstroBox.filesystem.pickFile(opts)` | `ZeroBox.file.pick(opts)` | Returns `{path, size, text_len}` |
| `AstroBox.filesystem.readFile(path, opts)` | `ZeroBox.file.read(path, opts)` | Text/Binary support |
| `AstroBox.filesystem.unloadFile(path)` | `ZeroBox.file.remove(path)` | Delete temp file |
| `AstroBox.network.fetch(url, opts)` | `ZeroBox.network.fetch(url, opts)` | Direct pass-through |
| `AstroBox.interconnect.sendQAICMessage(pkg, data)` | `ZeroBox.interconnect.send(pkg, data)` | |
| `AstroBox.event.addEventListener('onQAICMessage_<pkg>', fn)` | `ZeroBox.interconnect.onMessage(...)` | Auto subscribe/unsubscribe |
| `AstroBox.installer.addThirdPartyAppToQueue(path)` | `ZeroBox.device.install(path, {type:'app'})` | |
| `AstroBox.installer.addWatchFaceToQueue(path)` | `ZeroBox.device.install(path, {type:'watchface'})` | |
| `AstroBox.installer.addFirmwareToQueue(path)` | `ZeroBox.device.install(path, {type:'firmware'})` | |
| `AstroBox.thirdpartyapp.getThirdPartyAppList()` | `ZeroBox.device.apps.list()` | Field name conversion |
| `AstroBox.thirdpartyapp.launchQA(app, page)` | `ZeroBox.device.apps.launch(pkg, {page})` | |
| `AstroBox.device.getDeviceList()` | `ZeroBox.device.list()` | |
| `AstroBox.device.getDeviceState(addr)` | `ZeroBox.device.list()` + lookup | Mock legacy fields |
| `AstroBox.device.disconnectDevice()` | `ZeroBox.device.disconnect()` | |
| `AstroBox.debug.sendRaw(data)` | `ZeroBox.protocol.send(data)` | |
| `AstroBox.ui.updatePluginSettingsUI(nodes)` | `ZeroBox.ui.update(nodes)` | Direct pass-through |
| `AstroBox.ui.openPageWithNodes(nodes)` | `ZeroBox.ui.openPage(nodes)` | Direct pass-through |
| `AstroBox.ui.openPageWithUrl(url)` | `ZeroBox.ui.openExternal(url)` | Direct pass-through |
| `AstroBox.native.regNativeFun(fn)` | `ZeroBox.ui.callback(fn)` | Returns callback ID |

## Path Remapping

ABv1 plugins use `/package/` and `/tmp/` prefixes. The adapter remaps them:

| ABv1 path | ZeroBox path |
|-----------|-------------|
| `/package/` | `/plugin/` |
| `/tmp/` | `/temp/` |

## Unsupported Features

These ABv1 APIs throw errors in ZeroBox:

- `AstroBox.device.modifyDeviceState()` — device state is read-only in ZeroBox
- `AstroBox.provider.registerCommunityProvider()` — use native `ZeroBox.provider.register()`
  instead, but ABv1 plugins cannot access the native API

## Permissions

ABv1 manifest may declare legacy permission names (e.g. `lifecycle`, `native`). ZeroBox
ignores unknown names during validation. At runtime, the adapter calls the corresponding
`ZeroBox.*` host methods, which go through the native permission system. For example,
`AstroBox.interconnect.sendQAICMessage` triggers the `interconnect:send` medium-risk
authorization dialog.

## Migration Guide

Dual-compatibility pattern:

```js
if (typeof RUNTIME === 'string' && RUNTIME === 'AstroBox') {
  AstroBox.lifecycle.onLoad(async () => { /* ABv1 API */ });
} else if (typeof ZeroBox !== 'undefined') {
  globalThis.activate = async (plugin) => { /* ZeroBox API */ };
}
```

Prefer native ZeroBox format (`.zbp` + `runtime: "js"` + `ZeroBox.*` API) for full
feature access and better performance.
