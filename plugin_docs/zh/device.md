# device — 设备管理

管理已配对设备，查看/连接/断开、管理应用、安装资源到设备。

所有方法支持可选的 `deviceId` 参数，不传则操作当前活动设备。

## 设备列表与信息

### list()

```js
const devices = await ZeroBox.device.list();
// [{ id: 'D4:17:61:14:18:6E', name: 'Xiaomi Smart Band 9 Pro',
//    connectType: 'spp', connected: true, current: true }, ...]
```

### info(deviceId?)

```js
const info = await ZeroBox.device.info();
// { id: 'D4:17:61:...', name: '...', model: 'M2401B1',
//   firmwareVersion: '3.1.175', battery: 85 }
```

### connect(deviceId)

连接指定设备，需要设备已配对且有 authkey。

```js
await ZeroBox.device.connect('D4:17:61:14:18:6E');
```

### disconnect()

断开当前设备。

```js
await ZeroBox.device.disconnect();
```

## 应用管理

### apps.list(deviceId?)

```js
const apps = await ZeroBox.device.apps.list();
// [{ packageName: 'com.example.app', name: '示例应用',
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

## 安装资源

### install(path, options)

将沙箱文件安装到设备。

```js
// 安装快应用
await ZeroBox.device.install('/data/app.bin', {
  type: 'app',
  fileName: 'app.bin'
});

// 安装表盘
await ZeroBox.device.install('/data/watchface.bin', {
  type: 'watchface',
  fileName: 'watchface.bin'
});

// 安装固件
await ZeroBox.device.install('/data/firmware.fw', {
  type: 'firmware',
  fileName: 'firmware.fw'
});
```

`type` 可选值：`app` | `watchface` | `firmware`。

## 完整示例：设备信息面板

```js
globalThis.activate = async (plugin) => {
  let info = '点击按钮获取设备信息';
  const { Column, Text, Button } = ZeroBox.ui;

  const listDevices = async () => {
    const devices = await ZeroBox.device.list();
    info = devices.map(d =>
      `${d.name} ${d.connected ? '✓' : '✗'} ${d.current ? '←当前' : ''}`
    ).join('\n');
  };

  const loadInfo = async () => {
    try {
      const d = await ZeroBox.device.info();
      info = `型号: ${d.model}\n固件: ${d.firmwareVersion}\n电量: ${d.battery}%`;
    } catch (e) { info = `错误: ${e.message}`; }
  };

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      Button('列出设备', { onClick: ZeroBox.ui.action(listDevices, render) }),
      Button('设备信息', { onClick: ZeroBox.ui.action(loadInfo, render) }),
      Text(info),
    ]),
  );

  render();
};
```

## 权限

声明 `device` 许可。只读操作（`list`、`info`、`apps.list`）中等风险；
写入操作（`connect`、`disconnect`、`install`、`apps.launch`、`apps.uninstall`）高风险，
按具体操作和目标设备授权。
