# ZeroBox Plugin System v1

ZeroBox plugins use the `.zbp` extension. A package is a ZIP archive with a
root `manifest.json` and may use the JavaScript, WASM, or Hybrid runtime.

```json
{
  "id": "org.example.ebook-sync",
  "name": "E-book Sync",
  "version": "1.0.0",
  "author": "Example Developer",
  "description": "Synchronizes e-books to a device",
  "api_level": 1,
  "runtime": "hybrid",
  "entry": "main.js",
  "permissions": ["ui", "file", "network", "interconnect", "provider", "device", "protocol"],
  "website": "https://example.org",
  "icon": "assets/icon.png"
}
```

`runtime` is `js`, `wasm`, or `hybrid`. `entry` is independent from it. A
Hybrid plugin has a JavaScript entry and loads its own WASM modules at runtime.
`api_level` is currently `1`. Permissions are coarse capabilities; undeclared
capabilities cannot be used.

Medium- and high-risk calls block and ask the user to allow once, allow for the
current runtime session, always allow, or deny. Persistent grants are removed
when the plugin is uninstalled.

JavaScript defines `globalThis.activate = async (plugin) => {}` and accesses
the Host API through `ZeroBox`. See [api.md](api.md), [wasm.md](wasm.md), and
[legacy.md](legacy.md).
