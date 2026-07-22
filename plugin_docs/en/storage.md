# storage — Key-Value Storage

Persistent key-value pairs, removed when the plugin is uninstalled. Values can
be any JSON-serializable data.

## Methods

### get(key)

```js
const value = await ZeroBox.storage.get('lastVisit');
// Returns the stored value, or undefined if never set
```

### set(key, value)

```js
await ZeroBox.storage.set('lastVisit', new Date().toISOString());
await ZeroBox.storage.set('theme', 'dark');
await ZeroBox.storage.set('prefs', { fontSize: 14, lineHeight: 1.5 });
```

### remove(key)

```js
await ZeroBox.storage.remove('theme');
```

### clear()

```js
await ZeroBox.storage.clear();
```

## Example: Visit Tracker

```js
globalThis.activate = async (plugin) => {
  let lastVisit = (await ZeroBox.storage.get('lastVisit')) || 'Never';
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
      Text(`Last visit: ${lastVisit}`),
      Text(`Visits: ${visitCount}`),
      Button('Record visit', { onClick: ZeroBox.ui.action(recordVisit, render) }),
    ]),
  );

  render();
};
```
