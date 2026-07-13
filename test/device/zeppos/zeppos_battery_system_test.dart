import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_battery_system.dart';

void main() {
  test(
    'emits battery updates from endpoint reports without a request',
    () async {
      final eventBus = DeviceEventBus();
      final entity = DeviceEntity(
        id: 'zepp-device',
        kind: 'zepp',
        transport: _UnusedTransport(),
        eventBus: eventBus,
      );
      final system = ZeppOsBatterySystem();
      entity.registerSystem(system);
      final event = eventBus.stream
          .where((event) => event is BatteryUpdated)
          .cast<BatteryUpdated>()
          .first;

      system.handlePayload(Uint8List.fromList([0x04, 0x00, 86, 1]));

      final update = await event;
      expect(update.deviceId, 'zepp-device');
      expect(update.battery.capacity, 86);
      expect(update.battery.chargeStatus, ChargeStatus.charging);

      eventBus.dispose();
    },
  );
}

class _UnusedTransport implements Transport {
  @override
  String get deviceId => 'zepp-device';

  @override
  String get deviceName => 'Zepp Device';

  @override
  Stream<Uint8List> get incomingData => const Stream.empty();

  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> dispose() async {}
}
