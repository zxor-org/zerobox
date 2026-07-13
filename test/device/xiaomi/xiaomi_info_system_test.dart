import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/xiaomi/components/info_system.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;

void main() {
  test('emits battery updates from persistent battery reports', () async {
    final eventBus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi',
      transport: _UnusedTransport(),
      eventBus: eventBus,
    );
    final system = XiaomiInfoSystem();
    entity.registerSystem(system);
    final event = eventBus.stream
        .where((event) => event is BatteryUpdated)
        .cast<BatteryUpdated>()
        .first;

    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.REPORT_BATTERY_STATUS.value,
        system: pb_system.System(
          batteryStatus: pb_system.DeviceStatus_Battery(
            capacity: 73,
            chargeStatus: pb_system.DeviceStatus_Battery_ChargeStatus.CHARGING,
            chargeInfo: pb_system.DeviceStatus_Battery_ChargeInfo(
              state: 1,
              timestamp: 1234,
            ),
          ),
        ),
      ),
    );

    final update = await event;
    expect(update.deviceId, 'device-a');
    expect(update.battery.capacity, 73);
    expect(update.battery.chargeStatus, ChargeStatus.charging);
    expect(update.battery.chargeInfo?.state, 1);
    expect(update.battery.chargeInfo?.timestamp, 1234);

    eventBus.dispose();
  });
}

class _UnusedTransport implements Transport {
  @override
  String get deviceId => 'device-a';

  @override
  String get deviceName => 'Device A';

  @override
  Stream<Uint8List> get incomingData => const Stream.empty();

  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> dispose() async {}
}
