// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'ZeroBox';

  @override
  String get homeTab => '首页';

  @override
  String get exploreTab => '探索';

  @override
  String get devicesTab => '设备';

  @override
  String get pluginsTab => '插件';

  @override
  String get pluginImport => '导入插件';

  @override
  String get pluginInstalled => '已安装';

  @override
  String get pluginMarket => '插件市场';

  @override
  String get pluginMarketUnavailable => '插件市场暂未接入';

  @override
  String get pluginEmpty => '尚未安装插件';

  @override
  String get pluginSelectHint => '选择一个插件查看功能';

  @override
  String get pluginFeatures => '功能';

  @override
  String get pluginDetails => '详情';

  @override
  String get pluginNoFeatures => '此插件没有可用功能';

  @override
  String get pluginAuthor => '作者';

  @override
  String get pluginVersion => '版本';

  @override
  String get pluginApiLevel => 'API 级别';

  @override
  String get pluginWebsite => '网站';

  @override
  String get pluginPermissions => '权限';

  @override
  String get pluginInstallConfirmTitle => '插件安装确认';

  @override
  String get pluginUpdateConfirmTitle => '插件更新确认';

  @override
  String get pluginDeclaredPermissions => '此插件声明了以下权限：';

  @override
  String get pluginNoPermissions => '未声明任何权限';

  @override
  String get pluginUpToDate => '已安装且为最新版本';

  @override
  String get pluginUninstallTitle => '卸载插件';

  @override
  String get pluginUninstallMessage => '插件数据也将被删除';

  @override
  String get settingsTab => '设置';

  @override
  String get search => '搜索';

  @override
  String get refresh => '刷新';

  @override
  String get notifications => '通知';

  @override
  String get pendingTasks => '待处理任务';

  @override
  String get manageDevice => '管理设备';

  @override
  String get installLocalResource => '安装本地资源';

  @override
  String get recentUpdates => '最近更新';

  @override
  String get newlyPublished => '最新发布';

  @override
  String get news => '资讯';

  @override
  String get zeroBoxNews => 'ZeroBox 资讯';

  @override
  String get bandbbsNews => 'BandBBS 资讯';

  @override
  String get astroBoxNews => 'AstroBox 资讯';

  @override
  String get resourceLibrary => '资源库';

  @override
  String get creatorCenter => '创作者中心';

  @override
  String get filter => '筛选';

  @override
  String get importLocalResource => '导入本地资源';

  @override
  String get allDevices => '全部设备';

  @override
  String get currentDevice => '当前设备';

  @override
  String get all => '全部';

  @override
  String get watchfaces => '表盘';

  @override
  String get quickApps => '快应用';

  @override
  String get firmwareTools => '固件 / 工具';

  @override
  String get resourceTypeFontpack => '字体包';

  @override
  String get resourceTypeIconpack => '图标包';

  @override
  String get localResources => '本地资源';

  @override
  String get zeroBox => 'ZeroBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => '本地';

  @override
  String get install => '安装';

  @override
  String get update => '更新';

  @override
  String get manage => '管理';

  @override
  String get description => '描述';

  @override
  String get supportedDevices => '支持的设备';

  @override
  String get downloads => '下载包';

  @override
  String get changelog => '更新日志';

  @override
  String get notFound => '未找到';

  @override
  String get downloadStarted => '开始下载';

  @override
  String get compatible => '兼容';

  @override
  String get incompatible => '不兼容';

  @override
  String get incompatibleSuffix => '，可能无法正常使用';

  @override
  String get openSourcePage => '开源页面';

  @override
  String get creatorDashboard => '创作者仪表盘';

  @override
  String get myResources => '我的资源';

  @override
  String get drafts => '草稿';

  @override
  String get pendingReview => '审核中';

  @override
  String get published => '已发布';

  @override
  String get failed => '失败 / 需处理';

  @override
  String get newResource => '新建资源';

  @override
  String get basicInfo => '基本信息';

  @override
  String get packageFiles => '包文件';

  @override
  String get deviceSelection => '选择设备';

  @override
  String get deviceFileMapping => '设备-文件映射';

  @override
  String get publishTargets => '发布目标';

  @override
  String get publishPreview => '发布预览';

  @override
  String get reviewStatus => '审核状态';

  @override
  String get scan => '扫描';

  @override
  String get logs => '日志';

  @override
  String get connectedDevices => '已连接设备';

  @override
  String get pairedDevices => '已配对设备';

  @override
  String get discoveredDevices => '发现设备';

  @override
  String get overview => '概览';

  @override
  String get apps => '应用';

  @override
  String get connection => '连接';

  @override
  String get protocol => '协议';

  @override
  String get error => '错误';

  @override
  String get errorBluetoothUnavailable =>
      '蓝牙不可用，请检查蓝牙是否已开启，并确认系统权限已允许 ZeroBox 使用蓝牙';

  @override
  String get errorBluetoothConnectFailed =>
      '蓝牙连接失败，请确认设备在附近、未被其他程序占用，并尝试重新开启蓝牙';

  @override
  String get errorBluetoothDisconnected => '蓝牙连接已断开，请重新连接设备';

  @override
  String get errorOperationTimeout => '操作超时，请确认设备仍在附近并重试';

  @override
  String get errorDeviceNotReady => '设备尚未准备好，请先连接并完成认证';

  @override
  String get errorBleCharacteristicsMissing =>
      '未找到需要的 BLE 通道，请重新连接设备或检查设备是否支持该功能';

  @override
  String get errorWebSerialUnavailable =>
      '当前浏览器不支持 Web Serial，请使用 Chrome / Edge 等支持 Web Serial 的浏览器';

  @override
  String get errorAccountPasswordIncorrect => '小米账号或密码错误';

  @override
  String get errorAccountTwoFactorIncomplete => '小米账号二次验证未完成，请重新登录';

  @override
  String get errorUnsupportedFileType => '不支持或无法识别的文件类型';

  @override
  String get errorCertificateVerificationFailed =>
      '证书校验失败，如果正在使用代理，请关闭对本应用的 HTTPS 接管，或确认 Flutter/Dart 能信任其证书';

  @override
  String errorUnknownWithDetail(Object detail) {
    return '操作失败：$detail';
  }

  @override
  String get copyLogs => '复制日志';

  @override
  String get exportLogs => '导出日志';

  @override
  String get clearLogs => '清空日志';

  @override
  String get personalCenter => '个人中心';

  @override
  String get accountAndPublishing => '账号与发布';

  @override
  String get appearance => '外观';

  @override
  String get resources => '资源';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox Repo';

  @override
  String get communitySourceBandBbs => '米坛社区';

  @override
  String get communitySourceHuamiAppStore => '华米应用商店';

  @override
  String get devices => '设备';

  @override
  String get categories => '分区';

  @override
  String get advanced => '高级';

  @override
  String get aboutZeroBox => '关于 ZeroBox';

  @override
  String get openSourceLicenses => '开放源代码许可';

  @override
  String get acknowledgements => '特别鸣谢';

  @override
  String get acknowledgementsDesc => '查看 ZeroBox 参考与致谢的开源项目';

  @override
  String get developmentTeam => '开发团队';

  @override
  String get deviceNotConnected => '未连接';

  @override
  String get deviceConnected => '已连接';

  @override
  String get deviceDisconnected => '已断开';

  @override
  String get deviceReconnect => '重新连接';

  @override
  String get deviceConnect => '连接设备';

  @override
  String get deviceSwitch => '切换设备';

  @override
  String get deviceCharging => '充电中';

  @override
  String get deviceFeaturesInstallApp => '安装应用';

  @override
  String get deviceFeaturesInstallAppDesc => '从本地文件安装第三方应用';

  @override
  String get deviceFeaturesInstallWatchface => '安装表盘';

  @override
  String get deviceFeaturesInstallWatchfaceDesc => '从本地文件安装表盘';

  @override
  String get deviceFeaturesInstallFirmware => '安装固件';

  @override
  String get deviceFeaturesInstallFirmwareDesc => '刷写固件或工具包';

  @override
  String get deviceFeaturesManageApps => '管理应用';

  @override
  String get deviceFeaturesManageAppsDesc => '查看并卸载已安装的应用';

  @override
  String get deviceFeaturesManageWatchfaces => '管理表盘';

  @override
  String get deviceFeaturesManageWatchfacesDesc => '查看、删除并设置当前表盘';

  @override
  String get zeppOsMoreFeatures => 'Zepp OS 专区';

  @override
  String get zeppOsMoreFeaturesDescription => '探索你的 Zepp OS 设备';

  @override
  String get zeppOsFindDevice => '查找设备';

  @override
  String get zeppOsFindDeviceDescription => '让设备持续振动或响铃，方便在附近快速找到它。';

  @override
  String get zeppOsFindDeviceStart => '开始查找';

  @override
  String get zeppOsFindDeviceStop => '停止查找';

  @override
  String get deviceFeaturesDeviceInfo => '设备信息';

  @override
  String get deviceFeaturesDeviceInfoDesc => '固件、存储空间与详情';

  @override
  String get switchDeviceTitle => '切换设备';

  @override
  String get savedDevices => '已配对设备';

  @override
  String get scanAndAdd => '扫描并添加';

  @override
  String get scanNotFound => '未发现设备';

  @override
  String get noSavedDevices => '没有已配对设备';

  @override
  String get authkey => '认证密钥';

  @override
  String get authkeyPrompt => '输入设备认证密钥';

  @override
  String get authkeyPlaceholder => '认证密钥';

  @override
  String get connectFailed => '连接失败';

  @override
  String deviceConnectingTo(String deviceName) {
    return '正在连接 $deviceName…';
  }

  @override
  String get deviceConnectionPreparing => '正在准备连接…';

  @override
  String deviceConnectionEstablishing(String transport) {
    return '正在建立 $transport 连接…';
  }

  @override
  String get deviceConnectionInitializing => '正在初始化设备协议…';

  @override
  String get deviceConnectionAuthenticating => '正在认证设备…';

  @override
  String get deviceConnectionFetchingStatus => '正在读取设备信息…';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown => '未识别设备';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint =>
      '在网页端，ZeroBox 通过 Web Serial 连接设备，已保存的设备会保留在当前浏览器中';

  @override
  String get webSerialConnectDialogTitle => '通过 Web Serial 连接';

  @override
  String get webSerialConnectDialogHint =>
      '输入设备认证密钥，并在浏览器弹窗中选择串口，认证密钥会保存在当前浏览器中';

  @override
  String get cancel => '取消';

  @override
  String get deviceActionsDelete => '删除';

  @override
  String get deviceActionsDisconnect => '断开连接';

  @override
  String get deviceActionsShareQR => '分享二维码';

  @override
  String get deviceShareZeroBoxCode => '切换为 ZeroBox 码';

  @override
  String get deviceShareAstroBoxCompatibleCode => '切换 AstroBox 兼容码';

  @override
  String get installTapToSelectFile => '点击选择文件';

  @override
  String get installPackageName => '包名';

  @override
  String get installWatchfaceId => '表盘 ID';

  @override
  String get deviceInfoTitle => '设备信息';

  @override
  String get deviceInfoGroupDevice => '设备';

  @override
  String get deviceInfoGroupSystem => '系统';

  @override
  String get deviceInfoGroupStatus => '状态';

  @override
  String get fieldName => '名称';

  @override
  String get fieldAddress => '地址';

  @override
  String get fieldAuthkey => '认证密钥';

  @override
  String get fieldConnectionType => '连接类型';

  @override
  String get fieldCodename => '代号';

  @override
  String get fieldModel => '型号';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => '固件';

  @override
  String get fieldSerial => '序列号';

  @override
  String get fieldBattery => '电量';

  @override
  String get fieldChargeStatus => '充电状态';

  @override
  String get fieldLastCharge => '上次充电';

  @override
  String get fieldStorage => '存储空间';

  @override
  String get appManagementTitle => '应用管理';

  @override
  String get appManagementNone => '没有已安装的应用';

  @override
  String get appManagementShowSystemApps => '显示系统应用';

  @override
  String get watchfaceManagementTitle => '表盘管理';

  @override
  String get watchfaceManagementNone => '没有已安装的表盘';

  @override
  String get open => '打开';

  @override
  String get externalLinkTitle => '跳转外部链接';

  @override
  String externalLinkDescription(String url) {
    return '即将跳转到 $url\n\n该网站由第三方运营，与 ZeroBox 没有从属关系，安全性未知，请注意辨别，是否继续访问？';
  }

  @override
  String get externalLinkAstroBoxResourceHint =>
      '这似乎是一个 AstroBox 资源，您也可以在 ZeroBox内访问并安装';

  @override
  String get continueToWebsite => '继续访问';

  @override
  String get viewInZeroBox => '在 ZeroBox 中查看';

  @override
  String get uninstall => '卸载';

  @override
  String get enable => '设为当前';

  @override
  String get fail => '失败';

  @override
  String get show => '显示';

  @override
  String get hide => '隐藏';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get close => '关闭';

  @override
  String get desktopTrayShow => '显示窗口';

  @override
  String get desktopTrayExit => '退出 ZeroBox';

  @override
  String get desktopCloseTitle => '退出确认';

  @override
  String get desktopCloseMessage => '您想要退出 ZeroBox 吗？';

  @override
  String get desktopCloseRemember => '下次不再询问';

  @override
  String get desktopCloseToTray => '最小化到托盘';

  @override
  String get desktopCloseExit => '退出 ZeroBox';

  @override
  String get settingsDesktopCloseBehavior => '关闭按钮行为';

  @override
  String get settingsDesktopCloseBehaviorDesc => '选择关闭主窗口时执行的操作';

  @override
  String get desktopCloseBehaviorAsk => '每次询问';

  @override
  String get desktopCloseBehaviorExit => '直接退出';

  @override
  String get desktopCloseBehaviorTray => '最小化到托盘';

  @override
  String get multiDevice => '多设备';

  @override
  String get quickApp => '快应用';

  @override
  String get miniprogram => '小程序';

  @override
  String get miniprograms => '小程序';

  @override
  String get watchface => '表盘';

  @override
  String get firmwareTool => '固件 / 工具';

  @override
  String get fontPack => '字体包';

  @override
  String get iconPack => '图标包';

  @override
  String get free => '免费';

  @override
  String get paid => '付费';

  @override
  String get forcePaid => '强制付费';

  @override
  String get version => '版本';

  @override
  String get noDescription => '暂无描述';

  @override
  String get preview => '预览';

  @override
  String get productAbout => '关于';

  @override
  String get productDeviceRequirements => '系统要求';

  @override
  String get productOtherVersions => '其他版本';

  @override
  String get productInQueue => '已在队列';

  @override
  String get productShare => '分享';

  @override
  String get productViewOnBandBBS => '在米坛查看';

  @override
  String get changeCdn => '切换 CDN';

  @override
  String get cdnErrorTitle => 'AstroBox 数据加载失败';

  @override
  String cdnErrorMessage(Object cdn, Object path) {
    return '当前 CDN（$cdn）无法获取 $path，是否切换 CDN？';
  }

  @override
  String get cdnErrorContinue => '切换 CDN';

  @override
  String get cdnErrorCancel => '取消';

  @override
  String get settingsAccount => '账号';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsSource => '下载';

  @override
  String get settingsSourceRestart => '重启后生效';

  @override
  String get settingsQueue => '队列';

  @override
  String get settingsInstall => '安装';

  @override
  String get settingsTools => '神秘工具';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAccountLoginBBS => '登录 BandBBS';

  @override
  String get settingsAccountLoginBBSDesc => '登录以同步已购资源';

  @override
  String get settingsAccountBandBbsSigningIn => '正在登录';

  @override
  String get settingsAccountBandBbsOpenedBrowser => '已打开浏览器，请完成 BandBBS 授权';

  @override
  String get settingsAccountBandBbsSignedIn => 'BandBBS 登录成功';

  @override
  String get settingsAccountBandBbsLoginFailed => 'BandBBS 登录失败';

  @override
  String get settingsBandBbsAccountRequired => '请先在设置中登录米坛账号';

  @override
  String settingsAccountBandBbsUser(Object userId) {
    return '用户 ID：$userId';
  }

  @override
  String get settingsAccountBBSAccount => '米坛账号';

  @override
  String get bandBbsAccountTitle => '米坛账号';

  @override
  String get bandBbsPurchasedResources => '已购资源';

  @override
  String get bandBbsResourceId => '资源 ID';

  @override
  String get bandBbsResourceIdHint => '输入米坛资源 ID';

  @override
  String get bandBbsQueryResource => '查询';

  @override
  String get bandBbsOpenResource => '在米坛查看';

  @override
  String get bandBbsLogout => '退出登录';

  @override
  String get bandBbsLoggedOut => '已退出登录';

  @override
  String get bandBbsLoadPreviews => '加载资源帖预览图';

  @override
  String get bandBbsLoadPreviewsDesc => '在资源列表中自动加载帖子附件预览图';

  @override
  String get bandBbsShowAllCategories => '显示所有资源分区';

  @override
  String get bandBbsShowAllCategoriesDesc => '包含默认隐藏的未适配设备分区';

  @override
  String get settingsAccountSyncDevices => '同步设备';

  @override
  String get settingsAccountSyncDevicesDesc => '登录小米账号同步配对设备';

  @override
  String get settingsMiAccount => '小米账号';

  @override
  String get settingsMiAccountDesc => '登录并同步已绑定设备 authkey';

  @override
  String get settingsMiAccountLoginTitle => '小米账号登录';

  @override
  String get settingsMiAccountUsername => '账号';

  @override
  String get settingsMiAccountPassword => '密码';

  @override
  String get settingsMiAccountRememberCredentials => '记住账号密码';

  @override
  String get settingsMiAccountLoginAndSync => '登录并同步';

  @override
  String get settingsMiAccountMissingCredentials => '请输入小米账号和密码';

  @override
  String get settingsMiAccountTwoFactorPrompt => '请在验证页面完成小米账号二次验证';

  @override
  String get settingsMiAccountLoginWindowClosed => '登录窗口已关闭';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return '已同步 $count 台小米设备';
  }

  @override
  String get settingsHuamiAccount => '华米账号';

  @override
  String get settingsHuamiAccountDesc => '登录并保存访问 Zepp 商店所需凭据';

  @override
  String get settingsHuamiAccountSigningIn => '正在登录';

  @override
  String get settingsHuamiAccountSignedIn => '华米账号登录成功';

  @override
  String settingsHuamiAccountUser(Object username) {
    return '账号：$username';
  }

  @override
  String get settingsHuamiAccountLoginTitle => '华米账号登录';

  @override
  String get settingsHuamiAccountUsername => '账号';

  @override
  String get settingsHuamiAccountPassword => '密码';

  @override
  String get settingsHuamiAccountRememberCredentials => '记住密码';

  @override
  String get settingsHuamiAccountLoginAndSave => '登录并保存';

  @override
  String get settingsHuamiAccountMissingCredentials => '请输入华米账号和密码';

  @override
  String get settingsHuamiAccountRequired => '请先在设置中登录华米账号';

  @override
  String get unsupportedDeviceResourceTitle => '尚未支持的设备/资源类型';

  @override
  String get unsupportedDeviceResourceMessage =>
      'ZeroBox 暂不支持此设备或资源类型，请勿尝试安装该分区中的资源，以免出现不可预期的问题';

  @override
  String get understood => '我知道了';

  @override
  String get settingsGeneralLanguage => '语言';

  @override
  String get settingsGeneralLanguageDesc => '更改应用显示语言';

  @override
  String get settingsWideNavigationPosition => '导航位置';

  @override
  String get settingsWideNavigationPositionDesc => '调整宽屏状态下侧边标签的位置';

  @override
  String get settingsWideNavigationPositionBottom => '置底';

  @override
  String get settingsWideNavigationPositionCenter => '居中';

  @override
  String get settingsWideNavigationPositionSplit => '分离';

  @override
  String get settingsGeneralTranslateTeam => '翻译贡献者';

  @override
  String get settingsAutoReconnectTitle => '自动回连';

  @override
  String get settingsAutoReconnectDesc => '启动时自动连接上次配对的设备';

  @override
  String get settingsGeneralDebugWindow => '调试窗口';

  @override
  String get settingsGeneralDebugWindowDesc => '显示悬浮调试面板';

  @override
  String get settingsSourceOfficialCdn => 'GitHub 源 CDN';

  @override
  String get settingsSourceOfficialCdnDesc => '获取托管在 GitHub 上的社区索引使用的 CDN';

  @override
  String get settingsQueueAutoInstall => '自动安装';

  @override
  String get settingsQueueAutoInstallDesc => '下载完成后自动开始安装';

  @override
  String get settingsQueueDontClear => '不清除安装队列';

  @override
  String get settingsQueueDontClearDesc => '保留已完成的安装队列项';

  @override
  String get settingsInstallSendInterval => '分包间隔';

  @override
  String get settingsInstallSendIntervalDesc => '安装时蓝牙分包发送延迟';

  @override
  String get settingsToolsUnlockCode => '计算解锁码';

  @override
  String get settingsToolsUnlockCodeDesc => '通过 MAC 和 SN 生成小米穿戴解锁码';

  @override
  String get settingsToolsDialogTitle => '解锁码';

  @override
  String get settingsToolsMac => 'MAC 地址';

  @override
  String get settingsToolsSn => '序列号';

  @override
  String get settingsToolsNoticeTitle => '警告';

  @override
  String get settingsToolsNoticeBody => '解锁可能导致保修失效或数据丢失，请自行承担风险';

  @override
  String get settingsToolsAgree => '我已了解风险';

  @override
  String get settingsToolsCalculate => '计算';

  @override
  String get settingsToolsResult => '结果';

  @override
  String get settingsToolsDialogUsage => '用法';

  @override
  String get settingsToolsDialogUsageInfo => '输入设备上显示的 MAC 地址和序列号';

  @override
  String get settingsAboutAboutAstrobox => '关于 ZeroBox';

  @override
  String get settingsAboutAboutAstroboxDesc => '版本、更新日志和团队';

  @override
  String get settingsAboutDisclaimer => '免责声明';

  @override
  String get settingsAboutDisclaimerDesc => '用户协议与责任声明';

  @override
  String get settingsAboutOpenlog => '日志文件夹';

  @override
  String get settingsAboutOpenlogDesc => '在文件管理器中打开日志目录';

  @override
  String get settingsAboutWebsite => '官方网站';

  @override
  String get settingsAboutWebsiteDesc => '访问 zerobox.zxor.org';

  @override
  String get settingsAboutQQ => 'QQ 群';

  @override
  String get settingsAboutQQDesc => '加入社区群聊';

  @override
  String get settingsAboutLicences => '开放源代码许可';

  @override
  String get settingsAboutLicencesDesc => '查看 Flutter、依赖库与开源组件许可证';

  @override
  String get settingsGuest => '访客';

  @override
  String get settingsTapToSignIn => '点击登录';

  @override
  String get settingsConnected => '已连接';

  @override
  String get settingsNotConnected => '未连接';

  @override
  String get settingsNotSet => '未设置';

  @override
  String get settingsOn => '开启';

  @override
  String get settingsOff => '关闭';

  @override
  String get settingsSystem => '跟随系统';

  @override
  String get settingsLight => '浅色';

  @override
  String get settingsDark => '深色';

  @override
  String get settingsOledDark => 'OLED 深色';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsThemeModeDesc => '更改应用主题外观';

  @override
  String get settingsDynamicColor => '动态取色';

  @override
  String get settingsDynamicColorDesc => '使用系统主题色调整应用配色';

  @override
  String get settingsColorScheme => '配色方案';

  @override
  String get settingsColorSchemeDesc => '选择应用主题色';

  @override
  String get settingsColorSchemePink => '粉色';

  @override
  String get settingsColorSchemePurple => '紫色';

  @override
  String get settingsColorSchemeTeal => '青色';

  @override
  String get settingsColorSchemeGreen => '绿色';

  @override
  String get settingsColorSchemeRed => '红色';

  @override
  String get settingsColorSchemeAmber => '琥珀色';

  @override
  String get settingsDesktopAccentSource => 'Linux 主题色来源';

  @override
  String get settingsDesktopAccentSourceDesc => '选择从 GTK 或 Qt 读取主题色';

  @override
  String get settingsDesktopAccentSourceSystem => '自动';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsConfirm => '确认';

  @override
  String get settingsOpen => '打开';

  @override
  String get settingsVisit => '访问';

  @override
  String get settingsTeamSlogan => '一款面向 VelaOS 与 ZeppOS 的可穿戴设备管理工具';

  @override
  String get settingsTeamGitHub => 'GitHub 仓库';

  @override
  String get settingsTeamMembers => '团队成员';

  @override
  String get settingsTeamRoleMain => '主开发 / 设计';

  @override
  String get settingsTeamRoleZeppOS => 'ZeppOS 实现';

  @override
  String get settingsAboutSoftware => '关于软件';

  @override
  String get settingsAboutSoftwareDesc => '版本、更新日志与开发团队';

  @override
  String get settingsAboutSoftwareTagline =>
      '一个又好看又快的 VelaOS / ZeppOS 可穿戴设备管理软件，使用 Flutter 构建';

  @override
  String get settingsAboutSoftwareRepository => '打开 GitHub 仓库';

  @override
  String get settingsAboutSoftwareTeam => '开发团队';

  @override
  String get settingsAboutSoftwareReleaseName => '当前版本：开发预览';

  @override
  String get settingsAboutSoftwareReleaseBody =>
      '本次更新内容包括：\n• 新增系统强调色支持与主题细节优化\n• 重构资源详情页与列表页，支持按设备分组筛选\n• 用“关于软件”页替换原“团队页”；设置页全面国际化\n• 优化小米 SAR 控制器发送失败错误处理\n• 稳定 Linux 经典 SPP 连接的取消与超时行为\n• 更新 ARB 本地化文案与生成的 l10n 文件';

  @override
  String get settingsAboutSoftwareBuildInfo => '构建信息';

  @override
  String get settingsAboutSoftwareCopyright =>
      'Copyright © ZeroBox contributors';

  @override
  String get acknowledgementsKazumi => 'Material Design 组件与界面设计参考';

  @override
  String get acknowledgementsAstroBoxPublic => '界面结构、资源流程与交互设计参考';

  @override
  String get acknowledgementsAstroBoxNgCore => '小米设备协议、安装流程与传输行为参考';

  @override
  String get acknowledgementsAstroBoxNgBluetooth => '蓝牙连接行为参考';

  @override
  String get acknowledgementsAstroBoxNgAccount => '小米账号登录、设备同步与 authkey 获取流程参考';

  @override
  String get acknowledgementsAstroBoxNgProvider => '社区资源索引、CDN 与清单解析流程参考';

  @override
  String get acknowledgementsAstroBoxNgAppWasm => 'Web Serial 与浏览器端连接流程参考';

  @override
  String get acknowledgementsGadgetbridge => 'ZeppOS 与可穿戴设备协议研究参考';

  @override
  String get resourceHomeEmptyTitle => '首页未完成';

  @override
  String get resourceHomeEmptySubtitle => '您可以在资源库获取资源';

  @override
  String get resourceCreatorEmptyTitle => '创作者中心未完成';

  @override
  String get resourceCreatorEmptySubtitle => '您可以在资源库管理已获取资源';

  @override
  String get openResourceLibrary => '打开资源库';

  @override
  String get downloadQueueTitle => '下载队列';

  @override
  String get installQueueTitle => '安装队列';

  @override
  String get queueClear => '清空';

  @override
  String get queueStart => '开始';

  @override
  String get queuePause => '暂停';

  @override
  String get downloadQueueEmpty => '暂无下载任务';

  @override
  String get installQueueEmpty => '暂无安装任务';

  @override
  String get localAppInstall => '本地应用安装';

  @override
  String get localWatchfaceInstall => '本地表盘安装';

  @override
  String get localFirmwareInstall => '本地固件安装';

  @override
  String get queueStatusPending => '等待中';

  @override
  String queueStatusDownloading(String percent) {
    return '下载中 $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return '安装中 $percent%';
  }

  @override
  String get queueStatusCompleted => '已完成';

  @override
  String get queueStatusFailed => '失败';

  @override
  String get queueDragToInstall => '松开以加入安装队列';

  @override
  String queueAddedFiles(int count) {
    return '已加入安装队列：$count 个文件';
  }

  @override
  String get installQueueReadFailed => '读取失败';

  @override
  String get installQueueUnsupportedFile => '不支持的文件';

  @override
  String timeTodayAt(Object time) {
    return '今天 $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return '昨天 $time';
  }

  @override
  String get settingsAccountBandBbsAccount => '米坛账号';

  @override
  String get bandBbsResourceQueryTitle => '安装已购付费资源';

  @override
  String get settingsAboutLogs => '日志';

  @override
  String get settingsAboutLogsDescription =>
      '保留最近 7 天的运行日志，Android 可在系统“文件”应用中查看和复制';

  @override
  String get settingsAboutLogsOpen => '打开日志文件夹';

  @override
  String get settingsAboutLogsOpenFailed => '无法打开日志文件夹';

  @override
  String get settingsAboutLogsWarningTitle => '敏感信息警告';

  @override
  String get settingsAboutLogsWarningMessage =>
      '日志可能包含米坛/小米/华米登录凭证等敏感信息，请勿随意分享给除 ZeroBox 官方维护者以外的其他人！';

  @override
  String get pluginPermissionRequestTitle => '插件权限请求';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return '“$plugin”希望$operation。';
  }

  @override
  String get pluginPermissionOnce => '允许本次';

  @override
  String get pluginPermissionSession => '本次运行中允许';

  @override
  String get pluginPermissionAlways => '始终允许';

  @override
  String get pluginPermissionDeny => '拒绝';

  @override
  String get pluginPermissionOpenExternal => '打开外部链接';

  @override
  String get pluginPermissionPickFile => '访问宿主文件';

  @override
  String get pluginPermissionExportFile => '将文件导出到宿主环境';

  @override
  String get pluginPermissionNetwork => '访问网络';

  @override
  String get pluginPermissionInterconnect => '与设备应用通信';

  @override
  String get pluginPermissionProvider => '注册资源源';

  @override
  String get pluginPermissionReadDevice => '读取设备信息';

  @override
  String get pluginPermissionOperateDevice => '操作设备';

  @override
  String get pluginPermissionObserveProtocol => '读取设备原始协议数据';

  @override
  String get pluginPermissionSendProtocol => '向设备发送原始协议数据';

  @override
  String get pluginErrorTitle => '插件运行错误';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return '“$plugin”运行时发生错误：\n\n$error';
  }

  @override
  String get pluginErrorClearData => '清除插件数据';

  @override
  String get pluginErrorUninstall => '卸载插件';

  @override
  String get pluginErrorSafeMode => '进入安全模式';

  @override
  String get pluginSafeModeTitle => '插件安全模式已启用';

  @override
  String get pluginSafeModeDescription => '所有插件均已停止，退出安全模式后才会重新加载。';

  @override
  String get pluginSafeModeExit => '退出安全模式';

  @override
  String get debugWindow => '调试窗口';

  @override
  String get debugWindowDescription => '是否启用 ZeroBox 调试窗口';

  @override
  String get debugWindowOperationFailed => '无法更改调试窗口状态';

  @override
  String get resourceTypeErrorTitle => '错误的资源类型';

  @override
  String get resourceTypeUnknownTitle => '无法识别的资源类型';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return '这似乎是一个$detectedType资源，但您选择的资源类型为$selectedType，请选择安装方式';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return '这似乎是一个 $resourcePlatform 设备的$resourceType资源，当前连接的设备为 $deviceName（$devicePlatform），不支持安装，强行安装可能引发不可预知的问题';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return 'ZeroBox 无法识别此文件的实际资源类型，是否仍以$selectedType安装？';
  }

  @override
  String get resourceInstallCancel => '取消安装';

  @override
  String get resourceInstallAcknowledge => '我知道了';

  @override
  String get resourceInstallForce => '强制安装';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return '强制安装 (${seconds}s)';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return '继续以$type安装';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return '继续以$type安装 (${seconds}s)';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return '以$type安装';
  }

  @override
  String get resourceTypeApp => '小程序';

  @override
  String get resourceTypeQuickApp => '快应用';

  @override
  String get resourceTypeWatchface => '表盘';

  @override
  String get resourceTypeFirmware => '固件';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return '安装$type';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return '确认要安装 $fileName（$fileSize）吗？';
  }

  @override
  String get resourceInstallConfirm => '确认安装';
}
