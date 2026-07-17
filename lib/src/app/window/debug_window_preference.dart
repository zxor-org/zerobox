import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';

const _debugWindowEnabledKey = 'window.debug.enabled';

bool isDebugWindowEnabled() =>
    SharedPrefsService.instance.getBool(_debugWindowEnabledKey) ?? false;

Future<void> setDebugWindowEnabled(bool enabled) =>
    SharedPrefsService.instance.setBool(_debugWindowEnabledKey, enabled);

class DebugWindowEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => isDebugWindowEnabled();

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await setDebugWindowEnabled(enabled);
  }
}

final debugWindowEnabledProvider =
    NotifierProvider<DebugWindowEnabledNotifier, bool>(
      DebugWindowEnabledNotifier.new,
    );
