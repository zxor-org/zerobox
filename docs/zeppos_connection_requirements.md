# ZeppOS 设备连接要求与 ZeroBox 实现清单

本文以仓库内 `common/Gadgetbridge` 的 Huami / ZeppOS 实现为基准，记录 ZeppOS 设备从发现到可用连接所需的条件，并逐项对照 ZeroBox。本文只描述连接与协议要求，不表示所有 ZeppOS 功能已经可用。

## 1. 结论与边界

ZeppOS 平台层必须同时保留两类通道：

- BLE GATT：ZeppOS 2021 chunked 协议直接运行在 GATT characteristic 上。
- Classic Bluetooth RFCOMM / BTBR：连接华米专用 Serial Service，并先建立 BTBR 主会话和逻辑通道映射，再承载同一套 ZeppOS endpoint。

Web 只能承诺 BLE。Android、Linux、macOS、Windows 若要完整支持 ZeppOS，应同时实现 BLE 和 BTBR。协议层只依赖统一 `Transport`，不应直接调用平台 API。

## 2. Gadgetbridge 连接链路

### 2.1 发现与设备识别

Gadgetbridge 的 `HuamiCoordinator` 使用华米 BLE service 过滤器发现设备，各具体 ZeppOS coordinator 再通过名称、型号和设备类型完成识别。连接类型由设备能力及用户的强制连接类型设置决定，并选择：

- BLE：`ZeppOsBtleSupport`
- Classic：`ZeppOsBtbrSupport`

ZeroBox 不能只依赖设备名称。可靠识别应综合：

- 广播名称（Amazfit、Zepp、Mi Band 7 等已知系列）。
- 广播中的华米/Zepp service UUID。
- 已保存设备的 `DeviceKind.zepp`，避免重连时因名称变化退化成 Xiaomi。
- 扫描通道类型：BLE 或 Classic。

### 2.2 BLE GATT 条件

ZeppOS 2021 BLE 连接至少需要：

| 用途 | UUID |
|---|---|
| Firmware service（部分型号仅含 `1531/1532`） | `00001530-0000-3512-2118-0009af100700` |
| 手机写、设备读（chunked write） | `00000016-0000-3512-2118-0009af100700` |
| 设备写、手机读及 ACK（chunked read） | `00000017-0000-3512-2118-0009af100700` |

`0x16/0x17`的父服务不能写死为`1530`。真实ZeppOS设备可能将它们放在`FEE0`服务下；Gadgetbridge按characteristic UUID全局解析。ZeroBox也必须优先查预期服务、再跨全部已发现服务按UUID回退。

BLE 建链顺序：

1. 请求平台蓝牙权限并扫描。
2. 建立 GATT 连接。
3. 等待平台确认 connected。
4. 必要时进行系统配对；配对失败不应直接判定协议失败。
5. 发现 GATT services。
6. 验证 `0x16`、`0x17` characteristic 均存在。
7. 订阅 `0x17` notification。
8. 按协商 MTU 分包，通过 `0x16` 无响应写入。
9. 收到需要 ACK 的包时，将 `04 00 <handle> 01 <count>` 写到 `0x17`。
10. 开始 endpoint `0x0082` 认证。

### 2.3 ZeppOS 2021 chunked 帧

Gadgetbridge 对 ZeppOS 强制使用 extended header。首包布局为：

`03 flags 00 handle count payloadLength(u32le) endpoint(u16le) payload...`

后续包布局为：

`03 flags 00 handle count payload...`

Flags：

- `0x01`：首包
- `0x02`：尾包
- `0x04`：需要 ACK
- `0x08`：加密

每条消息递增 8 位 handle；多包消息必须按 handle/count 重组。认证阶段使用明文，认证成功后的敏感 endpoint 可使用 session key 加密。

### 2.4 authkey 认证

认证 endpoint 为 `0x0082`，流程来自 Gadgetbridge `ZeppOsAuthenticationService`：

1. 生成 24 字节随机私钥，并在 B-163 曲线上生成 48 字节小端公钥。
2. 发送 `04 02 00 02 + publicKey(48)`。
3. 设备响应 `10 04 01 + random(16) + remotePublicKey(48)`。
4. 使用 B-163 ECDH 计算 48 字节 shared secret。
5. 初始加密序号取 shared secret 的前 4 字节小端整数。
6. session key：`sharedSecret[8..24] XOR authkey[0..16]`。
7. 分别用 authkey 和 session key 对设备 random 做 AES-128 ECB/NoPadding 加密。
8. 发送 `05 + encryptedRandomByAuthKey(16) + encryptedRandomBySessionKey(16)`。
9. 设备响应 `10 05 01` 表示成功；状态 `0x25` 表示 authkey 错误。

authkey 规则：

- 标准形式为 32 个十六进制字符，可带 `0x` 前缀。
- 空 key 使用 Gadgetbridge 的兼容默认值 `0123456789@ABCDE`，但正式配对不应依赖默认值。
- 输入必须在连接前校验；非法 32 位 hex 应返回明确错误，不能只暴露 `FormatException`。
- 日志不得打印完整 authkey 或派生出的 session key。

### 2.5 BTBR / RFCOMM 条件

BTBR 使用的不是 Xiaomi 当前的标准 SPP UUID `00001101-0000-1000-8000-00805f9b34fb`，而是华米 Serial Service：

`00000022-0000-3512-2118-0009af100700`

平台连接器需要优先按 service UUID / SDP 建链，并可按已知 channel 回退。仅建立 RFCOMM socket 还不够，`ZeppOsBtbrSupport` 还实现了：

- BTBR communicator 帧解析与写入。
- 主会话建立、确认、结束及重连。
- 逻辑 characteristic UUID 与短 channel 的双向映射。
- 在逻辑 channel 上承载 ZeppOS 2021 chunked 数据。
- 设备互联 / 电话互联 endpoint `0x000b`（`ZeppOsPhoneService`）可运行在 BLE 或 BTBR communicator 上。

因此，在 BTBR communicator 和主会话完成前，不得把裸 RFCOMM stream 直接送入 `ZeppOsDeviceComponent`，也不得宣称 authkey 连接成功。

## 3. ZeroBox 当前对照

| 项目 | 当前状态 | 结论 / 后续工作 |
|---|---|---|
| 统一 `Transport` 抽象 | 已有 | `BleTransport` 与 `SppTransport` 已隔离平台 API。 |
| BLE 扫描 | 已有 | `universal_ble` 扫描可用；需持续补充广播 service UUID，使无典型名称设备也能识别。 |
| Classic 扫描 | 已有基础 | Android/Linux/macOS/Windows 有 MethodChannel runner；Web 不支持。 |
| ZeppOS 名称识别 | 已有基础 | 当前正则覆盖主流 Amazfit/Zepp/Mi Band 7，后续应转为设备目录而非继续扩大单个正则。 |
| BLE service 识别 | 部分 | `DeviceManager` 已能按 `1530` service 判定 ZeppOS，但 BLE driver 当前没有把广播 service 列表填入 endpoint。 |
| BLE GATT 连接 | 已有 | 已验证 `0x16`、`0x17`，订阅 read、写入 write。 |
| BLE MTU / 分包 | 部分 | 认证阶段不再错误调用系统 `requestMtu(23)`，协议按初始 MTU 23 分包；认证后动态 MTU 尚未实现。 |
| 2021 明文分包/重组 | 已有基础 | extended header、endpoint、ACK 已实现；需补 count 连续性、长度越界和乱序保护测试。 |
| authkey 解析 | 已有基础 | 支持 hex、`0x` 和兼容文本；需增加显式格式校验与脱敏日志。 |
| B-163 ECDH | 已实现 | Dart 自实现需用 Gadgetbridge 固定向量/交叉实现补充测试。 |
| AES challenge | 已实现 | AES-ECB/NoPadding 流程与 Gadgetbridge 一致。 |
| BLE authkey 连接 | 待真机验证 | 扫描 → GATT → 服务发现 → 订阅 → endpoint `0x0082` 已串联；各阶段已有独立超时，但不能在真机通过前标记完成。 |
| 加密 chunked 收发 | 未实现 | 当前认证后加密 payload 会抛 `UnsupportedError`；实现 session key、序号、CRC32、padding 和解密校验。 |
| BTBR service UUID 连接 | 已有基础 | profile 已传华米 UUID，并支持 channel fallback。各平台需逐一真机验证 SDP/UUID 行为。 |
| BTBR communicator | 未实现 | 当前 `SppTransport.zeppBtbr` 只是裸 stream 包装，必须新增 framing、会话和 channel 映射。 |
| BTBR authkey 连接 | 未实现 | 在 communicator 完成前保持禁用，避免错误连接状态。 |
| 连接探活/重连 | 部分 | 通用 watchdog 已有；ZeppOS 应改为协议级 ping/connection endpoint，而非依赖 Xiaomi 系统。 |
| 认证后二阶段初始化 | 未实现 | 获取支持的 endpoint/service 列表，再按能力初始化各 service。 |
| endpoint `0x000b` 电话互联 | 未实现 | 应作为上层 service，同时支持 BLE/BTBR communicator。 |
| 设备信息、电量、时间 | 未实现 | 优先实现认证后的最小可用闭环。 |
| 应用/表盘/文件传输 | 未实现 | 依赖 supported services、加密 chunked 和 file transfer v2/v3。 |

## 4. 分阶段实现清单

### P0：发现与 BLE authkey 连接

- [x] BLE 与 Classic 并行扫描（Web 仅 BLE）。
- [x] 根据名称、保存类型、连接类型识别设备。
- [x] ZeppOS BLE 必需 UUID 配置。
- [x] 订阅 `0x17`、写 `0x16`、向 `0x17` 回 ACK。
- [x] endpoint `0x0082` authkey 握手。
- [ ] 从 BLE 广播对象提取 service UUID 并用于无典型名称识别。
- [x] authkey 输入格式校验和日志脱敏。
- [ ] 用真实 ZeppOS 设备验证 Android/Linux/macOS/Windows 的 BLE 流程。
- [x] 增加 chunked 与认证 crypto 单元测试源码。

### P1：BLE 稳定连接

- [ ] 认证后动态 MTU / 最大写长度分包。
- [x] 分包乱序、截断、超长保护（重复包策略仍待补充）。
- [x] 认证超时后状态回滚并返回 endpoint 阶段错误。
- [ ] 实现 encrypted chunked 编解码、序号与 CRC32。
- [ ] supported services 查询及二阶段初始化。
- [ ] ZeppOS 专用探活和自动重连策略。

### P2：BTBR 可用连接

- [x] 平台 API 接收华米 Serial Service UUID 和 fallback channels。
- [ ] 逐平台验证 SDP/UUID 连接，不把固定 channel 当作唯一方案。
- [ ] 移植 BTBR communicator framing。
- [ ] 主会话建立、ACK、结束与重连。
- [ ] characteristic/channel 映射。
- [ ] 在 BTBR 逻辑 channel 上复用 endpoint 分发。
- [ ] BTBR authkey 认证及真机测试。

### P3：基础设备功能

- [ ] 支持服务列表、设备信息、电量、时间与时区。
- [ ] endpoint `0x000b` 连接/电话互联。
- [ ] 通知、音乐、天气、查找设备。
- [ ] 活动数据、心率及健康同步。

### P4：资源与高级功能

- [ ] 文件传输 v2/v3。
- [ ] 应用列表、安装、启动、卸载。
- [ ] 表盘列表、安装、删除。
- [ ] 固件、AGPS、地图、音乐等大文件传输。
- [ ] Wi-Fi、HTTP/FTP、语音备忘录等设备能力。

## 5. 当前需要的外部条件

继续把 P0/P1 做到可验证，需要维护者提供：

- 一台可测试的 ZeppOS 设备及其正确 16 字节 authkey（不要提交到仓库）。
- 设备型号、ZeppOS 版本、广播名称以及目标测试平台。
- 一段脱敏连接日志；保留 UUID、包长度、状态码和十六进制协议包，删除 MAC/authkey/session key。
- 若测试 BTBR：设备已开启对应的“电话互联/设备互联”能力，并允许系统 Bluetooth Classic 配对。

不需要下载额外 Gadgetbridge；本仓库内的 `common/Gadgetbridge` 已足够作为当前实现依据。
