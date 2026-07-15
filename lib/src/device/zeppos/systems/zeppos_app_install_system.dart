import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:zerobox/src/device/core/ble_requirement.dart';
import 'package:zerobox/src/device/core/ble_transport.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/install/zeppos_package_parser.dart';

class ZeppOsAppInstallSystem extends System {
  static const _serviceUuid = '00001530-0000-3512-2118-0009af100700';
  static const _control = BleRequiredCharacteristic(
    serviceUuid: _serviceUuid,
    characteristicUuid: '00001531-0000-3512-2118-0009af100700',
    label: 'Zepp OS firmware control',
  );
  static const _data = BleRequiredCharacteristic(
    serviceUuid: _serviceUuid,
    characteristicUuid: '00001532-0000-3512-2118-0009af100700',
    label: 'Zepp OS firmware data',
  );

  static const _response = 0x10;
  static const _success = 0x01;
  static const _requestParameters = 0xd0;
  static const _sendInfo = 0xd2;
  static const _startTransfer = 0xd3;
  static const _progress = 0xd4;
  static const _completeTransfer = 0xd5;
  static const _finalize = 0xd6;

  final _notifications = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _controlSubscription;
  bool _installing = false;

  Future<void> install(
    ZeppOsInstallPackage package, {
    void Function(double progress)? onProgress,
  }) async {
    if (_installing) throw StateError('Another Zepp OS install is in progress');
    final transport = entity.transport;
    if (transport is! CharacteristicTransport) {
      throw UnsupportedError(
        'Zepp OS application installation requires a BLE characteristic transport',
      );
    }
    _installing = true;
    final bleTransport = transport is BleTransport ? transport : null;
    try {
      if (bleTransport != null) {
        // Gadgetbridge requests 247 after authentication when high MTU is
        // enabled, but does not require it for application installation.
        // Some devices (including some Mi Band 7 stacks) remain at MTU 23.
        await bleTransport.requestMtu(247);
      }
      bleTransport?.beginExclusiveCharacteristicWrites([
        _control.characteristicUuid,
        _data.characteristicUuid,
      ]);
      // Gadgetbridge disables the regular Zepp OS 2021 notification stream
      // for the entire firmware operation. Otherwise app/service traffic can
      // interrupt the firmware-control and firmware-data transaction.
      await bleTransport?.suspendProtocolNotifications();
      _controlSubscription ??= await transport.subscribeToCharacteristic(
        _control,
        (data) => _notifications.add(Uint8List.fromList(data)),
      );

      final parameters = await _command(
        transport,
        _requestParameters,
        Uint8List.fromList(const [_requestParameters]),
      );
      if (parameters.length < 6) {
        throw const FormatException('Invalid Zepp OS transfer parameters');
      }
      final deviceChunkLength = parameters[4] | (parameters[5] << 8);
      if (deviceChunkLength <= 0) {
        throw FormatException(
          'Invalid Zepp OS chunk length: $deviceChunkLength',
        );
      }

      final info = Uint8List(14)
        ..[0] = _sendInfo
        ..[1] = package.firmwareType;
      _writeUint32Le(info, 2, package.bytes.length);
      _writeUint32Le(info, 6, package.crc32);
      _writeUint16Le(info, 10, deviceChunkLength);
      info[12] = 0;
      info[13] = 0xff;
      await _command(transport, _sendInfo, info);
      await _command(
        transport,
        _startTransfer,
        Uint8List.fromList(const [_startTransfer, 0x01]),
      );

      var offset = 0;
      // Gadgetbridge uses the negotiated ATT payload (MTU - 3) here.
      final packetLength = (transport.maxWriteLength ?? 20).clamp(20, 512);
      while (offset < package.bytes.length) {
        final chunkEnd = math.min(
          offset + deviceChunkLength,
          package.bytes.length,
        );
        final progressFuture = _next(
          _progress,
          timeout: const Duration(seconds: 60),
        );
        for (
          var packetOffset = offset;
          packetOffset < chunkEnd;
          packetOffset += packetLength
        ) {
          final packetEnd = math.min(packetOffset + packetLength, chunkEnd);
          await transport.sendToCharacteristic(
            Uint8List.sublistView(package.bytes, packetOffset, packetEnd),
            _data,
            // Gadgetbridge preserves the firmware-data characteristic's
            // native write type. Forcing acknowledged writes here makes
            // dual-mode 0x1532 characteristics use ATT write requests,
            // which can stall long transfers until the watch watchdog resets.
            withResponse: false,
          );
        }
        final progress = await progressFuture;
        if (progress.length < 6) {
          throw const FormatException('Invalid Zepp OS transfer progress');
        }
        final nextOffset = ByteData.sublistView(
          progress,
          2,
          6,
        ).getUint32(0, Endian.little);
        if (nextOffset <= offset || nextOffset > package.bytes.length) {
          throw FormatException('Invalid Zepp OS transfer offset: $nextOffset');
        }
        offset = nextOffset;
        onProgress?.call(offset / package.bytes.length);
      }

      await _command(
        transport,
        _completeTransfer,
        Uint8List.fromList(const [_completeTransfer]),
      );
      await _command(
        transport,
        _finalize,
        Uint8List.fromList(const [_finalize]),
        timeout: const Duration(seconds: 45),
      );
      onProgress?.call(1);
    } finally {
      try {
        await bleTransport?.resumeProtocolNotifications();
      } finally {
        bleTransport?.endExclusiveCharacteristicWrites();
        _installing = false;
      }
    }
  }

  Future<Uint8List> _command(
    CharacteristicTransport transport,
    int command,
    Uint8List payload, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = _next(command, timeout: timeout);
    await transport.sendToCharacteristic(payload, _control, withResponse: true);
    final value = await response;
    if (value.length < 3 || value[2] != _success) {
      final status = value.length >= 3 ? value[2] : -1;
      final message = switch ((command, status)) {
        (_startTransfer, 0x47) => 'Not enough free space on the Zepp OS device',
        (_sendInfo, 0x22) => 'Zepp OS device battery is too low',
        _ =>
          'Zepp OS install ${_commandName(command)} '
          '(0x${command.toRadixString(16)}) was rejected by the device: '
          'status 0x${status.toRadixString(16)}',
      };
      throw StateError(message);
    }
    return value;
  }

  Future<Uint8List> _next(int command, {required Duration timeout}) =>
      _notifications.stream
          .firstWhere(
            (value) =>
                value.length >= 2 &&
                value[0] == _response &&
                value[1] == command,
          )
          .timeout(timeout);

  static void _writeUint16Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
  }

  static String _commandName(int command) => switch (command) {
    _requestParameters => 'parameter request',
    _sendInfo => 'package metadata',
    _startTransfer => 'transfer start',
    _completeTransfer => 'transfer completion',
    _finalize => 'package finalization',
    _ => 'command',
  };

  static void _writeUint32Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
    bytes[offset + 2] = (value >> 16) & 0xff;
    bytes[offset + 3] = (value >> 24) & 0xff;
  }

  @override
  void onData(Uint8List data) {}

  @override
  Future<void> dispose() async {
    await _controlSubscription?.cancel();
    await _notifications.close();
  }
}
