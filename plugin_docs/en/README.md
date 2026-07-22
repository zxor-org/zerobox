# ZeroBox Plugin System

A ZeroBox plugin is a `.zbp` file — a ZIP archive with a root `manifest.json` and
an entry script. Plugins run in a sandboxed QuickJS environment and access host
capabilities through the global `ZeroBox` object.

## Quick Start: Hello World

Build a click-counter plugin — tap a button to increment and display the count.

### 1. Create manifest.json

```json
{
  "id": "com.example.counter",
  "name": "Counter",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "A simple counter plugin",
  "api_level": 1,
  "runtime": "js",
  "entry": "main.js",
  "permissions": ["ui"],
  "icon": "icon.png"
}
```

| Field | Description |
|-------|-------------|
| `id` | Unique reverse-domain identifier: `[a-z][a-z0-9]*([.-][a-z0-9]+)+` |
| `name` | Display name |
| `version` | Semantic version |
| `runtime` | `js` / `wasm` / `hybrid` |
| `entry` | Entry file name, defaults to `main.js` |
| `permissions` | Capability declarations: `ui` `file` `network` `interconnect` `provider` `device` `protocol` `appside` |
| `icon` | Optional PNG icon path |

### 2. Create main.js

```js
// ZeroBox calls activate automatically after loading the plugin
globalThis.activate = async (plugin) => {
  let count = 0;

  const { Column, Text, Button } = ZeroBox.ui;
  const render = () => ZeroBox.ui.render(
    Column({ gap: 12, padding: 16 }, [
      Text(`Count: ${count}`),
      Button('+1', {
        onClick: ZeroBox.ui.action(() => count++, render),
      }),
    ]),
  );

  await render();
};
```

Key points:
- The entry point is the global function `activate(plugin)` where `plugin` is `{id, name, version, runtimeVersion}`
- Render component trees with `ZeroBox.ui.render(tree)`
- Component events accept functions directly; use `ZeroBox.ui.action(fn, render)` for asynchronous state changes
- `render()` should return the Promise from `ZeroBox.ui.render()`

### 3. Prepare an icon

Place a PNG file named `icon.png` in the same directory.

### 4. Package

Zip the files with the `.zbp` extension:

```bash
zip counter.zbp manifest.json main.js icon.png
```

### 5. Install

In ZeroBox, go to the Plugins tab and tap "Import plugin", then select `counter.zbp`.

## Plugin UI

Native plugins build UI trees with component factories such as `Column`, `Row`, `Text`, `Button`, `TextField`, and `Image`. See [ui.md](ui.md) for the complete component and property reference. See [legacy.md](legacy.md) separately for the AstroBox v1 compatibility scope.

## API Reference

| Namespace | Document | Description |
|-----------|----------|-------------|
| storage | [storage.md](storage.md) | Key-value persistent storage |
| file | [file.md](file.md) | Sandboxed file system |
| network | [network.md](network.md) | HTTP requests |
| device | [device.md](device.md) | Device management & installation |
| watchface | [watchface.md](watchface.md) | Watchface management |
| interconnect | [interconnect.md](interconnect.md) | Cross-plugin messaging |
| protocol | [protocol.md](protocol.md) | Raw device protocol |
| provider | [provider.md](provider.md) | Resource provider |
| os | [os.md](os.md) | Host environment info |
| ui | [ui.md](ui.md) | Plugin UI rendering |
| appside | [appside.md](appside.md) | Zepp OS AppSide management |
| — | [legacy.md](legacy.md) | ABv1 compatibility mode |
