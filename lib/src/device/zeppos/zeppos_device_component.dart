import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/core/ble_requirement.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/crypto/zeppos_auth_crypto.dart';

class ZeppOsPayload {
  const ZeppOsPayload({required this.endpoint, required this.payload});

  final int endpoint;
  final Uint8List payload;
}

class ZeppOsDeviceComponent {
  ZeppOsDeviceComponent({required this.transport})
    : _log = getLogger('ZeppOsDeviceComponent');

  static const endpointAuthentication = 0x0082;

  static const _chunkPacket = 0x03;
  static const _chunkAck = 0x04;
  static const _flagFirst = 0x01;
  static const _flagLast = 0x02;
  static const _flagNeedsAck = 0x04;
  static const _flagEncrypted = 0x08;
  static const _maxInboundPayloadLength = 1024 * 1024;
  static const _zeppServiceUuid = '00001530-0000-3512-2118-0009af100700';
  static const _zeppReadCharUuid = '00000017-0000-3512-2118-0009af100700';

  final Transport transport;
  final Logger _log;

  ZeppOsAuthKeys? authKeys;
  void Function(ZeppOsPayload payload)? onPayload;
  void Function(Object error, StackTrace stackTrace)? onTransportFailure;

  int _writeHandle = 0;
  int? _encryptedSequenceNumber;
  int? _currentHandle;
  int? _currentEndpoint;
  int? _currentLength;
  int _expectedCount = 0;
  BytesBuilder? _reassembly;

  Future<void> sendToEndpoint(
    int endpoint,
    Uint8List payload, {
    bool encrypted = false,
    int? maxWriteLength,
  }) async {
    _writeHandle = (_writeHandle + 1) & 0xff;
    final handle = _writeHandle;
    final wirePayload = encrypted ? _encryptPayload(payload, handle) : payload;
    var offset = 0;
    var count = 0;
    while (offset < wirePayload.length ||
        (wirePayload.isEmpty && count == 0)) {
      final first = count == 0;
      final maxPayload = _maxChunkPayload(
        first: first,
        maxWriteLength: maxWriteLength,
      );
      final remaining = wirePayload.length - offset;
      final take = wirePayload.isEmpty
          ? 0
          : (remaining < maxPayload ? remaining : maxPayload);
      final last = offset + take >= wirePayload.length;
      final headerSize = first ? 11 : 5;
      final chunk = Uint8List(headerSize + take);
      var flags = 0;
      if (first) flags |= _flagFirst;
      if (last) flags |= _flagLast | _flagNeedsAck;
      if (encrypted) flags |= _flagEncrypted;
      chunk[0] = _chunkPacket;
      chunk[1] = flags;
      chunk[2] = 0x00;
      chunk[3] = handle;
      chunk[4] = count;
      var cursor = 5;
      if (first) {
        _writeUint32Le(chunk, cursor, payload.length);
        cursor += 4;
        _writeUint16Le(chunk, cursor, endpoint);
        cursor += 2;
      }
      if (take > 0) {
        chunk.setRange(cursor, cursor + take, wirePayload, offset);
      }
      await _safeSend(chunk);
      offset += take;
      count += 1;
      if (wirePayload.isEmpty) break;
    }
  }

  void handleIncoming(Uint8List data) {
    if (data.isEmpty || data[0] != _chunkPacket) {
      _log.warning('Ignoring non-chunked ZeppOS payload');
      return;
    }
    if (data.length < 5) {
      throw StateError('ZeppOS chunk is too short: ${data.length}');
    }
    var cursor = 1;
    final flags = data[cursor++];
    final encrypted = flags & _flagEncrypted != 0;
    final first = flags & _flagFirst != 0;
    final last = flags & _flagLast != 0;
    final needsAck = flags & _flagNeedsAck != 0;
    cursor += 1; // extended header byte
    final handle = data[cursor++];
    final count = data[cursor++];

    if (!first && _currentHandle == null) {
      throw StateError('ZeppOS continuation chunk arrived before first chunk');
    }
    if (_currentHandle != null && _currentHandle != handle) {
      _resetReassembly();
      throw StateError('Unexpected ZeppOS chunk handle $handle');
    }
    if (count != (first ? 0 : _expectedCount)) {
      _resetReassembly();
      throw StateError(
        'Unexpected ZeppOS chunk count $count, expected '
        '${first ? 0 : _expectedCount}',
      );
    }
    if (first) {
      if (data.length < cursor + 6) {
        throw StateError('ZeppOS first chunk is too short: ${data.length}');
      }
      final announcedLength = _readUint32Le(data, cursor);
      if (announcedLength < 0 ||
          announcedLength > _maxInboundPayloadLength) {
        throw StateError(
          'Invalid ZeppOS payload length $announcedLength',
        );
      }
      _currentLength = announcedLength;
      cursor += 4;
      _currentEndpoint = _readUint16Le(data, cursor);
      cursor += 2;
      _currentHandle = handle;
      _expectedCount = 0;
      _reassembly = BytesBuilder(copy: false);
    }

    _reassembly?.add(Uint8List.sublistView(data, cursor));
    _expectedCount = (count + 1) & 0xff;
    if (needsAck) {
      unawaited(
        _sendAck(handle: handle, count: count).catchError(
          (Object error, StackTrace stackTrace) {
            _log.warning('Failed to send ZeppOS ACK', error, stackTrace);
          },
        ),
      );
    }
    if (!last) return;

    var bytes = _reassembly?.takeBytes() ?? Uint8List(0);
    final length = _currentLength ?? bytes.length;
    final endpoint = _currentEndpoint;
    _resetReassembly();
    if (endpoint == null) return;
    if (encrypted) {
      bytes = _decryptPayload(bytes, handle, length);
    }
    if (bytes.length < length) {
      throw StateError(
        'Truncated ZeppOS payload: expected $length, got ${bytes.length}',
      );
    }
    final actualLength = length;
    onPayload?.call(
      ZeppOsPayload(
        endpoint: endpoint,
        payload: Uint8List.sublistView(bytes, 0, actualLength),
      ),
    );
  }

  Future<void> _sendAck({required int handle, required int count}) {
    final ack = Uint8List.fromList([_chunkAck, 0x00, handle, 0x01, count]);
    final characteristicTransport = transport is CharacteristicTransport
        ? transport as CharacteristicTransport
        : null;
    if (characteristicTransport == null) {
      return _safeSend(ack);
    }
    return _safeSendToCharacteristic(
      ack,
      const BleRequiredCharacteristic(
        serviceUuid: _zeppServiceUuid,
        characteristicUuid: _zeppReadCharUuid,
        label: 'zeppos chunked 2021 read ack',
      ),
      characteristicTransport,
    );
  }

  Future<void> _safeSend(Uint8List data) async {
    try {
      await transport.send(data);
    } catch (e, st) {
      onTransportFailure?.call(e, st);
      rethrow;
    }
  }

  Future<void> _safeSendToCharacteristic(
    Uint8List data,
    BleRequiredCharacteristic characteristic,
    CharacteristicTransport characteristicTransport,
  ) async {
    try {
      await characteristicTransport.sendToCharacteristic(data, characteristic);
    } catch (e, st) {
      onTransportFailure?.call(e, st);
      rethrow;
    }
  }

  int _maxChunkPayload({required bool first, int? maxWriteLength}) {
    final packetLength = (maxWriteLength ?? 20).clamp(20, 512).toInt();
    return packetLength - (first ? 11 : 5);
  }

  Uint8List _encryptPayload(Uint8List payload, int handle) {
    final keys = authKeys;
    if (keys == null) {
      throw StateError('Cannot encrypt ZeppOS payload before authentication');
    }
    final sequence = _encryptedSequenceNumber ?? keys.encryptedSequenceNumber;
    _encryptedSequenceNumber = (sequence + 1) & 0xffffffff;
    final clearLength = payload.length + 8;
    final paddedLength = ((clearLength + 15) ~/ 16) * 16;
    final clear = Uint8List(paddedLength);
    clear.setRange(0, payload.length, payload);
    _writeUint32Le(clear, payload.length, sequence);
    _writeUint32Le(clear, payload.length + 4, _crc32(clear, payload.length + 4));
    return zeppOsAesEcbEncrypt(_messageKey(keys.sessionKey, handle), clear);
  }

  Uint8List _decryptPayload(Uint8List payload, int handle, int clearLength) {
    final keys = authKeys;
    if (keys == null) {
      throw StateError('Encrypted ZeppOS payload received before authentication');
    }
    if (payload.length % 16 != 0) {
      throw StateError('Encrypted ZeppOS payload is not block aligned');
    }
    final clear = zeppOsAesEcbDecrypt(
      _messageKey(keys.sessionKey, handle),
      payload,
    );
    if (clearLength > clear.length) {
      throw StateError('Encrypted ZeppOS payload is truncated');
    }
    return Uint8List.sublistView(clear, 0, clearLength);
  }

  Uint8List _messageKey(Uint8List sessionKey, int handle) =>
      Uint8List.fromList(sessionKey.map((byte) => byte ^ handle).toList());

  int _crc32(Uint8List data, int length) {
    var crc = 0xffffffff;
    for (var i = 0; i < length; i += 1) {
      crc ^= data[i];
      for (var bit = 0; bit < 8; bit += 1) {
        crc = (crc & 1) != 0
            ? (crc >> 1) ^ 0xedb88320
            : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  void _resetReassembly() {
    _currentHandle = null;
    _currentEndpoint = null;
    _currentLength = null;
    _expectedCount = 0;
    _reassembly = null;
  }

  void _writeUint16Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
  }

  void _writeUint32Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
    bytes[offset + 2] = (value >> 16) & 0xff;
    bytes[offset + 3] = (value >> 24) & 0xff;
  }

  int _readUint16Le(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  int _readUint32Le(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
