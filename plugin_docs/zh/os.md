# os — 宿主环境信息

获取运行 ZeroBox 的宿主操作系统信息。无需声明权限。

## 方法

```js
const arch      = await ZeroBox.os.arch();      // 'x64' | 'arm64' | 'unknown'
const hostname  = await ZeroBox.os.hostname();   // 主机名（桌面平台）
const locale    = await ZeroBox.os.locale();     // 'zh_CN' | 'en_US' | ...
const platform  = await ZeroBox.os.platform();   // 'linux' | 'macos' | 'windows' | 'android' | 'ios'
const version   = await ZeroBox.os.version();    // OS 版本号（桌面平台）
const language  = await ZeroBox.os.language();   // 'zh' | 'en' | ...
const appearance = await ZeroBox.os.appearance(); // 'light' | 'dark'
const timezone  = await ZeroBox.os.timezone();   // 时区偏移（分钟），如 480 表示 UTC+8
```

- `arch` 和 `hostname` 仅 Linux/macOS/Windows 桌面平台返回有意义的值，Web/移动端返回 `'unknown'`
- `timezone` 返回相对于 UTC 的分钟偏移

## 完整示例

```js
globalThis.activate = async (plugin) => {
  let info = '';

  const load = async () => {
    const lines = [
      `平台: ${await ZeroBox.os.platform()}`,
      `架构: ${await ZeroBox.os.arch()}`,
      `语言: ${await ZeroBox.os.language()}`,
      `区域: ${await ZeroBox.os.locale()}`,
      `外观: ${await ZeroBox.os.appearance()}`,
      `时区: UTC${await ZeroBox.os.timezone() >= 0 ? '+' : ''}${await ZeroBox.os.timezone() / 60}h`
    ];
    info = lines.join('\n');
  };

  const render = () => ZeroBox.ui.render(ZeroBox.ui.Text(info));

  await load();
  await render();
};
```
