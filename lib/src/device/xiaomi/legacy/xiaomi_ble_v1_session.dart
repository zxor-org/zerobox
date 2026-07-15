import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/core/ble_requirement.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';
import 'package:zerobox/src/protocols/xiaomi/crypto/miwear_crypto.dart';

/// Minimal Xiaomi encrypted BLE v1 session used by Xiaomi Smart Band 7 Pro.
///
/// The characteristic framing and authentication flow are ported from
/// Gadgetbridge's XiaomiCharacteristicV1 and XiaomiAuthService. This session
/// intentionally stops after authentication; feature services can be layered
/// on top once the connection is verified against real hardware.
class XiaomiBleV1Session {
  XiaomiBleV1Session(this._connection)
    : _commandRead = _XiaomiBleV1Channel(
        connection: _connection,
        characteristic: commandReadCharacteristic,
      ),
      _commandWrite = _XiaomiBleV1Channel(
        connection: _connection,
        characteristic: commandWriteCharacteristic,
      );

  static const serviceUuid = xiaomiBleServiceUuid;
  static const commandReadCharacteristic = BleRequiredCharacteristic(
    serviceUuid: serviceUuid,
    characteristicUuid: '00000051-0000-1000-8000-00805f9b34fb',
    label: 'Xiaomi BLE v1 command read',
  );
  static const commandWriteCharacteristic = BleRequiredCharacteristic(
    serviceUuid: serviceUuid,
    characteristicUuid: '00000052-0000-1000-8000-00805f9b34fb',
    label: 'Xiaomi BLE v1 command write',
  );
  static const activityCharacteristic = BleRequiredCharacteristic(
    serviceUuid: serviceUuid,
    characteristicUuid: '00000053-0000-1000-8000-00805f9b34fb',
    label: 'Xiaomi BLE v1 activity data',
  );
  static const uploadCharacteristic = BleRequiredCharacteristic(
    serviceUuid: serviceUuid,
    characteristicUuid: '00000055-0000-1000-8000-00805f9b34fb',
    label: 'Xiaomi BLE v1 data upload',
  );

  static const requiredCharacteristics = <BleRequiredCharacteristic>[
    commandReadCharacteristic,
    commandWriteCharacteristic,
  ];

  final BluetoothConnection _connection;
  final _XiaomiBleV1Channel _commandRead;
  final _XiaomiBleV1Channel _commandWrite;
  final _messages = StreamController<Uint8List>.broadcast();
  final _subscriptions = <StreamSubscription<Uint8List>>[];
  static final _log = getLogger('XiaomiBleV1Session');

  Future<void> start() async {
    _log.info('enabling Xiaomi BLE v1 command notifications');
    _commandRead.onPayload = _messages.add;
    _commandWrite.onPayload = _messages.add;
    await _subscribe(commandReadCharacteristic, _commandRead);
    await _subscribe(commandWriteCharacteristic, _commandWrite);
    _log.info('Xiaomi BLE v1 command notifications are active');
  }

  Future<void> authenticate(String authKey) async {
    final normalized = authKey.trim().toLowerCase().replaceFirst('0x', '');
    final secretKey = parseAuthKey(normalized);
    final phoneNonce = generateRandomBytes(16);

    _log.info('starting Xiaomi BLE v1 encrypted authentication');
    final nonceResponseFuture = _nextCommand(26);
    await _commandWrite.send(
      _XiaomiV1AuthCodec.phoneNonceCommand(phoneNonce),
      encrypted: false,
    );
    _log.info('phone nonce sent; waiting for watch nonce');
    final nonceResponse = await nonceResponseFuture;
    _log.info('watch nonce response received');
    final watchNonce = _XiaomiV1AuthCodec.watchNonce(nonceResponse);
    final watchHmac = _XiaomiV1AuthCodec.watchHmac(nonceResponse);
    if (watchNonce.length != 16 || watchHmac.length != 32) {
      throw const FormatException('Invalid Xiaomi BLE v1 nonce response');
    }

    final derived = kdfMiwear(secretKey, phoneNonce, watchNonce);
    final decKey = Uint8List.sublistView(derived, 0, 16);
    final encKey = Uint8List.sublistView(derived, 16, 32);
    final decNonce = Uint8List.sublistView(derived, 32, 36);
    final encNonce = Uint8List.sublistView(derived, 36, 40);
    final expectedWatchHmac = hmacSha256(decKey, [watchNonce, phoneNonce]);
    if (!_constantTimeEquals(watchHmac, expectedWatchHmac)) {
      throw StateError('Xiaomi Smart Band 7 Pro authkey verification failed');
    }
    _log.info('watch HMAC verified');

    final keys = _XiaomiBleV1Keys(
      encryptionKey: Uint8List.fromList(encKey),
      decryptionKey: Uint8List.fromList(decKey),
      encryptionNonce: Uint8List.fromList(encNonce),
      decryptionNonce: Uint8List.fromList(decNonce),
    );
    _commandRead.keys = keys;
    _commandWrite.keys = keys;

    final appHmac = hmacSha256(encKey, [phoneNonce, watchNonce]);
    final deviceInfo = _XiaomiV1AuthCodec.deviceInfo(
      phoneName: 'ZeroBox',
      region: 'CN',
    );
    final encryptedDeviceInfo = aes128CcmEncrypt(
      encKey,
      _nonce(encNonce, 0),
      Uint8List(0),
      deviceInfo,
    );
    final confirmResponseFuture = _nextCommand(27);
    await _commandWrite.send(
      _XiaomiV1AuthCodec.authConfirmCommand(appHmac, encryptedDeviceInfo),
      encrypted: false,
    );
    _log.info('authentication confirmation sent; waiting for watch response');
    await confirmResponseFuture;
    _commandRead.encryptionEnabled = true;
    _commandWrite.encryptionEnabled = true;
    _log.info('Xiaomi BLE v1 authentication succeeded');
  }

  Future<Uint8List> _nextCommand(int subtype) async {
    return _messages.stream
        .firstWhere((bytes) => _XiaomiV1AuthCodec.subtype(bytes) == subtype)
        .timeout(const Duration(seconds: 10));
  }

  Future<void> _subscribe(
    BleRequiredCharacteristic characteristic,
    _XiaomiBleV1Channel channel,
  ) async {
    final controller = StreamController<Uint8List>();
    final subscription = controller.stream.listen(channel.handle);
    _subscriptions.add(subscription);
    await _connection.subscribe(
      characteristic: characteristic,
      onData: controller.add,
    );
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    if (!_messages.isClosed) await _messages.close();
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

class _XiaomiBleV1Keys {
  const _XiaomiBleV1Keys({
    required this.encryptionKey,
    required this.decryptionKey,
    required this.encryptionNonce,
    required this.decryptionNonce,
  });

  final Uint8List encryptionKey;
  final Uint8List decryptionKey;
  final Uint8List encryptionNonce;
  final Uint8List decryptionNonce;
}

class _XiaomiBleV1Channel {
  _XiaomiBleV1Channel({required this.connection, required this.characteristic});

  final BluetoothConnection connection;
  final BleRequiredCharacteristic characteristic;
  void Function(Uint8List payload)? onPayload;
  _XiaomiBleV1Keys? keys;
  bool encryptionEnabled = false;
  int _encryptionIndex = 1;
  int _expectedChunks = 0;
  bool _incomingEncrypted = false;
  final _chunks = <int, Uint8List>{};
  Completer<int>? _ack;

  int get _maxWriteSize => (connection.maxWriteLength ?? 244).clamp(20, 512);

  Future<void> send(Uint8List payload, {required bool encrypted}) async {
    if (_ack != null && !_ack!.isCompleted) {
      throw StateError('Xiaomi BLE v1 channel is already sending');
    }
    var bytes = payload;
    var encryptedIndex = 0;
    if (encrypted) {
      final currentKeys = keys;
      if (currentKeys == null || !encryptionEnabled) {
        throw StateError('Xiaomi BLE v1 encryption is not initialized');
      }
      encryptedIndex = _encryptionIndex++;
      bytes = aes128CcmEncrypt(
        currentKeys.encryptionKey,
        _nonce(currentKeys.encryptionNonce, encryptedIndex),
        Uint8List(0),
        bytes,
      );
    }

    // XiaomiCharacteristicV1 bases chunking on the characteristic being an
    // encrypted channel, not on whether keys are initialized for this packet.
    // The plaintext nonce/auth handshake therefore uses a single command with
    // encryption marker 2. Chunking it is ACKed by the watch but ignored.
    final headerSize = encrypted ? 6 : 4;
    final shouldChunk = bytes.length + headerSize > _maxWriteSize;
    if (shouldChunk) {
      if (encrypted) {
        final indexed = BytesBuilder()
          ..addByte(encryptedIndex & 0xff)
          ..addByte((encryptedIndex >> 8) & 0xff)
          ..add(bytes);
        bytes = indexed.toBytes();
      }
      final payloadSize = _maxWriteSize - 2;
      final count = (bytes.length / payloadSize).ceil();
      _ack = Completer<int>();
      await _write(
        Uint8List.fromList([
          0,
          0,
          0,
          encrypted ? 1 : 0,
          count & 0xff,
          (count >> 8) & 0xff,
        ]),
      );
      final startAck = await _takeAck();
      if (startAck != 1) throw StateError('BLE v1 chunk start rejected');
      _ack = Completer<int>();
      for (var index = 0; index < count; index++) {
        final start = index * payloadSize;
        final end = (start + payloadSize).clamp(0, bytes.length);
        final chunk = BytesBuilder()
          ..addByte((index + 1) & 0xff)
          ..addByte(((index + 1) >> 8) & 0xff)
          ..add(bytes.sublist(start, end));
        await _write(chunk.toBytes());
      }
      final endAck = await _takeAck();
      if (endAck != 0) throw StateError('BLE v1 chunk transfer rejected');
      return;
    }

    _ack = Completer<int>();
    final packet = BytesBuilder()..add([0, 0, 2, encrypted ? 1 : 2]);
    if (encrypted) {
      packet
        ..addByte(encryptedIndex & 0xff)
        ..addByte((encryptedIndex >> 8) & 0xff);
    }
    packet.add(bytes);
    await _write(packet.toBytes());
    final result = await _takeAck();
    if (result != 0) throw StateError('BLE v1 command rejected: $result');
  }

  Future<int> _takeAck() async {
    final completer = _ack!;
    final result = await completer.future.timeout(const Duration(seconds: 5));
    if (identical(_ack, completer)) _ack = null;
    return result;
  }

  Future<void> handle(Uint8List value) async {
    if (value.length < 2) return;
    final chunk = value[0] | (value[1] << 8);
    if (chunk != 0) {
      if (_expectedChunks == 0 || chunk > _expectedChunks) return;
      _chunks[chunk] = Uint8List.sublistView(value, 2);
      if (_chunks.length == _expectedChunks) {
        final payload = BytesBuilder();
        for (var index = 1; index <= _expectedChunks; index++) {
          final part = _chunks[index];
          if (part == null) return;
          payload.add(part);
        }
        _chunks.clear();
        _expectedChunks = 0;
        await _write(Uint8List.fromList(const [0, 0, 1, 0]));
        _emitPayload(payload.toBytes(), encrypted: _incomingEncrypted);
      }
      return;
    }
    if (value.length < 4) return;
    final type = value[2];
    if (type == 0) {
      if (value.length < 6) return;
      _incomingEncrypted = value[3] == 1;
      _expectedChunks = value[4] | (value[5] << 8);
      _chunks.clear();
      await _write(Uint8List.fromList(const [0, 0, 1, 1]));
      return;
    }
    if (type == 1) {
      final subtype = value[3];
      final completer = _ack;
      if (completer != null && !completer.isCompleted) {
        completer.complete(subtype);
      }
      return;
    }
    if (type == 2) {
      await _write(Uint8List.fromList(const [0, 0, 3, 0]));
      final encrypted = value[3] == 1;
      // Incoming single commands do not carry the outbound nonce index.
      const offset = 4;
      if (value.length < offset) return;
      _emitPayload(Uint8List.sublistView(value, offset), encrypted: encrypted);
      return;
    }
    if (type == 3) {
      final completer = _ack;
      if (completer != null && !completer.isCompleted) {
        completer.complete(value[3]);
      }
    }
  }

  void _emitPayload(Uint8List payload, {required bool encrypted}) {
    var decoded = payload;
    if (encrypted) {
      final currentKeys = keys;
      if (currentKeys == null) {
        throw StateError('Encrypted BLE v1 payload before auth');
      }
      decoded = aes128CcmDecrypt(
        currentKeys.decryptionKey,
        _nonce(currentKeys.decryptionNonce, 0),
        Uint8List(0),
        payload,
      );
    }
    onPayload?.call(decoded);
  }

  Future<void> _write(Uint8List bytes) => connection.send(
    bytes,
    characteristic: characteristic,
    withResponse: false,
  );
}

Uint8List _nonce(Uint8List prefix, int counter) {
  final nonce = Uint8List(12)..setRange(0, 4, prefix);
  nonce[8] = counter & 0xff;
  nonce[9] = (counter >> 8) & 0xff;
  nonce[10] = (counter >> 16) & 0xff;
  nonce[11] = (counter >> 24) & 0xff;
  return nonce;
}

class _XiaomiV1AuthCodec {
  static Uint8List phoneNonceCommand(Uint8List nonce) {
    final phoneNonce = _message({_field(1, 2): nonce});
    final auth = _message({_field(30, 2): phoneNonce});
    return _command(1, 26, auth);
  }

  static Uint8List authConfirmCommand(
    Uint8List appHmac,
    Uint8List encryptedDeviceInfo,
  ) {
    final step3 = _message({
      _field(1, 2): appHmac,
      _field(2, 2): encryptedDeviceInfo,
    });
    final auth = _message({_field(32, 2): step3});
    return _command(1, 27, auth);
  }

  static Uint8List deviceInfo({
    required String phoneName,
    required String region,
  }) {
    final out = BytesBuilder();
    _writeVarintField(out, 1, 0);
    _writeFixed32Field(out, 2, 0x42000000); // float 32.0
    _writeBytesField(out, 3, Uint8List.fromList(utf8.encode(phoneName)));
    _writeVarintField(out, 4, 224);
    _writeBytesField(out, 5, Uint8List.fromList(utf8.encode(region)));
    return out.toBytes();
  }

  static int subtype(Uint8List command) => (_parse(command)[2] as int?) ?? -1;

  static Uint8List watchNonce(Uint8List command) {
    final auth = _parse(command)[3] as Uint8List? ?? Uint8List(0);
    final watch = _parse(auth)[31] as Uint8List? ?? Uint8List(0);
    return _parse(watch)[1] as Uint8List? ?? Uint8List(0);
  }

  static Uint8List watchHmac(Uint8List command) {
    final auth = _parse(command)[3] as Uint8List? ?? Uint8List(0);
    final watch = _parse(auth)[31] as Uint8List? ?? Uint8List(0);
    return _parse(watch)[2] as Uint8List? ?? Uint8List(0);
  }

  static Uint8List _command(int type, int subtype, Uint8List auth) {
    final out = BytesBuilder();
    _writeVarintField(out, 1, type);
    _writeVarintField(out, 2, subtype);
    _writeBytesField(out, 3, auth);
    return out.toBytes();
  }

  static int _field(int number, int wireType) => (number << 3) | wireType;

  static Uint8List _message(Map<int, Uint8List> fields) {
    final out = BytesBuilder();
    for (final entry in fields.entries) {
      _writeVarint(out, entry.key);
      _writeVarint(out, entry.value.length);
      out.add(entry.value);
    }
    return out.toBytes();
  }

  static Map<int, Object> _parse(Uint8List bytes) {
    final fields = <int, Object>{};
    var offset = 0;
    while (offset < bytes.length) {
      final key = _readVarint(bytes, offset);
      offset = key.$2;
      final number = key.$1 >> 3;
      final wire = key.$1 & 7;
      if (wire == 0) {
        final value = _readVarint(bytes, offset);
        offset = value.$2;
        fields[number] = value.$1;
      } else if (wire == 2) {
        final length = _readVarint(bytes, offset);
        offset = length.$2;
        final end = offset + length.$1;
        if (end > bytes.length) {
          throw const FormatException('Truncated protobuf');
        }
        fields[number] = Uint8List.sublistView(bytes, offset, end);
        offset = end;
      } else if (wire == 5) {
        offset += 4;
      } else {
        throw FormatException('Unsupported protobuf wire type $wire');
      }
    }
    return fields;
  }

  static (int, int) _readVarint(Uint8List bytes, int offset) {
    var value = 0;
    var shift = 0;
    while (offset < bytes.length && shift < 35) {
      final byte = bytes[offset++];
      value |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return (value, offset);
      shift += 7;
    }
    throw const FormatException('Invalid protobuf varint');
  }

  static void _writeVarintField(BytesBuilder out, int number, int value) {
    _writeVarint(out, _field(number, 0));
    _writeVarint(out, value);
  }

  static void _writeFixed32Field(BytesBuilder out, int number, int value) {
    _writeVarint(out, _field(number, 5));
    out.add([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  static void _writeBytesField(BytesBuilder out, int number, Uint8List value) {
    _writeVarint(out, _field(number, 2));
    _writeVarint(out, value.length);
    out.add(value);
  }

  static void _writeVarint(BytesBuilder out, int value) {
    var remaining = value;
    while (remaining >= 0x80) {
      out.addByte((remaining & 0x7f) | 0x80);
      remaining >>= 7;
    }
    out.addByte(remaining);
  }
}
