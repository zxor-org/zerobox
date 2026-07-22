# interconnect — 跨插件消息

插件之间通过包名（packageName）收发原始文本消息。ZeroBox 只提供基础设施，
不规定文件传输、分片或确认协议。

## 发送

### send(packageName, data, deviceId?)

向指定包名发送消息。

```js
await ZeroBox.interconnect.send('com.example.target', 'hello from plugin');
```

## 接收

### onMessage(callback)

开始监听来自其他插件的消息，返回一个取消监听的函数。

```js
const stop = await ZeroBox.interconnect.onMessage(({ packageName, data }) => {
  console.info(`收到来自 ${packageName} 的消息: ${data}`);
});

// 停止监听
await stop();
```

## 完整示例：消息收发器

```js
globalThis.activate = async (plugin) => {
  let target = '';
  let message = '';
  let received = '';
  const { Column, Text, TextField, Button } = ZeroBox.ui;

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      TextField({ value: target, placeholder: '目标包名', onChange: v => { target = v; } }),
      TextField({ value: message, placeholder: '消息', onChange: v => { message = v; } }),
      Button('发送', {
        onClick: () => ZeroBox.interconnect.send(target, message),
      }),
      Text(received || '等待消息...'),
    ]),
  );

  // 启动时开始监听
  ZeroBox.interconnect.onMessage(({ packageName, data }) => {
    received = `[${packageName}] ${data}`;
    render();
  });

  render();
};
```

## 权限

声明 `interconnect` 许可，中等风险。
