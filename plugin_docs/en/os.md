# os — Host Environment Info

Retrieve information about the host OS. No permission required.

## Methods

```js
const arch       = await ZeroBox.os.arch();       // 'x64' | 'arm64' | 'unknown'
const hostname   = await ZeroBox.os.hostname();    // Desktop only
const locale     = await ZeroBox.os.locale();      // 'en_US' | 'zh_CN' | ...
const platform   = await ZeroBox.os.platform();    // 'linux' | 'macos' | 'windows' | 'android' | 'ios'
const version    = await ZeroBox.os.version();     // Desktop only
const language   = await ZeroBox.os.language();    // 'en' | 'zh' | ...
const appearance = await ZeroBox.os.appearance();  // 'light' | 'dark'
const timezone   = await ZeroBox.os.timezone();    // UTC offset in minutes, e.g. 480 = UTC+8
```

## Example

```js
globalThis.activate = async (plugin) => {
  const lines = [
    `Platform: ${await ZeroBox.os.platform()}`,
    `Arch: ${await ZeroBox.os.arch()}`,
    `Language: ${await ZeroBox.os.language()}`,
    `Locale: ${await ZeroBox.os.locale()}`,
    `Appearance: ${await ZeroBox.os.appearance()}`,
    `Timezone: UTC${await ZeroBox.os.timezone() >= 0 ? '+' : ''}${await ZeroBox.os.timezone() / 60}h`
  ];

  await ZeroBox.ui.render(ZeroBox.ui.Text(lines.join('\n')));
};
```
