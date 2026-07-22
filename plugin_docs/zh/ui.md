# ui — 插件界面渲染

插件通过组件树声明 UI。每个节点是一个 `{type, props, children}` 对象。

## 渲染

```js
ZeroBox.ui.render(tree);      // 在插件详情页渲染
ZeroBox.ui.openPage(tree);    // 打开全屏页面
```

`render` 和 `openPage` 接收**单个根节点**（通常是 Column 容器）。

异步交互必须等待操作完成后再重新渲染，并返回 `render()` 的 Promise：

```js
const save = ZeroBox.ui.action(async () => {
  await ZeroBox.storage.set('key', 'value');
  status = '保存成功';
}, render);
```

`ZeroBox.ui.action(fn, render)` 会等待 `fn` 完成后调用 `render`。如果自行注册回调并在异步操作完成前渲染，界面只会得到旧状态。

## 获取容器尺寸

```js
const size = await ZeroBox.ui.getRenderSize();
// { width: 360, height: 480 }
```

## 原生弹窗

```js
const result = await ZeroBox.ui.dialog({
  title: '确认操作',
  message: '确定要删除吗？',
  buttons: [
    { id: 'cancel', text: '取消' },
    { id: 'confirm', text: '确定', primary: true },
  ]
});
// result = { clickedBtnId: 'confirm' }
```

## 布局组件

### Column / Row

```js
const { Column, Row, Spacer, Text } = ZeroBox.ui;

Column({ gap: 12, padding: 16, align: 'start' }, [
  Text('标题', { size: 20, weight: 'bold' }),
  Row({ gap: 8 }, [
    Text('左侧'),
    Spacer(),
    Text('右侧'),
  ]),
]);
```

| prop | 类型 | 说明 |
|------|------|------|
| `gap` | number | 子元素间距 |
| `padding` | number | 内边距 |
| `align` | 'start'/'center'/'end' | 交叉轴对齐 |

### LazyColumn

纵滚列表，适合元素数量不定的场景。

```js
LazyColumn({ gap: 8 }, items.map(item => Text(item)));
```

### Spacer

弹性占位，填充剩余空间。仅 Row/Column 内有效。

## 基础组件

### Text

```js
Text('普通文本');
Text('标题', { size: 20, weight: 'bold', color: '#333', align: 'center', maxLines: 2 });
```

| prop | 类型 | 说明 |
|------|------|------|
| `size` | number | 字号 |
| `weight` | 'normal'/'medium'/'bold' | 字重 |
| `color` | string | '#RRGGBB' |
| `align` | 'start'/'center'/'end' | 对齐 |
| `maxLines` | number | 最大行数 |

### Button

```js
Button('点击', { onClick: () => console.info('clicked') });
Button('主要按钮', { primary: true, onClick: save });
```

### Image

```js
Image('/data/icon.png', { width: 64, height: 64, radius: 12, fit: 'cover' });
```

图片从插件沙箱路径读取，单张不得超过 4 MiB。`fit` 支持 `cover`、`contain`、`fill`、`fitWidth`、`fitHeight`、`none` 和 `scaleDown`。

### Divider

```js
Divider({ thickness: 1 });
```

### Badge

```js
Badge({ count: 3 }, Button('消息', { onClick: openMsg }));
```

## 输入组件

### TextField

```js
TextField({ value: '默认', placeholder: '请输入', multiline: true, onChange: v => save(v) });
```

### Switch

```js
Switch(true, { onChange: v => save('enabled', v) });
```

### Checkbox

```js
Checkbox(false, { label: '记住我', onChange: v => save('remember', v) });
```

### Slider

```js
Slider(0.5, { min: 0, max: 1, onChange: v => save('volume', v) });
```

### Dropdown

```js
Dropdown('A', { options: ['A', 'B', 'C'], onChange: v => save('option', v) });
```

## 容器组件

### Card

```js
Card({}, Row({ gap: 8 }, [Image('/plugin/icon.png', { width: 32 }), Text('内容')]));
```

### Modal

```js
Modal({ title: '设置', onDismiss: () => refresh() },
  Column({ gap: 12 }, [
    Text('这里是弹窗内容'),
    Button('关闭', { onClick: dismiss }),
  ])
);
```

### Tooltip

```js
Tooltip({ text: '解释文字' }, Text('悬停我'));
```

## 列表/标签

### Tabs + TabContent

```js
let activeTab = 'a';

const render = () => {
  ZeroBox.ui.render(
    Column({}, [
      Tabs({
        scrollable: true,
        tabs: [{ id: 'a', label: '标签A' }, { id: 'b', label: '标签B' }],
        activeId: activeTab,
        onChange: v => { activeTab = v; render(); }
      }),
      TabContent('a', activeTab, Text('A的内容')),
      TabContent('b', activeTab, Text('B的内容')),
    ])
  );
};
```

标签较多时设置 `scrollable: true`，标签栏会横向滚动而不是压缩标签。

## 状态组件

```js
CircularProgress({ size: 24 });
LinearProgress(45, { max: 100 });
```

## 通用 Props

所有组件支持：`visible` `disabled` `opacity` `padding`

```js
Text('隐藏文本', { visible: false });
Button('禁用', { disabled: true });
Text('半透明', { opacity: 0.5 });
```

## 完整示例：设置页

```js
globalThis.activate = async (plugin) => {
  const { Column, Row, Card, Text, Button, Switch, Slider, Dropdown, Divider, Spacer } = ZeroBox.ui;

  let notify = true;
  let brightness = 0.5;
  let theme = 'auto';

  const render = () => {
    ZeroBox.ui.render(
      Column({ padding: 16, gap: 12 }, [
        Text('设置', { size: 22, weight: 'bold' }),

        Card({}, Column({ gap: 8 }, [
          Row({ gap: 8 }, [Text('通知'), Spacer(), Switch(notify, { onChange: v => { notify = v; render(); } })]),
          Divider(),
          Row({ gap: 8 }, [Text('亮度'), Slider(brightness, { onChange: v => { brightness = v; render(); } })]),
          Divider(),
          Row({ gap: 8 }, [
            Text('主题'),
            Spacer(),
            Dropdown(theme, { options: ['auto', 'light', 'dark'], onChange: v => { theme = v; render(); } }),
          ]),
        ])),

        Row({ gap: 12 }, [
          Button('取消', { onClick: cancel }),
          Button('保存', { primary: true, onClick: submit }),
        ]),
      ])
    );
  };

  render();
};
```
