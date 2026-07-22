# file — 沙箱文件系统

插件拥有独立的沙箱文件系统，分为四个区域：

| 区域 | 路径前缀 | 权限 | 说明 |
|------|---------|------|------|
| 插件包 | `/plugin` | 只读 | 打包在 `.zbp` 内的文件 |
| 数据 | `/data` | 读写 | 持久化存储 |
| 缓存 | `/cache` | 读写 | 可能被系统清理 |
| 临时 | `/temp` | 读写 | 重启后清空 |

二进制数据使用 Base64 编码传输。

## 读写

### read(path, options)

```js
// 以 UTF-8 文本读取
const text = await ZeroBox.file.read('/data/note.txt', { encoding: 'utf8' });

// 以 Base64 读取二进制
const base64 = await ZeroBox.file.read('/data/image.png', { encoding: 'base64' });

// 分片读取
const chunk = await ZeroBox.file.read('/data/large.bin', {
  encoding: 'base64',
  offset: 1024,   // 起始字节
  length: 512     // 读取长度
});
```

### write(path, data, options)

```js
// 写入 UTF-8 文本
await ZeroBox.file.write('/data/note.txt', 'Hello World', { encoding: 'utf8' });

// 写入 Base64 二进制
await ZeroBox.file.write('/data/image.png', base64data, { encoding: 'base64' });

// 追加写入
await ZeroBox.file.write('/data/log.txt', '新的一行\n', {
  encoding: 'utf8',
  append: true
});
```

## 目录操作

```js
// 列出目录内容 → [{name, path, size, isDirectory}, ...]
const entries = await ZeroBox.file.list('/data');

// 查看文件信息 → {name, path, size, isDirectory} 或 null
const stat = await ZeroBox.file.stat('/data/note.txt');

// 创建目录
await ZeroBox.file.mkdir('/data/subdir');

// 复制
await ZeroBox.file.copy('/data/a.txt', '/data/b.txt');

// 移动
await ZeroBox.file.move('/temp/a.txt', '/data/a.txt');

// 删除文件或目录
await ZeroBox.file.remove('/data/old.txt');
```

## 原生文件交互

### pick(options)

打开系统文件选择器，将选中文件导入到 `/temp/picker/...`。

```js
const picked = await ZeroBox.file.pick({});
if (!picked) return; // 用户取消
// picked = { name: 'photo.png', path: '/temp/picker/.../photo.png', size: 102400 }
```

### unload(path, options)

将沙箱文件导出到原生环境（弹出保存对话框）。

```js
const result = await ZeroBox.file.unload('/data/report.pdf', {
  suggestedName: '报告.pdf'
});
// result = { exported: true, name: '报告.pdf' }
```

## 完整示例：日志记录器

```js
globalThis.activate = async (plugin) => {
  const LOG_PATH = '/data/log.txt';
  let logs = '';
  const { Column, Text, Button } = ZeroBox.ui;

  const addLog = async () => {
    const line = `[${new Date().toLocaleTimeString()}] 一条日志\n`;
    await ZeroBox.file.write(LOG_PATH, line, { encoding: 'utf8', append: true });
    logs = await ZeroBox.file.read(LOG_PATH, { encoding: 'utf8' });
  };

  const clearLogs = async () => {
    await ZeroBox.file.remove(LOG_PATH);
    logs = '';
  };

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      Text(logs || '暂无日志'),
      Button('添加日志', { onClick: ZeroBox.ui.action(addLog, render) }),
      Button('清空', { onClick: ZeroBox.ui.action(clearLogs, render) }),
    ]),
  );

  // 启动时读取已有日志
  try { logs = await ZeroBox.file.read(LOG_PATH, { encoding: 'utf8' }); } catch (_) {}
  render();
};
```
