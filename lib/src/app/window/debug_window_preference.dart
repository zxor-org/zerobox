import 'package:zerobox/src/core/services/shared_prefs_service.dart';

const _debugWindowEnabledKey = 'window.debug.enabled';

bool isDebugWindowEnabled() =>
    SharedPrefsService.instance.getBool(_debugWindowEnabledKey) ?? false;

Future<void> setDebugWindowEnabled(bool enabled) =>
    SharedPrefsService.instance.setBool(_debugWindowEnabledKey, enabled);
