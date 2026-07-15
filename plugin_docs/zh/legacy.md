# AstroBox v1 Legacy 兼容

`.abp` 且 manifest 未声明 `runtime` 的包被识别为 Legacy。兼容层运行在
JavaScript 客体环境中，把 `AstroBox.*` 调用翻译为 ZeroBox v1 Host API。
权限、沙箱、设备访问、网络和生命周期仍由新底座执行。

兼容层不在 Dart manager 中注册 ABv1 方法，也不会复制一套旧文件系统或设备
实现。文件选择对 ABv1 插件仍只返回原始文件名，适配器内部把它映射到
`/temp` 文件。现有存量未使用的 ABv1 provider 不提供兼容实现。

Legacy 仅用于运行旧插件，不是新插件开发接口。
