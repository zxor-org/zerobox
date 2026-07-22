# protocol — 原始设备协议

直接读写当前设备的蓝牙协议端点。数据使用 Base64 编码。

**警告：** 原始协议操作可能干扰正常的设备通信，仅在明确知道协议格式时使用。

## 发送

### send(base64Payload, options?)

发送原始协议帧到当前设备。

```js
// 发送一个 hex 为 "0100" 的帧
await ZeroBox.protocol.send(btoa('\x01\x00'));
```

### request(base64Payload, options?)

发送并等待响应。

```js
const response = await ZeroBox.protocol.request(btoa('\x01\x00'));
// response = {}  (响应通过 observe 获取)
```

## 监听

### observe(callback)

旁路监听所有原始协议数据（只读，不影响正常分发）。

```js
const stop = await ZeroBox.protocol.observe(({ data }) => {
  // data 是 Base64 编码的原始字节
  console.info('协议数据:', data);
});

// 停止监听
await stop();
```

## 完整示例：协议监控

```js
globalThis.activate = async (plugin) => {
  let hexInput = '';
  let output = '';
  const { Column, Text, TextField, Button } = ZeroBox.ui;

  const sendHex = async () => {
    try {
      const bytes = hexInput.match(/../g)
        ?.map(b => String.fromCharCode(parseInt(b, 16)))
        .join('') ?? '';
      await ZeroBox.protocol.send(btoa(bytes));
      output = `已发送: ${bytes.length} 字节`;
    } catch (e) {
      output = `错误: ${e.message}`;
    }
  };

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      TextField({ value: hexInput, onChange: v => { hexInput = v; } }),
      Button('发送 Hex', { onClick: ZeroBox.ui.action(sendHex, render) }),
      Text(output || '等待数据...'),
    ]),
  );

  // 监听入站数据
  ZeroBox.protocol.observe(({ data }) => {
    // Base64 → Hex
    const raw = atob(data);
    let hex = '';
    for (let i = 0; i < raw.length; i++) {
      hex += raw.charCodeAt(i).toString(16).padStart(2, '0');
    }
    output = `收到: ${hex}`;
    render();
  });

  render();
};
```

## 权限

声明 `protocol` 许可。`observe` 中等风险，`send` 和 `request` 高风险。
