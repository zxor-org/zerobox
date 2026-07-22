# watchface — Watchface Management

List and switch the current device's watchfaces.

## Methods

### list(deviceId?)

```js
const watchfaces = await ZeroBox.watchface.list();
// [{ id: '12345', name: 'Classic', current: true }, ...]
```

### set(watchfaceId, deviceId?)

```js
await ZeroBox.watchface.set('67890');
```

## Example: Watchface Switcher

```js
globalThis.activate = async (plugin) => {
  let wfList = [];
  let result = 'Tap to list watchfaces';
  const { Column, Text, Button } = ZeroBox.ui;

  const render = () => {
    const nodes = [
      Button('List', {
        onClick: ZeroBox.ui.action(async () => {
          wfList = await ZeroBox.watchface.list();
          result = wfList.map(w => `${w.name} ${w.current ? '←active' : ''}`).join('\n');
        }, render),
      }),
      Text(result),
    ];

    for (const wf of wfList) {
      if (wf.current) continue;
      nodes.push(Button(`Switch to ${wf.name}`, {
        onClick: ZeroBox.ui.action(async () => {
          await ZeroBox.watchface.set(wf.id);
          result = `Switched to ${wf.name}`;
        }, render),
      }));
    }
    return ZeroBox.ui.render(Column({ gap: 8 }, nodes));
  };

  render();
};
```

## Permission

Declare `device`. `list` is medium-risk, `set` is high-risk.
