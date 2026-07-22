# appside — Zepp OS AppSide Management

Manage AppSide sessions on Zepp OS devices. AppSide is a remote JS execution
channel (Bluetooth endpoint `0x00a0`) that runs alongside watch mini-apps,
communicating with them in real time via `messaging.peerSocket`.

`appId` is a 32-bit unsigned integer (Zepp OS app ID).

## Methods

### list()

```js
const ids = await ZeroBox.appside.list();
// [0x0010ee3b, 0x00001234, ...]
```

### start(appId)

Start the local AppSide QuickJS runtime (requires a cached script).

```js
await ZeroBox.appside.start(0x0010ee3b);
```

### stop(appId)

```js
await ZeroBox.appside.stop(0x0010ee3b);
```

### send(appId, hexData)

Send hex-encoded binary data to the watch (requires an active watch session).

```js
await ZeroBox.appside.send(0x0010ee3b, '0100ff');
```

### inject(appId, hexData)

Simulate a watch-to-host message, injecting into the local runtime (debugging — no watch session needed).

```js
await ZeroBox.appside.inject(0x0010ee3b, '48656c6c6f');
// "Hello" in hex → runtime's peerSocket.onmessage receives it
```

### sessions()

List all active sessions.

```js
const sessions = await ZeroBox.appside.sessions();
// [{ appId: 0x0010ee3b, version: 1, port1: 20, port2: 1004,
//    extra: 0, watchSessionOpen: true }, ...]
```

### events(appId)

Read debug event logs for an appId.

```js
const events = await ZeroBox.appside.events(0x0010ee3b);
// [{ timestamp: '2024-...', type: 'start', message: 'Script loaded (1234 chars)' }, ...]
```

### clearEvents(appId)

```js
await ZeroBox.appside.clearEvents(0x0010ee3b);
```

## Example: AppSide Manager

```js
globalThis.activate = async (plugin) => {
  let ids = [];
  let result = '';
  const { Column, Text, Button } = ZeroBox.ui;

  const render = () => {
    const nodes = [
      Button('Refresh', {
        onClick: ZeroBox.ui.action(async () => {
          ids = await ZeroBox.appside.list();
          result = `${ids.length} scripts cached: ${ids.map(i => '0x'+i.toString(16)).join(', ')}`;
        }, render),
      }),
      Text(result),
    ];

    for (const id of ids) {
      const hex = '0x' + id.toString(16);
      nodes.push(Button(`Start ${hex}`, {
        onClick: ZeroBox.ui.action(async () => {
          try { await ZeroBox.appside.start(id); result = `${hex} started`; }
          catch (e) { result = `Error: ${e.message}`; }
        }, render),
      }));
    }
    return ZeroBox.ui.render(Column({ gap: 8 }, nodes));
  };

  render();
};
```

## Permission

Declare `appside`. Read-only operations (`list`, `sessions`, `events`) are medium-risk;
control operations (`start`, `stop`, `send`, `inject`, `clearEvents`) are high-risk.
