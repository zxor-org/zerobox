# network — 网络请求

通过宿主发起 HTTP/HTTPS 请求。仅支持 `http://` 和 `https://` 协议。

## fetch(url, options)

发起请求并返回响应。响应体大小限制 16 MiB，超出请用 `download`。

```js
const resp = await ZeroBox.network.fetch('https://httpbin.org/json', {
  method: 'GET',          // 默认 GET
  headers: {              // 可选
    'Accept': 'application/json'
  },
  body: base64data        // 可选，Base64 编码的请求体
});
// resp = {
//   status: 200,
//   headers: { 'content-type': 'application/json' },
//   contentType: 'application/json',
//   body: 'eyJoZWxsbyI6IndvcmxkIn0='  // Base64 编码的响应体
// }
```

读取文本响应体：

```js
const resp = await ZeroBox.network.fetch('https://api.example.com/data');
const text = atob(resp.body);  // Base64 → 文本
const json = JSON.parse(text);
```

## download(url, path, options)

将响应直接流式写入沙箱文件，适合大文件。

```js
const result = await ZeroBox.network.download(
  'https://example.com/file.bin',
  '/data/file.bin',
  {
    method: 'GET',
    headers: {}
  }
);
// result = { path: '/data/file.bin', bytesWritten: 1048576, status: 200 }
```

## 完整示例：JSON 查看器

```js
globalThis.activate = async (plugin) => {
  let url = 'https://httpbin.org/json';
  let result = '输入 URL 并点击获取';
  const { Column, Text, TextField, Button } = ZeroBox.ui;

  const fetchJson = async () => {
    try {
      const resp = await ZeroBox.network.fetch(url);
      const body = resp.body ? atob(resp.body) : '';
      try {
        result = JSON.stringify(JSON.parse(body), null, 2);
      } catch (_) {
        result = body.substring(0, 500);
      }
    } catch (e) {
      result = `错误: ${e.message}`;
    }
  };

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      TextField({ value: url, onChange: v => { url = v; } }),
      Button('GET', { onClick: ZeroBox.ui.action(fetchJson, render) }),
      Text(result),
    ]),
  );

  render();
};
```

## 权限

声明 `network` 许可。首次请求会弹出授权对话框。
