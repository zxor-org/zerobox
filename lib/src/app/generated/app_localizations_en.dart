// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZeroBox';

  @override
  String get homeTab => 'Home';

  @override
  String get exploreTab => 'Explore';

  @override
  String get devicesTab => 'Devices';

  @override
  String get pluginsTab => 'Plugins';

  @override
  String get pluginImport => 'Import plugin';

  @override
  String get pluginInstalled => 'Installed';

  @override
  String get pluginMarket => 'Plugin market';

  @override
  String get pluginMarketUnavailable =>
      'The plugin market is not available yet';

  @override
  String get pluginEmpty => 'No plugins installed';

  @override
  String get pluginSelectHint => 'Select a plugin to view its features';

  @override
  String get pluginFeatures => 'Features';

  @override
  String get pluginDetails => 'Details';

  @override
  String get pluginNoFeatures => 'This plugin has no available features';

  @override
  String get pluginAuthor => 'Author';

  @override
  String get pluginVersion => 'Version';

  @override
  String get pluginApiLevel => 'API level';

  @override
  String get pluginWebsite => 'Website';

  @override
  String get pluginPermissions => 'Permissions';

  @override
  String get pluginInstallConfirmTitle => 'Confirm plugin installation';

  @override
  String get pluginUpdateConfirmTitle => 'Confirm plugin update';

  @override
  String get pluginDeclaredPermissions =>
      'This plugin declares the following permissions:';

  @override
  String get pluginNoPermissions => 'No permissions declared';

  @override
  String get pluginUpToDate => 'Installed and up to date';

  @override
  String get pluginUninstallTitle => 'Uninstall plugin';

  @override
  String get pluginUninstallMessage =>
      'The plugin\'s data will also be removed';

  @override
  String get settingsTab => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get refresh => 'Refresh';

  @override
  String get notifications => 'Notifications';

  @override
  String get pendingTasks => 'Pending tasks';

  @override
  String get manageDevice => 'Manage device';

  @override
  String get installLocalResource => 'Install local resource';

  @override
  String get recentUpdates => 'Recent updates';

  @override
  String get newlyPublished => 'Newly published';

  @override
  String get news => 'News';

  @override
  String get zeroBoxNews => 'ZeroBox news';

  @override
  String get bandbbsNews => 'BandBBS news';

  @override
  String get astroBoxNews => 'AstroBox news';

  @override
  String get resourceLibrary => 'Resource library';

  @override
  String get creatorCenter => 'Creator center';

  @override
  String get filter => 'Filter';

  @override
  String get importLocalResource => 'Import local resource';

  @override
  String get allDevices => 'All devices';

  @override
  String get currentDevice => 'Current device';

  @override
  String get all => 'All';

  @override
  String get watchfaces => 'Watchface';

  @override
  String get quickApps => 'Quickapps';

  @override
  String get firmwareTools => 'Firmware / Tools';

  @override
  String get resourceTypeFontpack => 'Font pack';

  @override
  String get resourceTypeIconpack => 'Icon pack';

  @override
  String get localResources => 'Local resources';

  @override
  String get zeroBox => 'ZeroBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => 'Local';

  @override
  String get install => 'Install';

  @override
  String get update => 'Update';

  @override
  String get manage => 'Manage';

  @override
  String get description => 'Description';

  @override
  String get supportedDevices => 'Supported devices';

  @override
  String get downloads => 'Downloads';

  @override
  String get changelog => 'Changelog';

  @override
  String get notFound => 'Not found';

  @override
  String get downloadStarted => 'Download started';

  @override
  String get compatible => 'Compatible with';

  @override
  String get incompatible => 'Incompatible with';

  @override
  String get incompatibleSuffix => '';

  @override
  String get openSourcePage => 'Open source page';

  @override
  String get creatorDashboard => 'Creator dashboard';

  @override
  String get myResources => 'My resources';

  @override
  String get drafts => 'Drafts';

  @override
  String get pendingReview => 'Pending review';

  @override
  String get published => 'Published';

  @override
  String get failed => 'Failed / Needs action';

  @override
  String get newResource => 'New resource';

  @override
  String get basicInfo => 'Basic info';

  @override
  String get packageFiles => 'Package files';

  @override
  String get deviceSelection => 'Device selection';

  @override
  String get deviceFileMapping => 'Device-file mapping';

  @override
  String get publishTargets => 'Publish targets';

  @override
  String get publishPreview => 'Publish preview';

  @override
  String get reviewStatus => 'Review status';

  @override
  String get scan => 'Scan';

  @override
  String get logs => 'Logs';

  @override
  String get connectedDevices => 'Connected devices';

  @override
  String get pairedDevices => 'Paired devices';

  @override
  String get discoveredDevices => 'Discovered devices';

  @override
  String get overview => 'Overview';

  @override
  String get apps => 'Apps';

  @override
  String get connection => 'Connection';

  @override
  String get protocol => 'Protocol';

  @override
  String get error => 'Error';

  @override
  String get errorBluetoothUnavailable =>
      'Bluetooth is not available. Check that Bluetooth is enabled and ZeroBox has permission to use it';

  @override
  String get errorBluetoothConnectFailed =>
      'Connection failed. Check that Bluetooth permission is granted and Bluetooth is on, the device is nearby and not occupied by another app or device, and VelaOS devices are in \"Connect new phone\" mode, then try again';

  @override
  String get errorBluetoothDisconnected =>
      'Bluetooth disconnected. Reconnect the device and try again';

  @override
  String get errorOperationTimeout =>
      'Operation timed out. Make sure the device is still nearby and try again';

  @override
  String get errorDeviceNotReady =>
      'Device is not ready. Connect and authenticate the device first';

  @override
  String get errorBleCharacteristicsMissing =>
      'Required BLE channels were not found. Reconnect the device or check whether it supports this feature';

  @override
  String get errorWebSerialUnavailable =>
      'This browser does not support Web Serial. Use Chrome, Edge, or another Web Serial compatible browser';

  @override
  String get errorAccountPasswordIncorrect =>
      'Xiaomi account username or password is incorrect';

  @override
  String get errorAccountTwoFactorIncomplete =>
      'Xiaomi account two-factor verification was not completed. Sign in again';

  @override
  String get errorUnsupportedFileType =>
      'Unsupported or unrecognized file type';

  @override
  String get errorCertificateVerificationFailed =>
      'Certificate verification failed. If you are using a proxy, disable HTTPS interception for this app or make sure its certificate is trusted by Flutter/Dart';

  @override
  String errorUnknownWithDetail(Object detail) {
    return 'Operation failed: $detail';
  }

  @override
  String get copyLogs => 'Copy logs';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get personalCenter => 'Personal center';

  @override
  String get accountAndPublishing => 'Account & Publishing';

  @override
  String get appearance => 'Appearance';

  @override
  String get resources => 'Resources';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox Repo';

  @override
  String get communitySourceBandBbs => 'BandBBS Community';

  @override
  String get communitySourceHuamiAppStore => 'Amazfit App Store';

  @override
  String get devices => 'Devices';

  @override
  String get categories => 'Categories';

  @override
  String get advanced => 'Advanced';

  @override
  String get aboutZeroBox => 'About ZeroBox';

  @override
  String get openSourceLicenses => 'Open source licenses';

  @override
  String get acknowledgements => 'Special Acknowledgements';

  @override
  String get acknowledgementsDesc =>
      'Open source projects referenced by ZeroBox';

  @override
  String get developmentTeam => 'Development team';

  @override
  String get deviceNotConnected => 'Not connected';

  @override
  String get deviceConnected => 'Connected';

  @override
  String get deviceDisconnected => 'Disconnected';

  @override
  String get deviceReconnect => 'Reconnect';

  @override
  String get deviceConnect => 'Connect';

  @override
  String get deviceSwitch => 'Switch';

  @override
  String get deviceCharging => 'Charging';

  @override
  String get deviceFeaturesInstallApp => 'Install app';

  @override
  String get deviceFeaturesInstallAppDesc =>
      'Install third-party app from local file';

  @override
  String get deviceFeaturesInstallWatchface => 'Install watchface';

  @override
  String get deviceFeaturesInstallWatchfaceDesc =>
      'Install watchface from local file';

  @override
  String get deviceFeaturesInstallFirmware => 'Install firmware';

  @override
  String get deviceFeaturesInstallFirmwareDesc =>
      'Flash firmware or tool package';

  @override
  String get deviceFeaturesManageApps => 'Manage apps';

  @override
  String get deviceFeaturesManageAppsDesc =>
      'View and uninstall installed apps';

  @override
  String get deviceFeaturesManageWatchfaces => 'Manage watchfaces';

  @override
  String get deviceFeaturesManageWatchfacesDesc =>
      'View, delete and set current watchface';

  @override
  String get zeppOsMoreFeatures => 'Zepp OS Hub';

  @override
  String get zeppOsMoreFeaturesDescription => 'Explore your Zepp OS device';

  @override
  String get zeppOsFindDevice => 'Find device';

  @override
  String get zeppOsFindDeviceDescription =>
      'Make the device vibrate or ring so you can locate it nearby.';

  @override
  String get zeppOsFindDeviceStart => 'Start finding';

  @override
  String get zeppOsFindDeviceStop => 'Stop finding';

  @override
  String get deviceFeaturesDeviceInfo => 'Device info';

  @override
  String get deviceFeaturesDeviceInfoDesc => 'Firmware, storage and details';

  @override
  String get switchDeviceTitle => 'Switch device';

  @override
  String get savedDevices => 'Saved devices';

  @override
  String get scanAndAdd => 'Scan and add';

  @override
  String get scanNotFound => 'No devices found';

  @override
  String get noSavedDevices => 'No saved devices';

  @override
  String get authkey => 'Auth key';

  @override
  String get authkeyPrompt => 'Enter device auth key';

  @override
  String get authkeyPlaceholder => 'Auth key';

  @override
  String get connectFailed => 'Connection failed';

  @override
  String deviceConnectingTo(String deviceName) {
    return 'Connecting to $deviceName…';
  }

  @override
  String get deviceConnectionPreparing => 'Preparing connection…';

  @override
  String deviceConnectionEstablishing(String transport) {
    return 'Establishing $transport connection…';
  }

  @override
  String get deviceConnectionInitializing => 'Initializing device protocol…';

  @override
  String get deviceConnectionAuthenticating => 'Authenticating device…';

  @override
  String get deviceConnectionFetchingStatus => 'Reading device information…';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown => 'Unrecognized device';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint =>
      'On the web, ZeroBox connects to devices via Web Serial. Saved devices stay in this browser.';

  @override
  String get webSerialConnectDialogTitle => 'Connect via Web Serial';

  @override
  String get webSerialConnectDialogHint =>
      'Enter the device auth key, then select the serial port in the browser prompt. The auth key is saved in this browser.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deviceActionsDelete => 'Delete';

  @override
  String get deviceActionsDisconnect => 'Disconnect';

  @override
  String get deviceActionsShareQR => 'Share QR';

  @override
  String get deviceShareZeroBoxCode => 'Switch to ZeroBox code';

  @override
  String get deviceShareAstroBoxCompatibleCode =>
      'Switch to AstroBox compatible code';

  @override
  String get installTapToSelectFile => 'Tap to select file';

  @override
  String get installPackageName => 'Package name';

  @override
  String get installWatchfaceId => 'Watchface ID';

  @override
  String get deviceInfoTitle => 'Device info';

  @override
  String get deviceInfoGroupDevice => 'Device';

  @override
  String get deviceInfoGroupSystem => 'System';

  @override
  String get deviceInfoGroupStatus => 'Status';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldAuthkey => 'Auth key';

  @override
  String get fieldConnectionType => 'Connection type';

  @override
  String get fieldCodename => 'Codename';

  @override
  String get fieldModel => 'Model';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => 'Firmware';

  @override
  String get fieldSerial => 'Serial';

  @override
  String get fieldBattery => 'Battery';

  @override
  String get fieldChargeStatus => 'Charge status';

  @override
  String get fieldLastCharge => 'Last charge';

  @override
  String get fieldStorage => 'Storage';

  @override
  String get appManagementTitle => 'App management';

  @override
  String get appManagementNone => 'No installed apps';

  @override
  String get appManagementShowSystemApps => 'Show system apps';

  @override
  String get watchfaceManagementTitle => 'Watchface management';

  @override
  String get watchfaceManagementNone => 'No installed watchfaces';

  @override
  String get open => 'Open';

  @override
  String get externalLinkTitle => 'Open external link';

  @override
  String externalLinkDescription(String url) {
    return 'You are about to visit $url\n\nThis website is operated by a third party, is not affiliated with ZeroBox, and its security is unknown. Please proceed with caution. Do you want to continue?';
  }

  @override
  String get externalLinkAstroBoxResourceHint =>
      'This appears to be an AstroBox resource. You can also view and install it within ZeroBox';

  @override
  String get continueToWebsite => 'Continue';

  @override
  String get viewInZeroBox => 'View in ZeroBox';

  @override
  String get uninstall => 'Uninstall';

  @override
  String get enable => 'Enable';

  @override
  String get fail => 'Failed';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get close => 'Close';

  @override
  String get desktopTrayShow => 'Show window';

  @override
  String get desktopTrayExit => 'Exit ZeroBox';

  @override
  String get desktopCloseTitle => 'Exit confirmation';

  @override
  String get desktopCloseMessage => 'Would you like to exit ZeroBox?';

  @override
  String get desktopCloseRemember => 'Do not ask again';

  @override
  String get desktopCloseToTray => 'Minimize to tray';

  @override
  String get desktopCloseExit => 'Exit ZeroBox';

  @override
  String get settingsDesktopCloseBehavior => 'Close button behavior';

  @override
  String get settingsDesktopCloseBehaviorDesc =>
      'Choose what happens when the main window is closed';

  @override
  String get desktopCloseBehaviorAsk => 'Ask every time';

  @override
  String get desktopCloseBehaviorExit => 'Exit immediately';

  @override
  String get desktopCloseBehaviorTray => 'Minimize to tray';

  @override
  String get multiDevice => 'Multi-device';

  @override
  String get quickApp => 'Quickapp';

  @override
  String get miniprogram => 'Miniprogram';

  @override
  String get miniprograms => 'Miniprograms';

  @override
  String get watchface => 'Watchface';

  @override
  String get firmwareTool => 'Firmware / Tool';

  @override
  String get fontPack => 'Font Pack';

  @override
  String get iconPack => 'Icon Pack';

  @override
  String get free => 'Free';

  @override
  String get paid => 'Paid';

  @override
  String get forcePaid => 'Force Paid';

  @override
  String get version => 'Version';

  @override
  String get noDescription => 'No description';

  @override
  String get preview => 'Preview';

  @override
  String get productAbout => 'About';

  @override
  String get productDeviceRequirements => 'Device requirements';

  @override
  String get productOtherVersions => 'Other versions';

  @override
  String get productInQueue => 'In queue';

  @override
  String get productShare => 'Share';

  @override
  String get productViewOnBandBBS => 'View on BandBBS';

  @override
  String get changeCdn => 'Change CDN';

  @override
  String get cdnErrorTitle => 'AstroBox data failed to load';

  @override
  String cdnErrorMessage(Object cdn, Object path) {
    return 'Current CDN ($cdn) could not fetch $path. Would you like to switch CDN?';
  }

  @override
  String get cdnErrorContinue => 'Switch CDN';

  @override
  String get cdnErrorCancel => 'Cancel';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsSource => 'Downloads';

  @override
  String get settingsSourceRestart => 'Restart required';

  @override
  String get settingsQueue => 'Queue';

  @override
  String get settingsInstall => 'Installation';

  @override
  String get settingsTools => 'Mysterious Tools';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAccountLoginBBS => 'Login to BandBBS';

  @override
  String get settingsAccountLoginBBSDesc =>
      'Sign in to sync purchased resources';

  @override
  String get settingsAccountBandBbsSigningIn => 'Signing in';

  @override
  String get settingsAccountBandBbsOpenedBrowser =>
      'Browser opened. Complete BandBBS authorization there';

  @override
  String get settingsAccountBandBbsSignedIn => 'BandBBS signed in';

  @override
  String get settingsAccountBandBbsLoginFailed => 'BandBBS sign-in failed';

  @override
  String get settingsBandBbsAccountRequired =>
      'Sign in to your BandBBS account in Settings first';

  @override
  String settingsAccountBandBbsUser(Object userId) {
    return 'User ID: $userId';
  }

  @override
  String get settingsAccountBBSAccount => 'BandBBS account';

  @override
  String get bandBbsAccountTitle => 'BandBBS account';

  @override
  String get bandBbsPurchasedResources => 'Purchased resources';

  @override
  String get bandBbsResourceId => 'Resource ID';

  @override
  String get bandBbsResourceIdHint => 'Enter BandBBS resource ID';

  @override
  String get bandBbsQueryResource => 'Query';

  @override
  String get bandBbsOpenResource => 'View on BandBBS';

  @override
  String get bandBbsLogout => 'Sign out';

  @override
  String get bandBbsLoggedOut => 'Signed out';

  @override
  String get bandBbsLoadPreviews => 'Load post previews';

  @override
  String get bandBbsLoadPreviewsDesc =>
      'Automatically load attachment previews in the resource list';

  @override
  String get bandBbsShowAllCategories => 'Show all categories';

  @override
  String get bandBbsShowAllCategoriesDesc =>
      'Include categories for unsupported devices hidden by default';

  @override
  String get settingsAccountSyncDevices => 'Sync devices';

  @override
  String get settingsAccountSyncDevicesDesc =>
      'Log in to Mi Account to sync paired devices';

  @override
  String get settingsMiAccount => 'Mi Account';

  @override
  String get settingsMiAccountDesc =>
      'Sign in and sync authkeys from bound devices';

  @override
  String get settingsMiAccountLoginTitle => 'Mi Account login';

  @override
  String get settingsMiAccountUsername => 'Account';

  @override
  String get settingsMiAccountPassword => 'Password';

  @override
  String get settingsMiAccountRememberCredentials =>
      'Remember account and password';

  @override
  String get settingsMiAccountLoginAndSync => 'Sign in and sync';

  @override
  String get settingsMiAccountMissingCredentials =>
      'Enter your Mi Account and password';

  @override
  String get settingsMiAccountTwoFactorPrompt =>
      'Complete Mi Account two-factor verification in the verification page';

  @override
  String get settingsMiAccountLoginWindowClosed =>
      'The login window was closed';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return 'Synced $count Mi devices';
  }

  @override
  String get settingsHuamiAccount => 'Amazfit account';

  @override
  String get settingsHuamiAccountDesc =>
      'Sign in and save credentials for Zepp store access';

  @override
  String get settingsHuamiAccountSigningIn => 'Signing in';

  @override
  String get settingsHuamiAccountSignedIn => 'Amazfit account signed in';

  @override
  String settingsHuamiAccountUser(Object username) {
    return 'Account: $username';
  }

  @override
  String get settingsHuamiAccountLoginTitle => 'Amazfit account login';

  @override
  String get settingsHuamiAccountUsername => 'Account';

  @override
  String get settingsHuamiAccountPassword => 'Password';

  @override
  String get settingsHuamiAccountRememberCredentials => 'Remember password';

  @override
  String get settingsHuamiAccountLoginAndSave => 'Sign in and save';

  @override
  String get settingsHuamiAccountMissingCredentials =>
      'Enter your Amazfit account and password';

  @override
  String get settingsHuamiAccountRequired =>
      'Sign in to your Amazfit account in Settings first';

  @override
  String get unsupportedDeviceResourceTitle =>
      'Unsupported device/resource type';

  @override
  String get unsupportedDeviceResourceMessage =>
      'ZeroBox does not currently support this device or resource type. Do not attempt to install resources from this category, as unexpected issues may occur.';

  @override
  String get understood => 'I understand';

  @override
  String get settingsGeneralLanguage => 'Language';

  @override
  String get settingsGeneralLanguageDesc => 'Change app display language';

  @override
  String get settingsWideNavigationPosition => 'Navigation position';

  @override
  String get settingsWideNavigationPositionDesc =>
      'Adjust side tab placement in the wide-screen state';

  @override
  String get settingsWideNavigationPositionBottom => 'Bottom';

  @override
  String get settingsWideNavigationPositionCenter => 'Center';

  @override
  String get settingsWideNavigationPositionSplit => 'Split';

  @override
  String get settingsGeneralTranslateTeam => 'Translation contributors';

  @override
  String get settingsAutoReconnectTitle => 'Auto reconnect';

  @override
  String get settingsAutoReconnectDesc =>
      'Automatically reconnect to the last paired device on startup';

  @override
  String get settingsGeneralDebugWindow => 'Debug window';

  @override
  String get settingsGeneralDebugWindowDesc => 'Show a floating debug panel';

  @override
  String get settingsSourceOfficialCdn => 'GitHub source CDN';

  @override
  String get settingsSourceOfficialCdnDesc =>
      'CDN used to fetch the GitHub-hosted community index';

  @override
  String get settingsQueueAutoInstall => 'Auto install';

  @override
  String get settingsQueueAutoInstallDesc =>
      'Start installation automatically after download';

  @override
  String get settingsQueueDontClear => 'Don\'t clear install queue';

  @override
  String get settingsQueueDontClearDesc =>
      'Keep completed items in the install queue';

  @override
  String get settingsInstallSendInterval => 'Packet interval';

  @override
  String get settingsInstallSendIntervalDesc =>
      'Delay between Bluetooth fragments during install';

  @override
  String get settingsToolsUnlockCode => 'Calculate unlock code';

  @override
  String get settingsToolsUnlockCodeDesc =>
      'Generate a Mi Wear unlock code from MAC and SN';

  @override
  String get settingsToolsDialogTitle => 'Unlock code';

  @override
  String get settingsToolsMac => 'MAC address';

  @override
  String get settingsToolsSn => 'Serial number';

  @override
  String get settingsToolsNoticeTitle => 'Warning';

  @override
  String get settingsToolsNoticeBody =>
      'Unlocking may void your warranty or cause data loss. Use at your own risk.';

  @override
  String get settingsToolsAgree => 'I understand the risks';

  @override
  String get settingsToolsCalculate => 'Calculate';

  @override
  String get settingsToolsResult => 'Result';

  @override
  String get settingsToolsDialogUsage => 'Usage';

  @override
  String get settingsToolsDialogUsageInfo =>
      'Enter the MAC address and serial number shown on the device.';

  @override
  String get settingsAboutAboutAstrobox => 'About ZeroBox';

  @override
  String get settingsAboutAboutAstroboxDesc => 'Version, changelog and team';

  @override
  String get settingsAboutDisclaimer => 'Disclaimer';

  @override
  String get settingsAboutDisclaimerDesc =>
      'User agreement and liability statement';

  @override
  String get settingsAboutOpenlog => 'Log folder';

  @override
  String get settingsAboutOpenlogDesc =>
      'Open the log directory in file manager';

  @override
  String get settingsAboutWebsite => 'Official website';

  @override
  String get settingsAboutWebsiteDesc => 'Visit zerobox.zxor.org';

  @override
  String get settingsAboutQQ => 'QQ group';

  @override
  String get settingsAboutQQDesc => 'Join the community chat';

  @override
  String get settingsAboutLicences => 'Open source licenses';

  @override
  String get settingsAboutLicencesDesc =>
      'Licenses for Flutter, dependencies and open source components';

  @override
  String get settingsGuest => 'Guest';

  @override
  String get settingsTapToSignIn => 'Tap to sign in';

  @override
  String get settingsConnected => 'Connected';

  @override
  String get settingsNotConnected => 'Not connected';

  @override
  String get settingsNotSet => 'Not set';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

  @override
  String get settingsOledDark => 'OLED dark';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsThemeModeDesc => 'Change app theme appearance';

  @override
  String get settingsDynamicColor => 'Dynamic color';

  @override
  String get settingsDynamicColorDesc =>
      'Use system accent colors for the app theme';

  @override
  String get settingsColorScheme => 'Color scheme';

  @override
  String get settingsColorSchemeDesc => 'Choose the app accent color';

  @override
  String get settingsColorSchemePink => 'Pink';

  @override
  String get settingsColorSchemePurple => 'Purple';

  @override
  String get settingsColorSchemeTeal => 'Teal';

  @override
  String get settingsColorSchemeGreen => 'Green';

  @override
  String get settingsColorSchemeRed => 'Red';

  @override
  String get settingsColorSchemeAmber => 'Amber';

  @override
  String get settingsDesktopAccentSource => 'Linux accent source';

  @override
  String get settingsDesktopAccentSourceDesc =>
      'Choose whether to read accent colors from GTK or Qt';

  @override
  String get settingsDesktopAccentSourceSystem => 'Auto';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsConfirm => 'Confirm';

  @override
  String get settingsOpen => 'Open';

  @override
  String get settingsVisit => 'Visit';

  @override
  String get settingsTeamSlogan =>
      'A pretty fast wearable management tool for VelaOS and ZeppOS.';

  @override
  String get settingsTeamGitHub => 'GitHub Repository';

  @override
  String get settingsTeamMembers => 'Team Members';

  @override
  String get settingsTeamRoleMain => 'Main Developer / Designer';

  @override
  String get settingsTeamRoleZeppOS => 'ZeppOS implementation';

  @override
  String get settingsAboutSoftware => 'About software';

  @override
  String get settingsAboutSoftwareDesc =>
      'Version, changelog and development team';

  @override
  String get settingsAboutSoftwareTagline =>
      'A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter';

  @override
  String get settingsAboutSoftwareRepository => 'Open GitHub repository';

  @override
  String get settingsAboutSoftwareTeam => 'Development team';

  @override
  String get settingsAboutSoftwareReleaseName =>
      'Current release: development preview';

  @override
  String get settingsAboutSoftwareReleaseBody =>
      'This update includes:\n• System accent color support and theme refinements\n• Redesigned resource detail and list pages with grouped device filters\n• Replaced team page with about software page; localized settings\n• Improved Xiaomi SAR controller send error handling\n• Stabilized Linux classic SPP connect cancellation and timeouts\n• Updated ARB localizations and generated l10n files';

  @override
  String get settingsAboutSoftwareBuildInfo => 'Build info';

  @override
  String get settingsAboutSoftwareCopyright =>
      'Copyright © ZeroBox contributors';

  @override
  String get acknowledgementsKazumi =>
      'Reference for Material Design components and UI patterns.';

  @override
  String get acknowledgementsAstroBoxPublic =>
      'Reference for UI structure, resource workflows, and interaction design.';

  @override
  String get acknowledgementsAstroBoxNgCore =>
      'Reference for Xiaomi device protocols, install flows, and transfer behavior.';

  @override
  String get acknowledgementsAstroBoxNgBluetooth =>
      'Reference for Bluetooth connection behavior.';

  @override
  String get acknowledgementsAstroBoxNgAccount =>
      'Reference for Xiaomi account login, device sync, and authkey retrieval flows.';

  @override
  String get acknowledgementsAstroBoxNgProvider =>
      'Reference for community resource indexes, CDN handling, and manifest parsing flows.';

  @override
  String get acknowledgementsAstroBoxNgAppWasm =>
      'Reference for Web Serial and browser-side connection flows.';

  @override
  String get acknowledgementsGadgetbridge =>
      'Reference for ZeppOS and wearable protocol research.';

  @override
  String get resourceHomeEmptyTitle => 'Home page is under construction';

  @override
  String get resourceHomeEmptySubtitle =>
      'You can get resources from the library';

  @override
  String get resourceCreatorEmptyTitle =>
      'Creator center is under construction';

  @override
  String get resourceCreatorEmptySubtitle =>
      'You can manage acquired resources in the library';

  @override
  String get openResourceLibrary => 'Open resource library';

  @override
  String get downloadQueueTitle => 'Download queue';

  @override
  String get installQueueTitle => 'Install queue';

  @override
  String get queueClear => 'Clear';

  @override
  String get queueStart => 'Start';

  @override
  String get queuePause => 'Pause';

  @override
  String get downloadQueueEmpty => 'No download tasks';

  @override
  String get installQueueEmpty => 'No install tasks';

  @override
  String get localAppInstall => 'Local app install';

  @override
  String get localWatchfaceInstall => 'Local watchface install';

  @override
  String get localFirmwareInstall => 'Local firmware install';

  @override
  String get queueStatusPending => 'Waiting';

  @override
  String queueStatusDownloading(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return 'Installing $percent%';
  }

  @override
  String get queueStatusCompleted => 'Completed';

  @override
  String get queueStatusFailed => 'Failed';

  @override
  String get queueDragToInstall => 'Release to add to install queue';

  @override
  String queueAddedFiles(int count) {
    return 'Added $count files to install queue';
  }

  @override
  String get installQueueReadFailed => 'Read failed';

  @override
  String get installQueueUnsupportedFile => 'Unsupported file';

  @override
  String timeTodayAt(Object time) {
    return 'Today $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return 'Yesterday $time';
  }

  @override
  String get settingsAccountBandBbsAccount => 'BandBBS Account';

  @override
  String get bandBbsResourceQueryTitle => 'Install purchased resources';

  @override
  String get settingsAboutLogs => 'Logs';

  @override
  String get settingsAboutLogsDescription =>
      'Runtime logs from the last 7 days. On Android, they can be viewed and copied in the Files app.';

  @override
  String get settingsAboutLogsOpen => 'Open logs folder';

  @override
  String get settingsAboutLogsOpenFailed => 'Unable to open the logs folder';

  @override
  String get settingsAboutLogsWarningTitle => 'Sensitive information warning';

  @override
  String get settingsAboutLogsWarningMessage =>
      'Logs may contain BandBBS, Xiaomi, or Amazfit login credentials and other sensitive information. Do not share them with anyone other than official ZeroBox maintainers!';

  @override
  String get pluginPermissionRequestTitle => 'Plugin permission request';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return '\"$plugin\" wants to $operation.';
  }

  @override
  String get pluginPermissionOnce => 'Allow once';

  @override
  String get pluginPermissionSession => 'Allow this run';

  @override
  String get pluginPermissionAlways => 'Always allow';

  @override
  String get pluginPermissionDeny => 'Deny';

  @override
  String get pluginPermissionOpenExternal => 'open an external link';

  @override
  String get pluginPermissionPickFile => 'access host files';

  @override
  String get pluginPermissionExportFile => 'export a file to the host';

  @override
  String get pluginPermissionNetwork => 'access the network';

  @override
  String get pluginPermissionInterconnect =>
      'communicate with device applications';

  @override
  String get pluginPermissionProvider => 'register a resource provider';

  @override
  String get pluginPermissionReadDevice => 'read device information';

  @override
  String get pluginPermissionOperateDevice => 'operate a device';

  @override
  String get pluginPermissionObserveProtocol => 'read raw device protocol data';

  @override
  String get pluginPermissionSendProtocol =>
      'send raw protocol data to a device';

  @override
  String get pluginErrorTitle => 'Plugin runtime error';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return '\"$plugin\" encountered a runtime error:\n\n$error';
  }

  @override
  String get pluginErrorClearData => 'Clear plugin data';

  @override
  String get pluginErrorUninstall => 'Uninstall plugin';

  @override
  String get pluginErrorSafeMode => 'Enter safe mode';

  @override
  String get pluginSafeModeTitle => 'Plugin safe mode is enabled';

  @override
  String get pluginSafeModeDescription =>
      'All plugins are stopped and will reload after safe mode is disabled.';

  @override
  String get pluginSafeModeExit => 'Exit safe mode';

  @override
  String get devTools => 'DevTools';

  @override
  String get devToolsDescriptionDesktop => 'Open DevTools in a separate window';

  @override
  String get devToolsDescriptionEntry =>
      'Show a DevTools entry button in app bars';

  @override
  String get devToolsOperationFailed => 'Unable to change the DevTools state';

  @override
  String get resourceTypeErrorTitle => 'Incorrect resource type';

  @override
  String get resourceTypeUnknownTitle => 'Unrecognized resource type';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return 'This appears to be a $detectedType resource, but you selected $selectedType. Choose how to install it';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return 'This appears to be a $resourceType resource for a $resourcePlatform device, but the connected device is $deviceName ($devicePlatform). It is not supported and forcing installation may cause unexpected problems';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return 'ZeroBox cannot identify the actual resource type. Install it as $selectedType anyway?';
  }

  @override
  String get resourceInstallCancel => 'Cancel installation';

  @override
  String get resourceInstallAcknowledge => 'I understand';

  @override
  String get resourceInstallForce => 'Force install';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return 'Force install (${seconds}s)';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return 'Continue as $type';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return 'Continue as $type (${seconds}s)';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return 'Install as $type';
  }

  @override
  String get resourceTypeApp => 'miniprogram';

  @override
  String get resourceTypeQuickApp => 'quick app';

  @override
  String get resourceTypeWatchface => 'watchface';

  @override
  String get resourceTypeFirmware => 'firmware';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return 'Install $type';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return 'Install $fileName ($fileSize)?';
  }

  @override
  String get resourceInstallConfirm => 'Install';
}
