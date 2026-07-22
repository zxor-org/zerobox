# ui — Plugin UI Rendering

Render plugin UI through component trees. Each node is a `{type, props, children}` object.

## Rendering

```js
ZeroBox.ui.render(tree);      // render inline in plugin detail page
ZeroBox.ui.openPage(tree);    // open full-screen page
```

Both accept a single root node (typically a Column).

Async interactions must wait for the operation before re-rendering and return
the `render()` Promise:

```js
const save = ZeroBox.ui.action(async () => {
  await ZeroBox.storage.set('key', 'value');
  status = 'Saved';
}, render);
```

`ZeroBox.ui.action(fn, render)` waits for `fn` before calling `render`. Manually rendering before an asynchronous operation completes renders stale state.

## Get Render Size

```js
const size = await ZeroBox.ui.getRenderSize();
// { width: 360, height: 480 }
```

## Native Dialog

```js
const result = await ZeroBox.ui.dialog({
  title: 'Confirm',
  message: 'Are you sure?',
  buttons: [
    { id: 'cancel', text: 'Cancel' },
    { id: 'confirm', text: 'OK', primary: true },
  ]
});
// result = { clickedBtnId: 'confirm' }
```

## Layout

### Column / Row

```js
const { Column, Row, Spacer, Text } = ZeroBox.ui;

Column({ gap: 12, padding: 16, align: 'start' }, [
  Text('Title', { size: 20, weight: 'bold' }),
  Row({ gap: 8 }, [Text('Left'), Spacer(), Text('Right')]),
]);
```

| prop | type | description |
|------|------|-------------|
| `gap` | number | spacing between children |
| `padding` | number | inner padding |
| `align` | 'start'/'center'/'end' | cross-axis alignment |

### LazyColumn

Scrollable column list.

```js
LazyColumn({ gap: 8 }, items.map(item => Text(item)));
```

### Spacer

Flexible filler that takes remaining space.

## Basic Components

### Text

```js
Text('Plain text');
Text('Title', { size: 20, weight: 'bold', color: '#333', maxLines: 2 });
```

### Button

```js
Button('Tap', { onClick: () => save() });
Button('Primary', { primary: true, onClick: submit });
```

### Image

```js
Image('/data/icon.png', { width: 64, height: 64, radius: 12, fit: 'cover' });
```

Images are read from plugin sandbox paths and must not exceed 4 MiB each. `fit` supports `cover`, `contain`, `fill`, `fitWidth`, `fitHeight`, `none`, and `scaleDown`.

### Divider / Badge

```js
Divider({ thickness: 1 });
Badge({ count: 3 }, Button('Messages'));
```

## Input Components

```js
TextField({ value: 'default', placeholder: 'Input...', multiline: true, onChange: v => save(v) });
Switch(true, { onChange: v => save('on', v) });
Checkbox(false, { label: 'Remember me', onChange: v => save('remember', v) });
Slider(0.5, { min: 0, max: 1, onChange: v => save('volume', v) });
Dropdown('A', { options: ['A', 'B', 'C'], onChange: v => save('opt', v) });
```

## Container Components

```js
Card({}, Row({ gap: 8 }, [Image('/plugin/icon.png', { width: 32 }), Text('Content')]));
Modal({ title: 'Settings', onDismiss: refresh }, Text('Modal body'));
Tooltip({ text: 'Help text' }, Text('Hover me'));
```

## Tabs

```js
Tabs({
  scrollable: true,
  tabs: [{ id: 'a', label: 'Tab A' }, { id: 'b', label: 'Tab B' }],
  activeId: 'a',
  onChange: v => switchTab(v)
});
TabContent('a', activeTab, Text('Content A'));
```

Set `scrollable: true` when there are many tabs so the tab bar scrolls instead of compressing labels.

## Progress

```js
CircularProgress({ size: 24 });
LinearProgress(45, { max: 100 });
```

## Common Props

All components: `visible` `disabled` `opacity` `padding`

## Example: Settings Page

```js
globalThis.activate = async (plugin) => {
  const { Column, Row, Card, Text, Button, Switch, Slider, Dropdown, Divider, Spacer } = ZeroBox.ui;
  let notify = true, brightness = 0.5, theme = 'auto';

  const render = () => {
    ZeroBox.ui.render(
      Column({ padding: 16, gap: 12 }, [
        Text('Settings', { size: 22, weight: 'bold' }),
        Card({}, Column({ gap: 8 }, [
          Row({ gap: 8 }, [Text('Notifications'), Spacer(), Switch(notify, { onChange: v => { notify = v; render(); } })]),
          Divider(),
          Row({ gap: 8 }, [Text('Brightness'), Slider(brightness, { onChange: v => { brightness = v; render(); } })]),
          Divider(),
          Row({ gap: 8 }, [Text('Theme'), Spacer(), Dropdown(theme, { options: ['auto','light','dark'], onChange: v => { theme = v; render(); } })]),
        ])),
        Row({ gap: 12 }, [Button('Cancel'), Button('Save', { primary: true, onClick: submit })]),
      ])
    );
  };
  render();
};
```
