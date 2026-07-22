import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsBatterySystem extends System {
  static const endpoint = 0x0029;
  static const _request = 0x03;
  static const _reply = 0x04;

  Completer<BatteryStatus>? _pending;
  bool encrypted = true;

  ZeppOsDeviceComponent get _component =>
      entity.getRequired<ZeppOsDeviceComponent>();

  Future<BatteryStatus> fetchBatteryInfo() async {
    final pending = _pending;
    if (pending != null) {
      return pending.future.timeout(const Duration(seconds: 8));
    }
    final completer = Completer<BatteryStatus>();
    _pending = completer;
    try {
      await _component.sendToEndpoint(
        endpoint,
        Uint8List.fromList(const [_request]),
        encrypted: encrypted,
      );
      return await completer.future.timeout(const Duration(seconds: 8));
    } finally {
      if (identical(_pending, completer)) _pending = null;
    }
  }

  void handlePayload(Uint8List payload) {
    if (payload.length < 4 || payload[0] != _reply) return;
    final battery = BatteryStatus(
      capacity: payload[2].clamp(0, 100).toInt(),
      chargeStatus: payload[3] == 1
          ? ChargeStatus.charging
          : ChargeStatus.notCharging,
    );
    entity.emit(BatteryUpdated(deviceId: entity.id, battery: battery));
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(battery);
  }

  @override
  void onData(Uint8List data) {}
}
