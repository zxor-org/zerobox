# device — Device Management

Manage paired devices: list, connect, disconnect, manage apps, and install resources.

All methods accept an optional `deviceId` parameter; omit to target the current active device.

## Listing & Info

### list()

```js
const devices = await ZeroBox.device.list();
// [{ id: 'D4:17:61:...', name: 'Xiaomi Smart Band 9 Pro',
//    connectType: 'spp', connected: true, current: true }, ...]
```

### info(deviceId?)

```js
const info = await ZeroBox.device.info();
// { id: 'D4:...', name: '...', model: 'M2401B1',
//   firmwareVersion: '3.1.175', battery: 85 }
```

### connect(deviceId)

```js
await ZeroBox.device.connect('D4:17:61:14:18:6E');
```

### disconnect()

```js
await ZeroBox.device.disconnect();
```

## App Management

### apps.list(deviceId?)

```js
const apps = await ZeroBox.device.apps.list();
// [{ packageName: 'com.example.app', name: 'Example',
//    versionCode: 1, canRemove: true }, ...]
```

### apps.launch(packageName, options)

```js
await ZeroBox.device.apps.launch('com.example.app', { page: '' });
```

### apps.uninstall(packageName)

```js
await ZeroBox.device.apps.uninstall('com.example.app');
```

## Install Resources

### install(path, options)

```js
// Install a quick app
await ZeroBox.device.install('/data/app.bin', {
  type: 'app', fileName: 'app.bin'
});

// Install a watchface
await ZeroBox.device.install('/data/watchface.bin', {
  type: 'watchface', fileName: 'watchface.bin'
});

// Install firmware
await ZeroBox.device.install('/data/firmware.fw', {
  type: 'firmware', fileName: 'firmware.fw'
});
```

`type` values: `app` | `watchface` | `firmware`.

## Example: Device Info Panel

```js
globalThis.activate = async (plugin) => {
  let info = 'Tap a button';
  const { Column, Text, Button } = ZeroBox.ui;

  const listDevices = async () => {
    const devices = await ZeroBox.device.list();
    info = devices.map(d =>
      `${d.name} ${d.connected ? '✓' : '✗'} ${d.current ? '←active' : ''}`
    ).join('\n');
  };

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      Button('List devices', { onClick: ZeroBox.ui.action(listDevices, render) }),
      Text(info),
    ]),
  );

  render();
};
```

## Permission

Declare `device` in the manifest. Read-only operations are medium-risk;
write operations (`connect`, `disconnect`, `install`, `apps.launch`, `apps.uninstall`)
are high-risk and authorized per device.
