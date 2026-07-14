# ONNX WASM 与流式语音识别暂记

## 当前方向

- 不接入 Flutter 原生 ONNX 插件
- 将 ONNX 推理引擎构建为可由 `wasm_run` 托管的独立 `onnx_engine.wasm`
- Android、iOS、Linux、macOS、Windows 与 Web 共用同一个 ONNX WASM 引擎
- `.onnx` 模型不随 ZeroBox 安装包分发
- ZeroBox 内建模型清单，用户启用功能时再下载模型并校验完整性

运行关系：

```text
wasm_run
  └─ onnx_engine.wasm
       ├─ load_model(model.onnx bytes)
       ├─ run(input tensors)
       └─ output tensors
```

## 引擎要求

- 动态加载普通 `.onnx` 模型，不把模型编译进 WASM
- 可被 Wasmtime/Core Wasm 直接实例化
- 不依赖浏览器 JavaScript glue
- 提供模型加载、Tensor 输入、推理、输出与资源释放 ABI
- 支持 ZeroBox 模型清单中所有模型需要的 ONNX 算子和数据类型
- 第一版使用单线程 + WASM SIMD，后续根据真机基准决定是否补 WASM Threads

官方 ONNX Runtime Web 发布物不能原样作为最终模块，因为它面向浏览器并配套 Emscripten `.mjs` glue。候选实现是使用官方 ONNX Runtime WebAssembly 静态库链接一层很薄的 ZeroBox C ABI，产出独立 `onnx_engine.wasm`

## 体积

实测 `onnxruntime-web 1.27.0` 的 `ort-wasm-simd-threaded.wasm`：

| 形态 | 大小 |
|---|---:|
| 原始 WASM | 12.85 MiB |
| gzip -9 | 3.27 MiB |
| Brotli -11 | 2.05 MiB |

加入 ZeroBox ABI 后，完整算子版预计约 13～16 MiB 原始体积

因为可安装模型来自内建清单，可以收集清单内全部模型使用的算子并生成联合裁剪配置。第一版保留普通 `.onnx` 支持，只裁剪无关算子，不使用仅支持 ORT 格式的极限 Minimal Build

## 模型清单与下载

每个模型条目至少包含：

- 稳定 ID、名称、版本与用途
- 支持语言和流式能力
- 模型文件列表、下载地址、大小与 SHA-256
- License 与来源
- 输入输出 Tensor 定义
- 前处理、后处理和端点检测配置
- 推荐设备档位与预计内存占用

下载流程：

1. 下载到临时文件
2. 校验长度与 SHA-256
3. 原子移动到 `models/<id>/<version>/`
4. 支持删除、更新和损坏后重新下载
5. Web 使用浏览器持久化存储保存模型字节

## 流式语音识别目标

目标不是离线整段转录，而是延迟 5 秒以内的流式语音转文字

首选真正的 Streaming Zipformer 或 Streaming Paraformer INT8 模型，不以 Whisper 作为默认流式方案

建议验收指标：

| 指标 | 目标 |
|---|---:|
| 首次出现 partial text | 0.5～1.5 秒 |
| 增量文字刷新间隔 | 200～500 ms |
| 停止说话到 final text | 1～3 秒 |
| P95 实时率 RTF | ≤ 0.9 |
| 硬延迟上限 | ≤ 5 秒 |

官方 sherpa-onnx 已提供使用 WASM + SIMD 运行中英 Streaming Zipformer 与 Streaming Paraformer 的实时识别示例，因此该产品目标在技术上可行。最终仍需使用选定模型在 Android、x64 Linux 与 Apple Silicon 上测量 RTF、首字延迟、终字延迟和峰值内存

## 待验证

- 选择首个中英流式 INT8 模型及其 License
- 生成可被当前 `wasm_run` 直接托管的 ONNX 引擎原型
- 定义最小稳定 Tensor ABI
- 验证动态状态 Tensor 和多 Session 是否满足流式 Zipformer/Paraformer
- 测量当前单线程 SIMD 后端的真机 RTF
- 根据模型清单生成联合算子裁剪配置

## 参考

- ONNX Runtime WebAssembly 构建与裁剪：https://onnxruntime.ai/docs/build/web.html
- ONNX Runtime Web 性能建议：https://onnxruntime.ai/docs/tutorials/web/performance-diagnosis.html
- sherpa-onnx WASM 实时识别：https://k2-fsa.github.io/sherpa/onnx/wasm/index.html
- sherpa-onnx 中英 Zipformer WASM 构建：https://k2-fsa.github.io/sherpa/onnx/wasm/build.html
