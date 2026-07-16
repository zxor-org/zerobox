# 纯 WASM 插件 ABI v1

纯 WASM 插件入口必须导出 `zerobox_start()` 或 WASI `_start()`，并导出线性
内存 `memory`。模块 start section 不得调用 Host import；应在入口函数中调用。

Host 在 `zerobox` 模块下提供同步导入，用请求 ID 表示异步调用：

```c
int32_t request(int32_t method_ptr, int32_t method_len,
                int32_t args_ptr, int32_t args_len);
int32_t poll(int32_t request_id);       // 0 pending, 1 success, 2 error
int32_t result_len(int32_t request_id);
int32_t result_read(int32_t request_id, int32_t ptr, int32_t capacity);
void result_drop(int32_t request_id);
```

方法名和参数采用 UTF-8；参数是 JSON 数组。结果是 UTF-8 JSON：
`{"ok":true,"value":...}` 或 `{"ok":false,"error":"..."}`。缓冲区不足时
`result_read` 返回所需长度的负数。请求完成后，Host 会调用可选导出
`zerobox_on_result(request_id)`。

Host 调用插件时使用以下导出：

```c
int32_t zerobox_alloc(int32_t length);                  // required for callbacks
void zerobox_free(int32_t ptr, int32_t length);         // optional
void zerobox_callback(name_ptr, name_len, json_ptr, json_len);
void zerobox_event(name_ptr, name_len, payload_ptr, payload_len);
```

WASI 预打开 `/plugin`、`/data`、`/cache`、`/temp`。`/plugin` 映射到安装包
副本，任何写入都不会修改已安装包。Web 端在运行结束时把可写目录同步回插件
存储。
