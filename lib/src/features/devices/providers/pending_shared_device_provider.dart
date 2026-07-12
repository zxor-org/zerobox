import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/models/bt_models.dart';

class PendingSharedDeviceNotifier extends Notifier<MiWearState?> {
  @override
  MiWearState? build() => null;

  void set(MiWearState? device) => state = device;
}

final pendingSharedDeviceProvider =
    NotifierProvider<PendingSharedDeviceNotifier, MiWearState?>(
      PendingSharedDeviceNotifier.new,
    );
