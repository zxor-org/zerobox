# appside — Zepp OS AppSide 管理

管理 Zepp OS 设备上的 AppSide 会话。AppSide 是手表上的小程序在手机侧运行的
远程 JS 通道（蓝牙端点 `0x00a0`），通过 `messaging.peerSocket` 与手表实时双向通信。

插件可以通过 AppSide API 安装/更新 app-side.js 脚本、管理运行时状态、
收发消息和读取调试日志。

`appId` 为 32-bit 无符号整数（Zepp OS 小程序的应用 ID）。

## 方法

### list()

列出已缓存 app-side.js 脚本的 appId。

```js
const ids = await ZeroBox.appside.list();
// [0x0010ee3b, 0x00001234, ...]
```

### start(appId)

启动本地 AppSide QuickJS runtime。需要已缓存脚本。

```js
await ZeroBox.appside.start(0x0010ee3b);
```

### stop(appId)

停止 runtime。

```js
await ZeroBox.appside.stop(0x0010ee3b);
```

### send(appId, hexData)

将 hex 编码的二进制数据发往手表（需要手表已打开 real session）。

```js
await ZeroBox.appside.send(0x0010ee3b, '0100ff');
```

### inject(appId, hexData)

模拟手表发来消息，注入到本地 runtime（调试用，不需要手表打开 session）。

```js
await ZeroBox.appside.inject(0x0010ee3b, '48656c6c6f');
// "Hello" 的 hex → runtime 的 peerSocket.onmessage 会收到
```

### sessions()

列出当前所有活跃会话。

```js
const sessions = await ZeroBox.appside.sessions();
// [{ appId: 0x0010ee3b, version: 1, port1: 20, port2: 1004,
//    extra: 0, watchSessionOpen: true }, ...]
```

### events(appId)

读取调试事件日志。

```js
const events = await ZeroBox.appside.events(0x0010ee3b);
// [{ timestamp: '2024-01-01T00:00:00.000', type: 'start',
//    message: '脚本加载成功（1234 字符）' }, ...]
```

### clearEvents(appId)

清空调试事件。

```js
await ZeroBox.appside.clearEvents(0x0010ee3b);
```

## 完整示例：AppSide 管理面板

```js
globalThis.activate = async (plugin) => {
  let ids = [];
  let sessions = [];
  let result = '';
  const { Column, Text, Button } = ZeroBox.ui;

  const render = () => {
    const nodes = [
      Button('刷新列表', {
        onClick: ZeroBox.ui.action(async () => {
          ids = await ZeroBox.appside.list();
          result = `已缓存 ${ids.length} 个脚本: ${ids.map(i => '0x' + i.toString(16)).join(', ')}`;
        }, render),
      }),
      Button('查看会话', {
        onClick: ZeroBox.ui.action(async () => {
          sessions = await ZeroBox.appside.sessions();
          result = sessions.map(s =>
            `0x${s.appId.toString(16)}: watch=${s.watchSessionOpen}`
          ).join('\n') || '无活跃会话';
        }, render),
      }),
      Text(result),
    ];

    // 为每个缓存的 appId 添加启动/停止按钮
    for (const id of ids) {
      const hex = '0x' + id.toString(16);
      nodes.push(Button(`启动 ${hex}`, {
        onClick: ZeroBox.ui.action(async () => {
          try {
            await ZeroBox.appside.start(id);
            result = `${hex} 已启动`;
          } catch (e) { result = `启动失败: ${e.message}`; }
        }, render),
      }));
      nodes.push(Button(`停止 ${hex}`, {
        onClick: ZeroBox.ui.action(async () => {
          await ZeroBox.appside.stop(id);
          result = `${hex} 已停止`;
        }, render),
      }));
    }

    return ZeroBox.ui.render(Column({ gap: 8 }, nodes));
  };

  render();
};
```

## 权限

声明 `appside` 许可。只读操作（`list`、`sessions`、`events`）中等风险；
控制操作（`start`、`stop`、`send`、`inject`、`clearEvents`）高风险。
