# protocol — Raw Device Protocol

Read and write raw Bluetooth protocol frames on the current device. Data uses Base64.

**Warning:** Raw protocol operations can interfere with normal device communication.

## send(base64Payload, options?)

```js
await ZeroBox.protocol.send(btoa('\x01\x00'));
```

## request(base64Payload, options?)

Send and await a response.

```js
const response = await ZeroBox.protocol.request(btoa('\x01\x00'));
```

## observe(callback)

Passive observation of all raw protocol data (read-only, does not interrupt normal dispatch).

```js
const stop = await ZeroBox.protocol.observe(({ data }) => {
  // data is Base64-encoded raw bytes
  console.info('Protocol data:', data);
});

await stop();
```

## Example: Protocol Monitor

```js
globalThis.activate = async (plugin) => {
  let hexInput = '';
  let output = '';
  const { Column, Text, TextField, Button } = ZeroBox.ui;

  ZeroBox.protocol.observe(({ data }) => {
    const raw = atob(data);
    let hex = '';
    for (let i = 0; i < raw.length; i++)
      hex += raw.charCodeAt(i).toString(16).padStart(2, '0');
    output = `Received: ${hex}`;
    render();
  });

  const sendHex = async () => {
    const bytes = hexInput.match(/../g)
      ?.map(b => String.fromCharCode(parseInt(b, 16))).join('') ?? '';
    await ZeroBox.protocol.send(btoa(bytes));
    output = `Sent: ${bytes.length} bytes`;
  };

  const render = () => ZeroBox.ui.render(
    Column({ gap: 8 }, [
      TextField({ value: hexInput, onChange: v => { hexInput = v; } }),
      Button('Send Hex', { onClick: ZeroBox.ui.action(sendHex, render) }),
      Text(output || 'Waiting...'),
    ]),
  );

  render();
};
```

## Permission

Declare `protocol`. `observe` is medium-risk; `send` and `request` are high-risk.
