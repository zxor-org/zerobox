import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/zerobox_app.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/license_registry_service.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/features/devices/widgets/device_deep_link_handler.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();
  await SharedPrefsService.instance.init();
  await LicenseRegistryService.registerThirdPartyLicenses();
  runApp(
    ProviderScope(
      overrides: [initialDeepLinksProvider.overrideWithValue(args)],
      child: const ZeroBoxApp(),
    ),
  );
}
