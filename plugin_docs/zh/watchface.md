# watchface — 表盘管理

列出和切换当前设备的表盘。

## 方法

### list(deviceId?)

列出设备上已安装的表盘。

```js
const watchfaces = await ZeroBox.watchface.list();
// [{ id: '12345', name: '经典表盘', current: true },
//  { id: '67890', name: '运动表盘', current: false }, ...]
```

### set(watchfaceId, deviceId?)

切换当前表盘。

```js
await ZeroBox.watchface.set('67890');
```

## 完整示例

```js
globalThis.activate = async (plugin) => {
  let wfList = [];
  let result = '点击列出表盘';
  const { Column, Text, Button } = ZeroBox.ui;

  const render = () => {
    const nodes = [
      Button('列出表盘', {
        onClick: ZeroBox.ui.action(async () => {
          wfList = await ZeroBox.watchface.list();
          result = wfList.map(w =>
            `${w.name} (${w.id}) ${w.current ? '←当前' : ''}`
          ).join('\n');
        }, render),
      }),
      Text(result),
    ];

    // 为每个非当前表盘添加切换按钮
    for (const wf of wfList) {
      if (wf.current) continue;
      nodes.push(Button(`切换到 ${wf.name}`, {
        onClick: ZeroBox.ui.action(async () => {
          await ZeroBox.watchface.set(wf.id);
          result = `已切换到 ${wf.name}`;
        }, render),
      }));
    }

    return ZeroBox.ui.render(Column({ gap: 8 }, nodes));
  };

  render();
};
```

## 权限

声明 `device` 许可。`list` 中等风险，`set` 高风险。
