import 'dart:async';

import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/devices/controllers/remote_device_manager.dart';
import 'package:zerobox/src/host/application_host_provider.dart';
import 'package:zerobox/src/host/gui_application_host.dart';

List<dynamic> guiHostOverrides() => [
  applicationHostProvider.overrideWith((ref) {
    final host = createGuiApplicationHost();
    ref.onDispose(() => unawaited(host.close()));
    return host;
  }),
  deviceManagerProvider.overrideWith(HostDeviceManager.new),
  appSettingsProvider.overrideWith(HostAppSettingsNotifier.new),
];
