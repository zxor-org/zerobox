import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ZeroBox'**
  String get appTitle;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @exploreTab.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreTab;

  /// No description provided for @devicesTab.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTab;

  /// No description provided for @pluginsTab.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get pluginsTab;

  /// No description provided for @pluginImport.
  ///
  /// In en, this message translates to:
  /// **'Import plugin'**
  String get pluginImport;

  /// No description provided for @pluginInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get pluginInstalled;

  /// No description provided for @pluginMarket.
  ///
  /// In en, this message translates to:
  /// **'Plugin market'**
  String get pluginMarket;

  /// No description provided for @pluginMarketUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The plugin market is not available yet'**
  String get pluginMarketUnavailable;

  /// No description provided for @pluginEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plugins installed'**
  String get pluginEmpty;

  /// No description provided for @pluginSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a plugin to view its features'**
  String get pluginSelectHint;

  /// No description provided for @pluginFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get pluginFeatures;

  /// No description provided for @pluginDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get pluginDetails;

  /// No description provided for @pluginNoFeatures.
  ///
  /// In en, this message translates to:
  /// **'This plugin has no available features'**
  String get pluginNoFeatures;

  /// No description provided for @pluginAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get pluginAuthor;

  /// No description provided for @pluginVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get pluginVersion;

  /// No description provided for @pluginApiLevel.
  ///
  /// In en, this message translates to:
  /// **'API level'**
  String get pluginApiLevel;

  /// No description provided for @pluginWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get pluginWebsite;

  /// No description provided for @pluginPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get pluginPermissions;

  /// No description provided for @pluginInstallConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm plugin installation'**
  String get pluginInstallConfirmTitle;

  /// No description provided for @pluginUpdateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm plugin update'**
  String get pluginUpdateConfirmTitle;

  /// No description provided for @pluginDeclaredPermissions.
  ///
  /// In en, this message translates to:
  /// **'This plugin declares the following permissions:'**
  String get pluginDeclaredPermissions;

  /// No description provided for @pluginNoPermissions.
  ///
  /// In en, this message translates to:
  /// **'No permissions declared'**
  String get pluginNoPermissions;

  /// No description provided for @pluginUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Installed and up to date'**
  String get pluginUpToDate;

  /// No description provided for @pluginUninstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Uninstall plugin'**
  String get pluginUninstallTitle;

  /// No description provided for @pluginUninstallMessage.
  ///
  /// In en, this message translates to:
  /// **'The plugin\'s data will also be removed'**
  String get pluginUninstallMessage;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pendingTasks.
  ///
  /// In en, this message translates to:
  /// **'Pending tasks'**
  String get pendingTasks;

  /// No description provided for @manageDevice.
  ///
  /// In en, this message translates to:
  /// **'Manage device'**
  String get manageDevice;

  /// No description provided for @installLocalResource.
  ///
  /// In en, this message translates to:
  /// **'Install local resource'**
  String get installLocalResource;

  /// No description provided for @recentUpdates.
  ///
  /// In en, this message translates to:
  /// **'Recent updates'**
  String get recentUpdates;

  /// No description provided for @newlyPublished.
  ///
  /// In en, this message translates to:
  /// **'Newly published'**
  String get newlyPublished;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @zeroBoxNews.
  ///
  /// In en, this message translates to:
  /// **'ZeroBox news'**
  String get zeroBoxNews;

  /// No description provided for @bandbbsNews.
  ///
  /// In en, this message translates to:
  /// **'BandBBS news'**
  String get bandbbsNews;

  /// No description provided for @astroBoxNews.
  ///
  /// In en, this message translates to:
  /// **'AstroBox news'**
  String get astroBoxNews;

  /// No description provided for @resourceLibrary.
  ///
  /// In en, this message translates to:
  /// **'Resource library'**
  String get resourceLibrary;

  /// No description provided for @creatorCenter.
  ///
  /// In en, this message translates to:
  /// **'Creator center'**
  String get creatorCenter;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @importLocalResource.
  ///
  /// In en, this message translates to:
  /// **'Import local resource'**
  String get importLocalResource;

  /// No description provided for @allDevices.
  ///
  /// In en, this message translates to:
  /// **'All devices'**
  String get allDevices;

  /// No description provided for @currentDevice.
  ///
  /// In en, this message translates to:
  /// **'Current device'**
  String get currentDevice;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @watchfaces.
  ///
  /// In en, this message translates to:
  /// **'Watchface'**
  String get watchfaces;

  /// No description provided for @quickApps.
  ///
  /// In en, this message translates to:
  /// **'Quickapps'**
  String get quickApps;

  /// No description provided for @firmwareTools.
  ///
  /// In en, this message translates to:
  /// **'Firmware / Tools'**
  String get firmwareTools;

  /// No description provided for @resourceTypeFontpack.
  ///
  /// In en, this message translates to:
  /// **'Font pack'**
  String get resourceTypeFontpack;

  /// No description provided for @resourceTypeIconpack.
  ///
  /// In en, this message translates to:
  /// **'Icon pack'**
  String get resourceTypeIconpack;

  /// No description provided for @localResources.
  ///
  /// In en, this message translates to:
  /// **'Local resources'**
  String get localResources;

  /// No description provided for @zeroBox.
  ///
  /// In en, this message translates to:
  /// **'ZeroBox'**
  String get zeroBox;

  /// No description provided for @bandbbs.
  ///
  /// In en, this message translates to:
  /// **'BandBBS'**
  String get bandbbs;

  /// No description provided for @astroBox.
  ///
  /// In en, this message translates to:
  /// **'AstroBox'**
  String get astroBox;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @supportedDevices.
  ///
  /// In en, this message translates to:
  /// **'Supported devices'**
  String get supportedDevices;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get downloadStarted;

  /// No description provided for @compatible.
  ///
  /// In en, this message translates to:
  /// **'Compatible with'**
  String get compatible;

  /// No description provided for @incompatible.
  ///
  /// In en, this message translates to:
  /// **'Incompatible with'**
  String get incompatible;

  /// No description provided for @incompatibleSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get incompatibleSuffix;

  /// No description provided for @openSourcePage.
  ///
  /// In en, this message translates to:
  /// **'Open source page'**
  String get openSourcePage;

  /// No description provided for @creatorDashboard.
  ///
  /// In en, this message translates to:
  /// **'Creator dashboard'**
  String get creatorDashboard;

  /// No description provided for @myResources.
  ///
  /// In en, this message translates to:
  /// **'My resources'**
  String get myResources;

  /// No description provided for @drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get drafts;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get pendingReview;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get published;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed / Needs action'**
  String get failed;

  /// No description provided for @newResource.
  ///
  /// In en, this message translates to:
  /// **'New resource'**
  String get newResource;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic info'**
  String get basicInfo;

  /// No description provided for @packageFiles.
  ///
  /// In en, this message translates to:
  /// **'Package files'**
  String get packageFiles;

  /// No description provided for @deviceSelection.
  ///
  /// In en, this message translates to:
  /// **'Device selection'**
  String get deviceSelection;

  /// No description provided for @deviceFileMapping.
  ///
  /// In en, this message translates to:
  /// **'Device-file mapping'**
  String get deviceFileMapping;

  /// No description provided for @publishTargets.
  ///
  /// In en, this message translates to:
  /// **'Publish targets'**
  String get publishTargets;

  /// No description provided for @publishPreview.
  ///
  /// In en, this message translates to:
  /// **'Publish preview'**
  String get publishPreview;

  /// No description provided for @reviewStatus.
  ///
  /// In en, this message translates to:
  /// **'Review status'**
  String get reviewStatus;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @connectedDevices.
  ///
  /// In en, this message translates to:
  /// **'Connected devices'**
  String get connectedDevices;

  /// No description provided for @pairedDevices.
  ///
  /// In en, this message translates to:
  /// **'Paired devices'**
  String get pairedDevices;

  /// No description provided for @discoveredDevices.
  ///
  /// In en, this message translates to:
  /// **'Discovered devices'**
  String get discoveredDevices;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @apps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get apps;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorBluetoothUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is not available. Check that Bluetooth is enabled and ZeroBox has permission to use it'**
  String get errorBluetoothUnavailable;

  /// No description provided for @errorBluetoothConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth connection failed. Make sure the device is nearby, not occupied by another app, and try restarting Bluetooth'**
  String get errorBluetoothConnectFailed;

  /// No description provided for @errorBluetoothDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth disconnected. Reconnect the device and try again'**
  String get errorBluetoothDisconnected;

  /// No description provided for @errorOperationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Operation timed out. Make sure the device is still nearby and try again'**
  String get errorOperationTimeout;

  /// No description provided for @errorDeviceNotReady.
  ///
  /// In en, this message translates to:
  /// **'Device is not ready. Connect and authenticate the device first'**
  String get errorDeviceNotReady;

  /// No description provided for @errorBleCharacteristicsMissing.
  ///
  /// In en, this message translates to:
  /// **'Required BLE channels were not found. Reconnect the device or check whether it supports this feature'**
  String get errorBleCharacteristicsMissing;

  /// No description provided for @errorWebSerialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This browser does not support Web Serial. Use Chrome, Edge, or another Web Serial compatible browser'**
  String get errorWebSerialUnavailable;

  /// No description provided for @errorAccountPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi account username or password is incorrect'**
  String get errorAccountPasswordIncorrect;

  /// No description provided for @errorAccountTwoFactorIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi account two-factor verification was not completed. Sign in again'**
  String get errorAccountTwoFactorIncomplete;

  /// No description provided for @errorUnsupportedFileType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported or unrecognized file type'**
  String get errorUnsupportedFileType;

  /// No description provided for @errorCertificateVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Certificate verification failed. If you are using a proxy, disable HTTPS interception for this app or make sure its certificate is trusted by Flutter/Dart'**
  String get errorCertificateVerificationFailed;

  /// No description provided for @errorUnknownWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {detail}'**
  String errorUnknownWithDetail(Object detail);

  /// No description provided for @copyLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy logs'**
  String get copyLogs;

  /// No description provided for @exportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get exportLogs;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get clearLogs;

  /// No description provided for @personalCenter.
  ///
  /// In en, this message translates to:
  /// **'Personal center'**
  String get personalCenter;

  /// No description provided for @accountAndPublishing.
  ///
  /// In en, this message translates to:
  /// **'Account & Publishing'**
  String get accountAndPublishing;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// No description provided for @communitySourceAstroBoxRepo.
  ///
  /// In en, this message translates to:
  /// **'AstroBox Repo'**
  String get communitySourceAstroBoxRepo;

  /// No description provided for @communitySourceBandBbs.
  ///
  /// In en, this message translates to:
  /// **'BandBBS Community'**
  String get communitySourceBandBbs;

  /// No description provided for @communitySourceHuamiAppStore.
  ///
  /// In en, this message translates to:
  /// **'Amazfit App Store'**
  String get communitySourceHuamiAppStore;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @aboutZeroBox.
  ///
  /// In en, this message translates to:
  /// **'About ZeroBox'**
  String get aboutZeroBox;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get openSourceLicenses;

  /// No description provided for @acknowledgements.
  ///
  /// In en, this message translates to:
  /// **'Special Acknowledgements'**
  String get acknowledgements;

  /// No description provided for @acknowledgementsDesc.
  ///
  /// In en, this message translates to:
  /// **'Open source projects referenced by ZeroBox'**
  String get acknowledgementsDesc;

  /// No description provided for @developmentTeam.
  ///
  /// In en, this message translates to:
  /// **'Development team'**
  String get developmentTeam;

  /// No description provided for @deviceNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get deviceNotConnected;

  /// No description provided for @deviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get deviceConnected;

  /// No description provided for @deviceDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get deviceDisconnected;

  /// No description provided for @deviceReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get deviceReconnect;

  /// No description provided for @deviceConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get deviceConnect;

  /// No description provided for @deviceSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get deviceSwitch;

  /// No description provided for @deviceCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get deviceCharging;

  /// No description provided for @deviceFeaturesInstallApp.
  ///
  /// In en, this message translates to:
  /// **'Install app'**
  String get deviceFeaturesInstallApp;

  /// No description provided for @deviceFeaturesInstallAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Install third-party app from local file'**
  String get deviceFeaturesInstallAppDesc;

  /// No description provided for @deviceFeaturesInstallWatchface.
  ///
  /// In en, this message translates to:
  /// **'Install watchface'**
  String get deviceFeaturesInstallWatchface;

  /// No description provided for @deviceFeaturesInstallWatchfaceDesc.
  ///
  /// In en, this message translates to:
  /// **'Install watchface from local file'**
  String get deviceFeaturesInstallWatchfaceDesc;

  /// No description provided for @deviceFeaturesInstallFirmware.
  ///
  /// In en, this message translates to:
  /// **'Install firmware'**
  String get deviceFeaturesInstallFirmware;

  /// No description provided for @deviceFeaturesInstallFirmwareDesc.
  ///
  /// In en, this message translates to:
  /// **'Flash firmware or tool package'**
  String get deviceFeaturesInstallFirmwareDesc;

  /// No description provided for @deviceFeaturesManageApps.
  ///
  /// In en, this message translates to:
  /// **'Manage apps'**
  String get deviceFeaturesManageApps;

  /// No description provided for @deviceFeaturesManageAppsDesc.
  ///
  /// In en, this message translates to:
  /// **'View and uninstall installed apps'**
  String get deviceFeaturesManageAppsDesc;

  /// No description provided for @deviceFeaturesManageWatchfaces.
  ///
  /// In en, this message translates to:
  /// **'Manage watchfaces'**
  String get deviceFeaturesManageWatchfaces;

  /// No description provided for @deviceFeaturesManageWatchfacesDesc.
  ///
  /// In en, this message translates to:
  /// **'View, delete and set current watchface'**
  String get deviceFeaturesManageWatchfacesDesc;

  /// No description provided for @zeppOsMoreFeatures.
  ///
  /// In en, this message translates to:
  /// **'Zepp OS Hub'**
  String get zeppOsMoreFeatures;

  /// No description provided for @zeppOsMoreFeaturesDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore your Zepp OS device'**
  String get zeppOsMoreFeaturesDescription;

  /// No description provided for @zeppOsFindDevice.
  ///
  /// In en, this message translates to:
  /// **'Find device'**
  String get zeppOsFindDevice;

  /// No description provided for @zeppOsFindDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Make the device vibrate or ring so you can locate it nearby.'**
  String get zeppOsFindDeviceDescription;

  /// No description provided for @zeppOsFindDeviceStart.
  ///
  /// In en, this message translates to:
  /// **'Start finding'**
  String get zeppOsFindDeviceStart;

  /// No description provided for @zeppOsFindDeviceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop finding'**
  String get zeppOsFindDeviceStop;

  /// No description provided for @deviceFeaturesDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device info'**
  String get deviceFeaturesDeviceInfo;

  /// No description provided for @deviceFeaturesDeviceInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Firmware, storage and details'**
  String get deviceFeaturesDeviceInfoDesc;

  /// No description provided for @switchDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch device'**
  String get switchDeviceTitle;

  /// No description provided for @savedDevices.
  ///
  /// In en, this message translates to:
  /// **'Saved devices'**
  String get savedDevices;

  /// No description provided for @scanAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Scan and add'**
  String get scanAndAdd;

  /// No description provided for @scanNotFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get scanNotFound;

  /// No description provided for @noSavedDevices.
  ///
  /// In en, this message translates to:
  /// **'No saved devices'**
  String get noSavedDevices;

  /// No description provided for @authkey.
  ///
  /// In en, this message translates to:
  /// **'Auth key'**
  String get authkey;

  /// No description provided for @authkeyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter device auth key'**
  String get authkeyPrompt;

  /// No description provided for @authkeyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Auth key'**
  String get authkeyPlaceholder;

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectFailed;

  /// No description provided for @deviceConnectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {deviceName}…'**
  String deviceConnectingTo(String deviceName);

  /// No description provided for @deviceConnectionPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing connection…'**
  String get deviceConnectionPreparing;

  /// No description provided for @deviceConnectionEstablishing.
  ///
  /// In en, this message translates to:
  /// **'Establishing {transport} connection…'**
  String deviceConnectionEstablishing(String transport);

  /// No description provided for @deviceConnectionInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing device protocol…'**
  String get deviceConnectionInitializing;

  /// No description provided for @deviceConnectionAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating device…'**
  String get deviceConnectionAuthenticating;

  /// No description provided for @deviceConnectionFetchingStatus.
  ///
  /// In en, this message translates to:
  /// **'Reading device information…'**
  String get deviceConnectionFetchingStatus;

  /// No description provided for @deviceTransportBle.
  ///
  /// In en, this message translates to:
  /// **'BLE'**
  String get deviceTransportBle;

  /// No description provided for @deviceTransportSpp.
  ///
  /// In en, this message translates to:
  /// **'SPP'**
  String get deviceTransportSpp;

  /// No description provided for @deviceCompatibilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized device'**
  String get deviceCompatibilityUnknown;

  /// No description provided for @webSerialTitle.
  ///
  /// In en, this message translates to:
  /// **'Web Serial'**
  String get webSerialTitle;

  /// No description provided for @webSerialHint.
  ///
  /// In en, this message translates to:
  /// **'On the web, ZeroBox connects to devices via Web Serial. Saved devices stay in this browser.'**
  String get webSerialHint;

  /// No description provided for @webSerialConnectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect via Web Serial'**
  String get webSerialConnectDialogTitle;

  /// No description provided for @webSerialConnectDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the device auth key, then select the serial port in the browser prompt. The auth key is saved in this browser.'**
  String get webSerialConnectDialogHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deviceActionsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deviceActionsDelete;

  /// No description provided for @deviceActionsDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get deviceActionsDisconnect;

  /// No description provided for @deviceActionsShareQR.
  ///
  /// In en, this message translates to:
  /// **'Share QR'**
  String get deviceActionsShareQR;

  /// No description provided for @deviceShareZeroBoxCode.
  ///
  /// In en, this message translates to:
  /// **'Switch to ZeroBox code'**
  String get deviceShareZeroBoxCode;

  /// No description provided for @deviceShareAstroBoxCompatibleCode.
  ///
  /// In en, this message translates to:
  /// **'Switch to AstroBox compatible code'**
  String get deviceShareAstroBoxCompatibleCode;

  /// No description provided for @installTapToSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Tap to select file'**
  String get installTapToSelectFile;

  /// No description provided for @installPackageName.
  ///
  /// In en, this message translates to:
  /// **'Package name'**
  String get installPackageName;

  /// No description provided for @installWatchfaceId.
  ///
  /// In en, this message translates to:
  /// **'Watchface ID'**
  String get installWatchfaceId;

  /// No description provided for @deviceInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Device info'**
  String get deviceInfoTitle;

  /// No description provided for @deviceInfoGroupDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceInfoGroupDevice;

  /// No description provided for @deviceInfoGroupSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get deviceInfoGroupSystem;

  /// No description provided for @deviceInfoGroupStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get deviceInfoGroupStatus;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldAuthkey.
  ///
  /// In en, this message translates to:
  /// **'Auth key'**
  String get fieldAuthkey;

  /// No description provided for @fieldConnectionType.
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get fieldConnectionType;

  /// No description provided for @fieldCodename.
  ///
  /// In en, this message translates to:
  /// **'Codename'**
  String get fieldCodename;

  /// No description provided for @fieldModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get fieldModel;

  /// No description provided for @fieldImei.
  ///
  /// In en, this message translates to:
  /// **'IMEI'**
  String get fieldImei;

  /// No description provided for @fieldFirmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get fieldFirmware;

  /// No description provided for @fieldSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial'**
  String get fieldSerial;

  /// No description provided for @fieldBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get fieldBattery;

  /// No description provided for @fieldChargeStatus.
  ///
  /// In en, this message translates to:
  /// **'Charge status'**
  String get fieldChargeStatus;

  /// No description provided for @fieldLastCharge.
  ///
  /// In en, this message translates to:
  /// **'Last charge'**
  String get fieldLastCharge;

  /// No description provided for @fieldStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get fieldStorage;

  /// No description provided for @appManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'App management'**
  String get appManagementTitle;

  /// No description provided for @appManagementNone.
  ///
  /// In en, this message translates to:
  /// **'No installed apps'**
  String get appManagementNone;

  /// No description provided for @appManagementShowSystemApps.
  ///
  /// In en, this message translates to:
  /// **'Show system apps'**
  String get appManagementShowSystemApps;

  /// No description provided for @watchfaceManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Watchface management'**
  String get watchfaceManagementTitle;

  /// No description provided for @watchfaceManagementNone.
  ///
  /// In en, this message translates to:
  /// **'No installed watchfaces'**
  String get watchfaceManagementNone;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @externalLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Open external link'**
  String get externalLinkTitle;

  /// No description provided for @externalLinkDescription.
  ///
  /// In en, this message translates to:
  /// **'You are about to visit {url}\n\nThis website is operated by a third party, is not affiliated with ZeroBox, and its security is unknown. Please proceed with caution. Do you want to continue?'**
  String externalLinkDescription(String url);

  /// No description provided for @externalLinkAstroBoxResourceHint.
  ///
  /// In en, this message translates to:
  /// **'This appears to be an AstroBox resource. You can also view and install it within ZeroBox'**
  String get externalLinkAstroBoxResourceHint;

  /// No description provided for @continueToWebsite.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueToWebsite;

  /// No description provided for @viewInZeroBox.
  ///
  /// In en, this message translates to:
  /// **'View in ZeroBox'**
  String get viewInZeroBox;

  /// No description provided for @uninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstall;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @fail.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get fail;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @desktopTrayShow.
  ///
  /// In en, this message translates to:
  /// **'Show window'**
  String get desktopTrayShow;

  /// No description provided for @desktopTrayExit.
  ///
  /// In en, this message translates to:
  /// **'Exit ZeroBox'**
  String get desktopTrayExit;

  /// No description provided for @desktopCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit confirmation'**
  String get desktopCloseTitle;

  /// No description provided for @desktopCloseMessage.
  ///
  /// In en, this message translates to:
  /// **'Would you like to exit ZeroBox?'**
  String get desktopCloseMessage;

  /// No description provided for @desktopCloseRemember.
  ///
  /// In en, this message translates to:
  /// **'Do not ask again'**
  String get desktopCloseRemember;

  /// No description provided for @desktopCloseToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray'**
  String get desktopCloseToTray;

  /// No description provided for @desktopCloseExit.
  ///
  /// In en, this message translates to:
  /// **'Exit ZeroBox'**
  String get desktopCloseExit;

  /// No description provided for @settingsDesktopCloseBehavior.
  ///
  /// In en, this message translates to:
  /// **'Close button behavior'**
  String get settingsDesktopCloseBehavior;

  /// No description provided for @settingsDesktopCloseBehaviorDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose what happens when the main window is closed'**
  String get settingsDesktopCloseBehaviorDesc;

  /// No description provided for @desktopCloseBehaviorAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get desktopCloseBehaviorAsk;

  /// No description provided for @desktopCloseBehaviorExit.
  ///
  /// In en, this message translates to:
  /// **'Exit immediately'**
  String get desktopCloseBehaviorExit;

  /// No description provided for @desktopCloseBehaviorTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray'**
  String get desktopCloseBehaviorTray;

  /// No description provided for @multiDevice.
  ///
  /// In en, this message translates to:
  /// **'Multi-device'**
  String get multiDevice;

  /// No description provided for @quickApp.
  ///
  /// In en, this message translates to:
  /// **'Quickapp'**
  String get quickApp;

  /// No description provided for @miniprogram.
  ///
  /// In en, this message translates to:
  /// **'Miniprogram'**
  String get miniprogram;

  /// No description provided for @miniprograms.
  ///
  /// In en, this message translates to:
  /// **'Miniprograms'**
  String get miniprograms;

  /// No description provided for @watchface.
  ///
  /// In en, this message translates to:
  /// **'Watchface'**
  String get watchface;

  /// No description provided for @firmwareTool.
  ///
  /// In en, this message translates to:
  /// **'Firmware / Tool'**
  String get firmwareTool;

  /// No description provided for @fontPack.
  ///
  /// In en, this message translates to:
  /// **'Font Pack'**
  String get fontPack;

  /// No description provided for @iconPack.
  ///
  /// In en, this message translates to:
  /// **'Icon Pack'**
  String get iconPack;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @forcePaid.
  ///
  /// In en, this message translates to:
  /// **'Force Paid'**
  String get forcePaid;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noDescription;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @productAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get productAbout;

  /// No description provided for @productDeviceRequirements.
  ///
  /// In en, this message translates to:
  /// **'Device requirements'**
  String get productDeviceRequirements;

  /// No description provided for @productOtherVersions.
  ///
  /// In en, this message translates to:
  /// **'Other versions'**
  String get productOtherVersions;

  /// No description provided for @productInQueue.
  ///
  /// In en, this message translates to:
  /// **'In queue'**
  String get productInQueue;

  /// No description provided for @productShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get productShare;

  /// No description provided for @productViewOnBandBBS.
  ///
  /// In en, this message translates to:
  /// **'View on BandBBS'**
  String get productViewOnBandBBS;

  /// No description provided for @changeCdn.
  ///
  /// In en, this message translates to:
  /// **'Change CDN'**
  String get changeCdn;

  /// No description provided for @cdnErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'AstroBox data failed to load'**
  String get cdnErrorTitle;

  /// No description provided for @cdnErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Current CDN ({cdn}) could not fetch {path}. Would you like to switch CDN?'**
  String cdnErrorMessage(Object cdn, Object path);

  /// No description provided for @cdnErrorContinue.
  ///
  /// In en, this message translates to:
  /// **'Switch CDN'**
  String get cdnErrorContinue;

  /// No description provided for @cdnErrorCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cdnErrorCancel;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsSource.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsSource;

  /// No description provided for @settingsSourceRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get settingsSourceRestart;

  /// No description provided for @settingsQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get settingsQueue;

  /// No description provided for @settingsInstall.
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get settingsInstall;

  /// No description provided for @settingsTools.
  ///
  /// In en, this message translates to:
  /// **'Mysterious Tools'**
  String get settingsTools;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAccountLoginBBS.
  ///
  /// In en, this message translates to:
  /// **'Login to BandBBS'**
  String get settingsAccountLoginBBS;

  /// No description provided for @settingsAccountLoginBBSDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync purchased resources'**
  String get settingsAccountLoginBBSDesc;

  /// No description provided for @settingsAccountBandBbsSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get settingsAccountBandBbsSigningIn;

  /// No description provided for @settingsAccountBandBbsOpenedBrowser.
  ///
  /// In en, this message translates to:
  /// **'Browser opened. Complete BandBBS authorization there'**
  String get settingsAccountBandBbsOpenedBrowser;

  /// No description provided for @settingsAccountBandBbsSignedIn.
  ///
  /// In en, this message translates to:
  /// **'BandBBS signed in'**
  String get settingsAccountBandBbsSignedIn;

  /// No description provided for @settingsAccountBandBbsLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'BandBBS sign-in failed'**
  String get settingsAccountBandBbsLoginFailed;

  /// No description provided for @settingsBandBbsAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your BandBBS account in Settings first'**
  String get settingsBandBbsAccountRequired;

  /// No description provided for @settingsAccountBandBbsUser.
  ///
  /// In en, this message translates to:
  /// **'User ID: {userId}'**
  String settingsAccountBandBbsUser(Object userId);

  /// No description provided for @settingsAccountBBSAccount.
  ///
  /// In en, this message translates to:
  /// **'BandBBS account'**
  String get settingsAccountBBSAccount;

  /// No description provided for @bandBbsAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'BandBBS account'**
  String get bandBbsAccountTitle;

  /// No description provided for @bandBbsPurchasedResources.
  ///
  /// In en, this message translates to:
  /// **'Purchased resources'**
  String get bandBbsPurchasedResources;

  /// No description provided for @bandBbsResourceId.
  ///
  /// In en, this message translates to:
  /// **'Resource ID'**
  String get bandBbsResourceId;

  /// No description provided for @bandBbsResourceIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter BandBBS resource ID'**
  String get bandBbsResourceIdHint;

  /// No description provided for @bandBbsQueryResource.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get bandBbsQueryResource;

  /// No description provided for @bandBbsOpenResource.
  ///
  /// In en, this message translates to:
  /// **'View on BandBBS'**
  String get bandBbsOpenResource;

  /// No description provided for @bandBbsLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get bandBbsLogout;

  /// No description provided for @bandBbsLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get bandBbsLoggedOut;

  /// No description provided for @bandBbsLoadPreviews.
  ///
  /// In en, this message translates to:
  /// **'Load post previews'**
  String get bandBbsLoadPreviews;

  /// No description provided for @bandBbsLoadPreviewsDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically load attachment previews in the resource list'**
  String get bandBbsLoadPreviewsDesc;

  /// No description provided for @bandBbsShowAllCategories.
  ///
  /// In en, this message translates to:
  /// **'Show all categories'**
  String get bandBbsShowAllCategories;

  /// No description provided for @bandBbsShowAllCategoriesDesc.
  ///
  /// In en, this message translates to:
  /// **'Include categories for unsupported devices hidden by default'**
  String get bandBbsShowAllCategoriesDesc;

  /// No description provided for @settingsAccountSyncDevices.
  ///
  /// In en, this message translates to:
  /// **'Sync devices'**
  String get settingsAccountSyncDevices;

  /// No description provided for @settingsAccountSyncDevicesDesc.
  ///
  /// In en, this message translates to:
  /// **'Log in to Mi Account to sync paired devices'**
  String get settingsAccountSyncDevicesDesc;

  /// No description provided for @settingsMiAccount.
  ///
  /// In en, this message translates to:
  /// **'Mi Account'**
  String get settingsMiAccount;

  /// No description provided for @settingsMiAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in and sync authkeys from bound devices'**
  String get settingsMiAccountDesc;

  /// No description provided for @settingsMiAccountLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Mi Account login'**
  String get settingsMiAccountLoginTitle;

  /// No description provided for @settingsMiAccountUsername.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsMiAccountUsername;

  /// No description provided for @settingsMiAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsMiAccountPassword;

  /// No description provided for @settingsMiAccountRememberCredentials.
  ///
  /// In en, this message translates to:
  /// **'Remember account and password'**
  String get settingsMiAccountRememberCredentials;

  /// No description provided for @settingsMiAccountLoginAndSync.
  ///
  /// In en, this message translates to:
  /// **'Sign in and sync'**
  String get settingsMiAccountLoginAndSync;

  /// No description provided for @settingsMiAccountMissingCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your Mi Account and password'**
  String get settingsMiAccountMissingCredentials;

  /// No description provided for @settingsMiAccountTwoFactorPrompt.
  ///
  /// In en, this message translates to:
  /// **'Complete Mi Account two-factor verification in the verification page'**
  String get settingsMiAccountTwoFactorPrompt;

  /// No description provided for @settingsMiAccountLoginWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'The login window was closed'**
  String get settingsMiAccountLoginWindowClosed;

  /// No description provided for @settingsMiAccountSyncedDevices.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} Mi devices'**
  String settingsMiAccountSyncedDevices(int count);

  /// No description provided for @settingsHuamiAccount.
  ///
  /// In en, this message translates to:
  /// **'Amazfit account'**
  String get settingsHuamiAccount;

  /// No description provided for @settingsHuamiAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in and save credentials for Zepp store access'**
  String get settingsHuamiAccountDesc;

  /// No description provided for @settingsHuamiAccountSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get settingsHuamiAccountSigningIn;

  /// No description provided for @settingsHuamiAccountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Amazfit account signed in'**
  String get settingsHuamiAccountSignedIn;

  /// No description provided for @settingsHuamiAccountUser.
  ///
  /// In en, this message translates to:
  /// **'Account: {username}'**
  String settingsHuamiAccountUser(Object username);

  /// No description provided for @settingsHuamiAccountLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Amazfit account login'**
  String get settingsHuamiAccountLoginTitle;

  /// No description provided for @settingsHuamiAccountUsername.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsHuamiAccountUsername;

  /// No description provided for @settingsHuamiAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsHuamiAccountPassword;

  /// No description provided for @settingsHuamiAccountRememberCredentials.
  ///
  /// In en, this message translates to:
  /// **'Remember password'**
  String get settingsHuamiAccountRememberCredentials;

  /// No description provided for @settingsHuamiAccountLoginAndSave.
  ///
  /// In en, this message translates to:
  /// **'Sign in and save'**
  String get settingsHuamiAccountLoginAndSave;

  /// No description provided for @settingsHuamiAccountMissingCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your Amazfit account and password'**
  String get settingsHuamiAccountMissingCredentials;

  /// No description provided for @settingsHuamiAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Amazfit account in Settings first'**
  String get settingsHuamiAccountRequired;

  /// No description provided for @unsupportedDeviceResourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsupported device/resource type'**
  String get unsupportedDeviceResourceTitle;

  /// No description provided for @unsupportedDeviceResourceMessage.
  ///
  /// In en, this message translates to:
  /// **'ZeroBox does not currently support this device or resource type. Do not attempt to install resources from this category, as unexpected issues may occur.'**
  String get unsupportedDeviceResourceMessage;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get understood;

  /// No description provided for @settingsGeneralLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsGeneralLanguage;

  /// No description provided for @settingsGeneralLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Change app display language'**
  String get settingsGeneralLanguageDesc;

  /// No description provided for @settingsWideNavigationPosition.
  ///
  /// In en, this message translates to:
  /// **'Navigation position'**
  String get settingsWideNavigationPosition;

  /// No description provided for @settingsWideNavigationPositionDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust side tab placement in the wide-screen state'**
  String get settingsWideNavigationPositionDesc;

  /// No description provided for @settingsWideNavigationPositionBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get settingsWideNavigationPositionBottom;

  /// No description provided for @settingsWideNavigationPositionCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get settingsWideNavigationPositionCenter;

  /// No description provided for @settingsWideNavigationPositionSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get settingsWideNavigationPositionSplit;

  /// No description provided for @settingsGeneralTranslateTeam.
  ///
  /// In en, this message translates to:
  /// **'Translation contributors'**
  String get settingsGeneralTranslateTeam;

  /// No description provided for @settingsAutoReconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto reconnect'**
  String get settingsAutoReconnectTitle;

  /// No description provided for @settingsAutoReconnectDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically reconnect to the last paired device on startup'**
  String get settingsAutoReconnectDesc;

  /// No description provided for @settingsGeneralDebugWindow.
  ///
  /// In en, this message translates to:
  /// **'Debug window'**
  String get settingsGeneralDebugWindow;

  /// No description provided for @settingsGeneralDebugWindowDesc.
  ///
  /// In en, this message translates to:
  /// **'Show a floating debug panel'**
  String get settingsGeneralDebugWindowDesc;

  /// No description provided for @settingsSourceOfficialCdn.
  ///
  /// In en, this message translates to:
  /// **'GitHub source CDN'**
  String get settingsSourceOfficialCdn;

  /// No description provided for @settingsSourceOfficialCdnDesc.
  ///
  /// In en, this message translates to:
  /// **'CDN used to fetch the GitHub-hosted community index'**
  String get settingsSourceOfficialCdnDesc;

  /// No description provided for @settingsQueueAutoInstall.
  ///
  /// In en, this message translates to:
  /// **'Auto install'**
  String get settingsQueueAutoInstall;

  /// No description provided for @settingsQueueAutoInstallDesc.
  ///
  /// In en, this message translates to:
  /// **'Start installation automatically after download'**
  String get settingsQueueAutoInstallDesc;

  /// No description provided for @settingsQueueDontClear.
  ///
  /// In en, this message translates to:
  /// **'Don\'t clear install queue'**
  String get settingsQueueDontClear;

  /// No description provided for @settingsQueueDontClearDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep completed items in the install queue'**
  String get settingsQueueDontClearDesc;

  /// No description provided for @settingsInstallSendInterval.
  ///
  /// In en, this message translates to:
  /// **'Packet interval'**
  String get settingsInstallSendInterval;

  /// No description provided for @settingsInstallSendIntervalDesc.
  ///
  /// In en, this message translates to:
  /// **'Delay between Bluetooth fragments during install'**
  String get settingsInstallSendIntervalDesc;

  /// No description provided for @settingsToolsUnlockCode.
  ///
  /// In en, this message translates to:
  /// **'Calculate unlock code'**
  String get settingsToolsUnlockCode;

  /// No description provided for @settingsToolsUnlockCodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate a Mi Wear unlock code from MAC and SN'**
  String get settingsToolsUnlockCodeDesc;

  /// No description provided for @settingsToolsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock code'**
  String get settingsToolsDialogTitle;

  /// No description provided for @settingsToolsMac.
  ///
  /// In en, this message translates to:
  /// **'MAC address'**
  String get settingsToolsMac;

  /// No description provided for @settingsToolsSn.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get settingsToolsSn;

  /// No description provided for @settingsToolsNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get settingsToolsNoticeTitle;

  /// No description provided for @settingsToolsNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Unlocking may void your warranty or cause data loss. Use at your own risk.'**
  String get settingsToolsNoticeBody;

  /// No description provided for @settingsToolsAgree.
  ///
  /// In en, this message translates to:
  /// **'I understand the risks'**
  String get settingsToolsAgree;

  /// No description provided for @settingsToolsCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get settingsToolsCalculate;

  /// No description provided for @settingsToolsResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get settingsToolsResult;

  /// No description provided for @settingsToolsDialogUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get settingsToolsDialogUsage;

  /// No description provided for @settingsToolsDialogUsageInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter the MAC address and serial number shown on the device.'**
  String get settingsToolsDialogUsageInfo;

  /// No description provided for @settingsAboutAboutAstrobox.
  ///
  /// In en, this message translates to:
  /// **'About ZeroBox'**
  String get settingsAboutAboutAstrobox;

  /// No description provided for @settingsAboutAboutAstroboxDesc.
  ///
  /// In en, this message translates to:
  /// **'Version, changelog and team'**
  String get settingsAboutAboutAstroboxDesc;

  /// No description provided for @settingsAboutDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get settingsAboutDisclaimer;

  /// No description provided for @settingsAboutDisclaimerDesc.
  ///
  /// In en, this message translates to:
  /// **'User agreement and liability statement'**
  String get settingsAboutDisclaimerDesc;

  /// No description provided for @settingsAboutOpenlog.
  ///
  /// In en, this message translates to:
  /// **'Log folder'**
  String get settingsAboutOpenlog;

  /// No description provided for @settingsAboutOpenlogDesc.
  ///
  /// In en, this message translates to:
  /// **'Open the log directory in file manager'**
  String get settingsAboutOpenlogDesc;

  /// No description provided for @settingsAboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get settingsAboutWebsite;

  /// No description provided for @settingsAboutWebsiteDesc.
  ///
  /// In en, this message translates to:
  /// **'Visit zerobox.zxor.org'**
  String get settingsAboutWebsiteDesc;

  /// No description provided for @settingsAboutQQ.
  ///
  /// In en, this message translates to:
  /// **'QQ group'**
  String get settingsAboutQQ;

  /// No description provided for @settingsAboutQQDesc.
  ///
  /// In en, this message translates to:
  /// **'Join the community chat'**
  String get settingsAboutQQDesc;

  /// No description provided for @settingsAboutLicences.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settingsAboutLicences;

  /// No description provided for @settingsAboutLicencesDesc.
  ///
  /// In en, this message translates to:
  /// **'Licenses for Flutter, dependencies and open source components'**
  String get settingsAboutLicencesDesc;

  /// No description provided for @settingsGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get settingsGuest;

  /// No description provided for @settingsTapToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Tap to sign in'**
  String get settingsTapToSignIn;

  /// No description provided for @settingsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsConnected;

  /// No description provided for @settingsNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get settingsNotConnected;

  /// No description provided for @settingsNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsNotSet;

  /// No description provided for @settingsOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsOn;

  /// No description provided for @settingsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsOff;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// No description provided for @settingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// No description provided for @settingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// No description provided for @settingsOledDark.
  ///
  /// In en, this message translates to:
  /// **'OLED dark'**
  String get settingsOledDark;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Change app theme appearance'**
  String get settingsThemeModeDesc;

  /// No description provided for @settingsDynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Dynamic color'**
  String get settingsDynamicColor;

  /// No description provided for @settingsDynamicColorDesc.
  ///
  /// In en, this message translates to:
  /// **'Use system accent colors for the app theme'**
  String get settingsDynamicColorDesc;

  /// No description provided for @settingsColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get settingsColorScheme;

  /// No description provided for @settingsColorSchemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose the app accent color'**
  String get settingsColorSchemeDesc;

  /// No description provided for @settingsColorSchemePink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get settingsColorSchemePink;

  /// No description provided for @settingsColorSchemePurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get settingsColorSchemePurple;

  /// No description provided for @settingsColorSchemeTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get settingsColorSchemeTeal;

  /// No description provided for @settingsColorSchemeGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get settingsColorSchemeGreen;

  /// No description provided for @settingsColorSchemeRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get settingsColorSchemeRed;

  /// No description provided for @settingsColorSchemeAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get settingsColorSchemeAmber;

  /// No description provided for @settingsDesktopAccentSource.
  ///
  /// In en, this message translates to:
  /// **'Linux accent source'**
  String get settingsDesktopAccentSource;

  /// No description provided for @settingsDesktopAccentSourceDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose whether to read accent colors from GTK or Qt'**
  String get settingsDesktopAccentSourceDesc;

  /// No description provided for @settingsDesktopAccentSourceSystem.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsDesktopAccentSourceSystem;

  /// No description provided for @settingsDesktopAccentSourceGtk.
  ///
  /// In en, this message translates to:
  /// **'GTK'**
  String get settingsDesktopAccentSourceGtk;

  /// No description provided for @settingsDesktopAccentSourceQt.
  ///
  /// In en, this message translates to:
  /// **'Qt'**
  String get settingsDesktopAccentSourceQt;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settingsConfirm;

  /// No description provided for @settingsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get settingsOpen;

  /// No description provided for @settingsVisit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get settingsVisit;

  /// No description provided for @settingsTeamSlogan.
  ///
  /// In en, this message translates to:
  /// **'A pretty fast wearable management tool for VelaOS and ZeppOS.'**
  String get settingsTeamSlogan;

  /// No description provided for @settingsTeamGitHub.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get settingsTeamGitHub;

  /// No description provided for @settingsTeamMembers.
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get settingsTeamMembers;

  /// No description provided for @settingsTeamRoleMain.
  ///
  /// In en, this message translates to:
  /// **'Main Developer / Designer'**
  String get settingsTeamRoleMain;

  /// No description provided for @settingsTeamRoleZeppOS.
  ///
  /// In en, this message translates to:
  /// **'ZeppOS implementation'**
  String get settingsTeamRoleZeppOS;

  /// No description provided for @settingsAboutSoftware.
  ///
  /// In en, this message translates to:
  /// **'About software'**
  String get settingsAboutSoftware;

  /// No description provided for @settingsAboutSoftwareDesc.
  ///
  /// In en, this message translates to:
  /// **'Version, changelog and development team'**
  String get settingsAboutSoftwareDesc;

  /// No description provided for @settingsAboutSoftwareTagline.
  ///
  /// In en, this message translates to:
  /// **'A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter'**
  String get settingsAboutSoftwareTagline;

  /// No description provided for @settingsAboutSoftwareRepository.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub repository'**
  String get settingsAboutSoftwareRepository;

  /// No description provided for @settingsAboutSoftwareTeam.
  ///
  /// In en, this message translates to:
  /// **'Development team'**
  String get settingsAboutSoftwareTeam;

  /// No description provided for @settingsAboutSoftwareReleaseName.
  ///
  /// In en, this message translates to:
  /// **'Current release: development preview'**
  String get settingsAboutSoftwareReleaseName;

  /// No description provided for @settingsAboutSoftwareReleaseBody.
  ///
  /// In en, this message translates to:
  /// **'This update includes:\n• System accent color support and theme refinements\n• Redesigned resource detail and list pages with grouped device filters\n• Replaced team page with about software page; localized settings\n• Improved Xiaomi SAR controller send error handling\n• Stabilized Linux classic SPP connect cancellation and timeouts\n• Updated ARB localizations and generated l10n files'**
  String get settingsAboutSoftwareReleaseBody;

  /// No description provided for @settingsAboutSoftwareBuildInfo.
  ///
  /// In en, this message translates to:
  /// **'Build info'**
  String get settingsAboutSoftwareBuildInfo;

  /// No description provided for @settingsAboutSoftwareCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright © ZeroBox contributors'**
  String get settingsAboutSoftwareCopyright;

  /// No description provided for @acknowledgementsKazumi.
  ///
  /// In en, this message translates to:
  /// **'Reference for Material Design components and UI patterns.'**
  String get acknowledgementsKazumi;

  /// No description provided for @acknowledgementsAstroBoxPublic.
  ///
  /// In en, this message translates to:
  /// **'Reference for UI structure, resource workflows, and interaction design.'**
  String get acknowledgementsAstroBoxPublic;

  /// No description provided for @acknowledgementsAstroBoxNgCore.
  ///
  /// In en, this message translates to:
  /// **'Reference for Xiaomi device protocols, install flows, and transfer behavior.'**
  String get acknowledgementsAstroBoxNgCore;

  /// No description provided for @acknowledgementsAstroBoxNgBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Reference for Bluetooth connection behavior.'**
  String get acknowledgementsAstroBoxNgBluetooth;

  /// No description provided for @acknowledgementsAstroBoxNgAccount.
  ///
  /// In en, this message translates to:
  /// **'Reference for Xiaomi account login, device sync, and authkey retrieval flows.'**
  String get acknowledgementsAstroBoxNgAccount;

  /// No description provided for @acknowledgementsAstroBoxNgProvider.
  ///
  /// In en, this message translates to:
  /// **'Reference for community resource indexes, CDN handling, and manifest parsing flows.'**
  String get acknowledgementsAstroBoxNgProvider;

  /// No description provided for @acknowledgementsAstroBoxNgAppWasm.
  ///
  /// In en, this message translates to:
  /// **'Reference for Web Serial and browser-side connection flows.'**
  String get acknowledgementsAstroBoxNgAppWasm;

  /// No description provided for @acknowledgementsGadgetbridge.
  ///
  /// In en, this message translates to:
  /// **'Reference for ZeppOS and wearable protocol research.'**
  String get acknowledgementsGadgetbridge;

  /// No description provided for @resourceHomeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Home page is under construction'**
  String get resourceHomeEmptyTitle;

  /// No description provided for @resourceHomeEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can get resources from the library'**
  String get resourceHomeEmptySubtitle;

  /// No description provided for @resourceCreatorEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator center is under construction'**
  String get resourceCreatorEmptyTitle;

  /// No description provided for @resourceCreatorEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can manage acquired resources in the library'**
  String get resourceCreatorEmptySubtitle;

  /// No description provided for @openResourceLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open resource library'**
  String get openResourceLibrary;

  /// No description provided for @downloadQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Download queue'**
  String get downloadQueueTitle;

  /// No description provided for @installQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Install queue'**
  String get installQueueTitle;

  /// No description provided for @queueClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get queueClear;

  /// No description provided for @queueStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get queueStart;

  /// No description provided for @queuePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get queuePause;

  /// No description provided for @downloadQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No download tasks'**
  String get downloadQueueEmpty;

  /// No description provided for @installQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No install tasks'**
  String get installQueueEmpty;

  /// No description provided for @localAppInstall.
  ///
  /// In en, this message translates to:
  /// **'Local app install'**
  String get localAppInstall;

  /// No description provided for @localWatchfaceInstall.
  ///
  /// In en, this message translates to:
  /// **'Local watchface install'**
  String get localWatchfaceInstall;

  /// No description provided for @localFirmwareInstall.
  ///
  /// In en, this message translates to:
  /// **'Local firmware install'**
  String get localFirmwareInstall;

  /// No description provided for @queueStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get queueStatusPending;

  /// No description provided for @queueStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String queueStatusDownloading(String percent);

  /// No description provided for @queueStatusInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing {percent}%'**
  String queueStatusInstalling(String percent);

  /// No description provided for @queueStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get queueStatusCompleted;

  /// No description provided for @queueStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get queueStatusFailed;

  /// No description provided for @queueDragToInstall.
  ///
  /// In en, this message translates to:
  /// **'Release to add to install queue'**
  String get queueDragToInstall;

  /// No description provided for @queueAddedFiles.
  ///
  /// In en, this message translates to:
  /// **'Added {count} files to install queue'**
  String queueAddedFiles(int count);

  /// No description provided for @installQueueReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Read failed'**
  String get installQueueReadFailed;

  /// No description provided for @installQueueUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file'**
  String get installQueueUnsupportedFile;

  /// No description provided for @timeTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String timeTodayAt(Object time);

  /// No description provided for @timeYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String timeYesterdayAt(Object time);

  /// No description provided for @settingsAccountBandBbsAccount.
  ///
  /// In en, this message translates to:
  /// **'BandBBS Account'**
  String get settingsAccountBandBbsAccount;

  /// No description provided for @bandBbsResourceQueryTitle.
  ///
  /// In en, this message translates to:
  /// **'Install purchased resources'**
  String get bandBbsResourceQueryTitle;

  /// No description provided for @settingsAboutLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get settingsAboutLogs;

  /// No description provided for @settingsAboutLogsDescription.
  ///
  /// In en, this message translates to:
  /// **'Runtime logs from the last 7 days. On Android, they can be viewed and copied in the Files app.'**
  String get settingsAboutLogsDescription;

  /// No description provided for @settingsAboutLogsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open logs folder'**
  String get settingsAboutLogsOpen;

  /// No description provided for @settingsAboutLogsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the logs folder'**
  String get settingsAboutLogsOpenFailed;

  /// No description provided for @settingsAboutLogsWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensitive information warning'**
  String get settingsAboutLogsWarningTitle;

  /// No description provided for @settingsAboutLogsWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Logs may contain BandBBS, Xiaomi, or Amazfit login credentials and other sensitive information. Do not share them with anyone other than official ZeroBox maintainers!'**
  String get settingsAboutLogsWarningMessage;

  /// No description provided for @pluginPermissionRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin permission request'**
  String get pluginPermissionRequestTitle;

  /// No description provided for @pluginPermissionRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{plugin}\" wants to {operation}.'**
  String pluginPermissionRequestMessage(Object plugin, Object operation);

  /// No description provided for @pluginPermissionOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get pluginPermissionOnce;

  /// No description provided for @pluginPermissionSession.
  ///
  /// In en, this message translates to:
  /// **'Allow this run'**
  String get pluginPermissionSession;

  /// No description provided for @pluginPermissionAlways.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get pluginPermissionAlways;

  /// No description provided for @pluginPermissionDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get pluginPermissionDeny;

  /// No description provided for @pluginPermissionOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'open an external link'**
  String get pluginPermissionOpenExternal;

  /// No description provided for @pluginPermissionPickFile.
  ///
  /// In en, this message translates to:
  /// **'access host files'**
  String get pluginPermissionPickFile;

  /// No description provided for @pluginPermissionExportFile.
  ///
  /// In en, this message translates to:
  /// **'export a file to the host'**
  String get pluginPermissionExportFile;

  /// No description provided for @pluginPermissionNetwork.
  ///
  /// In en, this message translates to:
  /// **'access the network'**
  String get pluginPermissionNetwork;

  /// No description provided for @pluginPermissionInterconnect.
  ///
  /// In en, this message translates to:
  /// **'communicate with device applications'**
  String get pluginPermissionInterconnect;

  /// No description provided for @pluginPermissionProvider.
  ///
  /// In en, this message translates to:
  /// **'register a resource provider'**
  String get pluginPermissionProvider;

  /// No description provided for @pluginPermissionReadDevice.
  ///
  /// In en, this message translates to:
  /// **'read device information'**
  String get pluginPermissionReadDevice;

  /// No description provided for @pluginPermissionOperateDevice.
  ///
  /// In en, this message translates to:
  /// **'operate a device'**
  String get pluginPermissionOperateDevice;

  /// No description provided for @pluginPermissionObserveProtocol.
  ///
  /// In en, this message translates to:
  /// **'read raw device protocol data'**
  String get pluginPermissionObserveProtocol;

  /// No description provided for @pluginPermissionSendProtocol.
  ///
  /// In en, this message translates to:
  /// **'send raw protocol data to a device'**
  String get pluginPermissionSendProtocol;

  /// No description provided for @pluginErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin runtime error'**
  String get pluginErrorTitle;

  /// No description provided for @pluginErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{plugin}\" encountered a runtime error:\n\n{error}'**
  String pluginErrorMessage(Object plugin, Object error);

  /// No description provided for @pluginErrorClearData.
  ///
  /// In en, this message translates to:
  /// **'Clear plugin data'**
  String get pluginErrorClearData;

  /// No description provided for @pluginErrorUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall plugin'**
  String get pluginErrorUninstall;

  /// No description provided for @pluginErrorSafeMode.
  ///
  /// In en, this message translates to:
  /// **'Enter safe mode'**
  String get pluginErrorSafeMode;

  /// No description provided for @pluginSafeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin safe mode is enabled'**
  String get pluginSafeModeTitle;

  /// No description provided for @pluginSafeModeDescription.
  ///
  /// In en, this message translates to:
  /// **'All plugins are stopped and will reload after safe mode is disabled.'**
  String get pluginSafeModeDescription;

  /// No description provided for @pluginSafeModeExit.
  ///
  /// In en, this message translates to:
  /// **'Exit safe mode'**
  String get pluginSafeModeExit;

  /// No description provided for @debugWindow.
  ///
  /// In en, this message translates to:
  /// **'Debug window'**
  String get debugWindow;

  /// No description provided for @debugWindowDescription.
  ///
  /// In en, this message translates to:
  /// **'Toggle the ZeroBox debug window'**
  String get debugWindowDescription;

  /// No description provided for @debugWindowOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to change the debug window state'**
  String get debugWindowOperationFailed;

  /// No description provided for @resourceTypeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Incorrect resource type'**
  String get resourceTypeErrorTitle;

  /// No description provided for @resourceTypeUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized resource type'**
  String get resourceTypeUnknownTitle;

  /// No description provided for @resourceTypeMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'This appears to be a {detectedType} resource, but you selected {selectedType}. Choose how to install it'**
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType);

  /// No description provided for @resourcePlatformMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'This appears to be a {resourceType} resource for a {resourcePlatform} device, but the connected device is {deviceName} ({devicePlatform}). It is not supported and forcing installation may cause unexpected problems'**
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  );

  /// No description provided for @resourceTypeUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'ZeroBox cannot identify the actual resource type. Install it as {selectedType} anyway?'**
  String resourceTypeUnknownMessage(Object selectedType);

  /// No description provided for @resourceInstallCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel installation'**
  String get resourceInstallCancel;

  /// No description provided for @resourceInstallAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get resourceInstallAcknowledge;

  /// No description provided for @resourceInstallForce.
  ///
  /// In en, this message translates to:
  /// **'Force install'**
  String get resourceInstallForce;

  /// No description provided for @resourceInstallForceCountdown.
  ///
  /// In en, this message translates to:
  /// **'Force install ({seconds}s)'**
  String resourceInstallForceCountdown(int seconds);

  /// No description provided for @resourceInstallAsSelected.
  ///
  /// In en, this message translates to:
  /// **'Continue as {type}'**
  String resourceInstallAsSelected(Object type);

  /// No description provided for @resourceInstallAsSelectedCountdown.
  ///
  /// In en, this message translates to:
  /// **'Continue as {type} ({seconds}s)'**
  String resourceInstallAsSelectedCountdown(Object type, int seconds);

  /// No description provided for @resourceInstallAsDetected.
  ///
  /// In en, this message translates to:
  /// **'Install as {type}'**
  String resourceInstallAsDetected(Object type);

  /// No description provided for @resourceTypeApp.
  ///
  /// In en, this message translates to:
  /// **'miniprogram'**
  String get resourceTypeApp;

  /// No description provided for @resourceTypeQuickApp.
  ///
  /// In en, this message translates to:
  /// **'quick app'**
  String get resourceTypeQuickApp;

  /// No description provided for @resourceTypeWatchface.
  ///
  /// In en, this message translates to:
  /// **'watchface'**
  String get resourceTypeWatchface;

  /// No description provided for @resourceTypeFirmware.
  ///
  /// In en, this message translates to:
  /// **'firmware'**
  String get resourceTypeFirmware;

  /// No description provided for @resourceInstallConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Install {type}'**
  String resourceInstallConfirmTitle(Object type);

  /// No description provided for @resourceInstallConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Install {fileName} ({fileSize})?'**
  String resourceInstallConfirmMessage(Object fileName, Object fileSize);

  /// No description provided for @resourceInstallConfirm.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get resourceInstallConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
