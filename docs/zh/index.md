# ZeroBox CLI 与守护进程

ZeroBox 通过 `--nogui` 提供桌面端自动化接口

桌面守护进程统一管理蓝牙连接与任务状态，短生命周期的 CLI 进程在 Linux 和 macOS 上通过当前用户专属的 Unix 套接字连接，在 Windows 上则通过回环 IPC 连接

桌面 GUI 同样连接到该守护进程，不会重复占用蓝牙传输通道

## 启动和查看守护进程

```sh
zerobox --nogui daemon start
zerobox --nogui daemon status
zerobox --nogui daemon stop
```

除非指定 `--no-autostart`，其他命令会自动启动守护进程

目前使用的 Flutter 蓝牙插件在 Linux 上仍要求用户已登录图形桌面，`--nogui` 会隐藏窗口，但无法在没有显示服务器的 SSH 会话中运行

## 设备与本地安装

```sh
zerobox --nogui device paired
zerobox --nogui device scan --timeout 10
zerobox --nogui device connect AA:BB:CC:DD:EE:FF
zerobox --nogui device info
zerobox --nogui install quickapp ./demo.rpk
zerobox --nogui install watchface ./face.mwz --device AA:BB:CC:DD:EE:FF
```

使用 `--detach` 可将安装加入队列并立即返回任务 ID，配合 `--wait` 可等待持久化任务完成，并根据最终结果返回相应的退出码

## 在线资源

```sh
zerobox --nogui resource sources
zerobox --nogui resource search calculator --source bandbbs --type quickapp
zerobox --nogui resource info bandbbs:6751
zerobox --nogui resource download bandbbs:6751
zerobox --nogui resource install bandbbs:6751
```

## 设备内容、账号与设置

```sh
zerobox --nogui app list
zerobox --nogui app launch com.example.app
zerobox --nogui app uninstall com.example.app
zerobox --nogui watchface list
zerobox --nogui watchface set FACE_ID
zerobox --nogui watchface remove FACE_ID
zerobox --nogui account list
zerobox --nogui account login amazfit --username user@example.com
zerobox --nogui account logout bandbbs
zerobox --nogui settings list
zerobox --nogui settings set auto_reconnect true
```

非交互式账号登录请使用 `--password-stdin`，ZeroBox 不接受通过命令行参数直接传入密码

## 队列、日志与机器可读输出

```sh
zerobox --nogui queue list
zerobox --nogui queue get TASK_ID
zerobox --nogui queue wait TASK_ID
zerobox --nogui queue watch
zerobox --nogui queue cancel TASK_ID
zerobox --nogui queue remove TASK_ID
zerobox --nogui logs watch
zerobox --nogui --json device status
```

指定 `--json` 后，命令结果以 JSON 输出，进度和事件以 JSONL 输出，CLI 退出码如下：

| 退出码 | 含义 |
| ---: | --- |
| 0 | 成功 |
| 2 | 用法或参数无效 |
| 3 | 文件错误 |
| 4 | 没有合适的设备 |
| 5 | 连接失败 |
| 6 | 资源校验失败 |
| 7 | 安装失败 |
| 8 | 守护进程错误 |
| 70 | 内部错误 |

## 移动端执行方式

Android 和 iOS 不会启动桌面式守护进程，而是在应用进程内执行相同的设备核心逻辑

Android 使用前台数据同步服务保护安装队列，iOS 使用系统提供的限时后台任务

移动端会持久化任务元数据，若操作因进程挂起而中断，任务会恢复为等待状态，供用户继续执行

共享命令协议本身不依赖桌面 IPC

## 桌面端架构

- 守护进程是桌面端唯一允许占用蓝牙传输通道的进程
- GUI 和 CLI 客户端通过守护进程接收 `device.state` 状态快照
- 设备操作会串行执行，避免协议请求相互重叠
- CLI 后台任务与 GUI 安装任务均由守护进程持久化，包括任务状态和进度
- Linux 的 Unix 套接字位于 `$XDG_RUNTIME_DIR/zerobox`，macOS 的套接字位于当前用户的 Application Support 目录，升级期间仍兼容旧版 `/tmp` 端点
- Windows 使用随机回环端口，并将单次运行认证令牌保存在当前用户的本地应用数据目录中，客户端发送命令前会通过认证握手验证守护进程身份和协议版本
