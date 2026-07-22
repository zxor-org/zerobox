import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/device/core/ble_requirement.dart';

abstract class Transport {
  String get deviceId;
  String get deviceName;
  Stream<Uint8List> get incomingData;
  Stream<bool> get connectionState;
  Future<void> send(Uint8List data);
  Future<void> dispose();
}

abstract class CharacteristicTransport implements Transport {
  int? get maxWriteLength;

  Future<void> sendToCharacteristic(
    Uint8List data,
    BleRequiredCharacteristic characteristic, {
    bool? withResponse,
  });

  Future<StreamSubscription<Uint8List>?> subscribeToCharacteristic(
    BleRequiredCharacteristic characteristic,
    void Function(Uint8List data) onData,
  );
}

class TransportException implements Exception {
  const TransportException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message (caused by $cause)';
}
