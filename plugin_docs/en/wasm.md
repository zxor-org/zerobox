# Pure WASM Plugin ABI v1

A pure WASM entry exports `zerobox_start()` or WASI `_start()` and linear
memory named `memory`. Host imports must not be called from the module start
section; call them from the exported entry point.

The `zerobox` import module exposes an asynchronous request ABI:

```c
int32_t request(int32_t method_ptr, int32_t method_len,
                int32_t args_ptr, int32_t args_len);
int32_t poll(int32_t request_id); // 0 pending, 1 success, 2 error
int32_t result_len(int32_t request_id);
int32_t result_read(int32_t request_id, int32_t ptr, int32_t capacity);
void result_drop(int32_t request_id);
```

Method names are UTF-8 and arguments are JSON arrays. Results are UTF-8 JSON:
`{"ok":true,"value":...}` or `{"ok":false,"error":"..."}`. If the output
buffer is too small, `result_read` returns the negative required length. The
host calls optional `zerobox_on_result(request_id)` when a request completes.

Host-to-plugin callbacks use `zerobox_alloc`, optional `zerobox_free`,
`zerobox_callback`, and `zerobox_event` exports. WASI preopens `/plugin`,
`/data`, `/cache`, and `/temp`. `/plugin` is a disposable package snapshot, so
writes cannot modify the installed package.
