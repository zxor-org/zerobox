# storage — 键值存储

持久化键值对，卸载插件时一并删除。值可以是任意 JSON 可序列化的数据。

## 方法

### get(key)

读取一个键的值。

```js
const value = await ZeroBox.storage.get('lastVisit');
// value 为存储的值，未设置过则返回 undefined
```

### set(key, value)

写入一个键值对。

```js
await ZeroBox.storage.set('lastVisit', new Date().toISOString());
await ZeroBox.storage.set('theme', 'dark');
await ZeroBox.storage.set('prefs', { fontSize: 14, lineHeight: 1.5 });
```

### remove(key)

删除一个键。

```js
await ZeroBox.storage.remove('theme');
```

### clear()

清空所有存储。

```js
await ZeroBox.storage.clear();
```

## 完整示例

```js
globalThis.activate = async (plugin) => {
  let lastVisit = (await ZeroBox.storage.get('lastVisit')) || '从未访问';
  let visitCount = (await ZeroBox.storage.get('visitCount')) || 0;
  const { Column, Text, Button } = ZeroBox.ui;

  const recordVisit = async () => {
    visitCount++;
    lastVisit = new Date().toLocaleString();
    await ZeroBox.storage.set('visitCount', visitCount);
    await ZeroBox.storage.set('lastVisit', lastVisit);
  };

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      Text(`上次访问: ${lastVisit}`),
      Text(`访问次数: ${visitCount}`),
      Button('记录访问', { onClick: ZeroBox.ui.action(recordVisit, render) }),
    ]),
  );

  render();
};
```
