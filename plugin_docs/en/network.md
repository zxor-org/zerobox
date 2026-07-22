# network — HTTP Requests

Make HTTP/HTTPS requests through the host. Only `http://` and `https://` schemes are supported.

## fetch(url, options)

Response body is limited to 16 MiB. Use `download` for larger files.

```js
const resp = await ZeroBox.network.fetch('https://httpbin.org/json', {
  method: 'GET',
  headers: { 'Accept': 'application/json' },
  body: base64data  // optional, Base64-encoded request body
});
// resp = { status: 200, headers: {...}, contentType: 'application/json',
//          body: 'eyJoZWxsbyI6...' }

// Decode response body
const text = atob(resp.body);
const json = JSON.parse(text);
```

## download(url, path, options)

Streams the response directly to a sandbox file. Ideal for large downloads.

```js
const result = await ZeroBox.network.download(
  'https://example.com/file.bin',
  '/data/file.bin',
  { method: 'GET', headers: {} }
);
// result = { path: '/data/file.bin', bytesWritten: 1048576, status: 200 }
```

## Example: JSON Fetcher

```js
globalThis.activate = async (plugin) => {
  let url = 'https://httpbin.org/json';
  let result = 'Enter a URL and tap Fetch';
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
    } catch (e) { result = `Error: ${e.message}`; }
  };

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      TextField({ value: url, onChange: v => { url = v; } }),
      Button('Fetch', { onClick: ZeroBox.ui.action(fetchJson, render) }),
      Text(result),
    ]),
  );

  render();
};
```

## Permission

Declare `network` in the manifest. Medium-risk — prompts on first use.
