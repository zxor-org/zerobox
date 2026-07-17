import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:zerobox/src/device/core/ble_requirement.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsScreenshotSystem extends System {
  static const appsEndpoint = 0x00a0;
  static const fileTransferEndpoint = 0x000d;
  static const _maxScreenshotBytes = 8 * 1024 * 1024;
  static const _firmwareService = '00001530-0000-3512-2118-0009af100700';
  static const _v3Receive = BleRequiredCharacteristic(
    serviceUuid: _firmwareService,
    characteristicUuid: '00000024-0000-3512-2118-0009af100700',
    label: 'Zepp OS file transfer v3 receive',
  );
  static const _v3Send = BleRequiredCharacteristic(
    serviceUuid: _firmwareService,
    characteristicUuid: '00000023-0000-3512-2118-0009af100700',
    label: 'Zepp OS file transfer v3 send',
  );

  int? _fileTransferVersion;
  bool _appsEncrypted = false;
  bool _fileTransferEncrypted = false;
  Completer<int>? _capabilities;
  Completer<int>? _screenshotAck;
  Completer<void>? _fileRequest;
  Completer<Uint8List>? _pendingScreenshot;
  bool _requestRunning = false;
  _Download? _download;
  StreamSubscription<Uint8List>? _v3Subscription;
  StreamSubscription<Uint8List>? _v3SendSubscription;
  final _v3Packet = BytesBuilder(copy: false);
  int _v3ChunkSize = -1;
  bool _v3LastChunk = false;

  ZeppOsDeviceComponent get _component =>
      entity.getRequired<ZeppOsDeviceComponent>();

  int? get _maxWriteLength {
    final transport = entity.transport;
    return transport is CharacteristicTransport
        ? transport.maxWriteLength
        : null;
  }

  Future<Uint8List> requestScreenshot() async {
    if (_requestRunning) {
      throw StateError('A screenshot request is already running');
    }
    _requestRunning = true;
    try {
      final servicesSystem = entity.system<ZeppOsServicesSystem>();
      if (servicesSystem == null) {
        throw StateError('Zepp OS services system is unavailable');
      }
      final services = await servicesSystem.fetchSupportedServices();
      if (!services.containsKey(appsEndpoint) ||
          !services.containsKey(fileTransferEndpoint)) {
        throw UnsupportedError(
          'The connected Zepp OS device does not advertise the screenshot '
          'and file-transfer services',
        );
      }
      _appsEncrypted = services[appsEndpoint] ?? false;
      _fileTransferEncrypted = services[fileTransferEndpoint] ?? false;
      final version = await _ensureCapabilities();
      if (version > 3) {
        throw UnsupportedError(
          'Zepp OS file transfer v$version screenshots are not supported yet',
        );
      }
      final completer = Completer<Uint8List>();
      final ack = Completer<int>();
      final fileRequest = Completer<void>();
      _pendingScreenshot = completer;
      _screenshotAck = ack;
      _fileRequest = fileRequest;
      final request = Uint8List(20)
        ..[0] = 0x03
        ..[1] = 0x01
        ..[2] = 0x01;
      try {
        await _component.sendToEndpoint(
          appsEndpoint,
          request,
          encrypted: _appsEncrypted,
          maxWriteLength: _maxWriteLength,
        );
        final status =
            await Future.any<int>([
              ack.future,
              fileRequest.future.then((_) => 0),
            ]).timeout(
              const Duration(seconds: 6),
              onTimeout: () => throw TimeoutException(
                'The watch neither acknowledged the screenshot command nor '
                'started a file transfer',
                const Duration(seconds: 6),
              ),
            );
        if (status != 0) {
          throw StateError(
            'The watch rejected the screenshot command with status $status',
          );
        }
        return await completer.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
            _download == null
                ? 'The watch accepted no screenshot file transfer request'
                : 'The watch stopped sending screenshot data '
                      '(${_download!.progress}/${_download!.length} bytes)',
            const Duration(seconds: 20),
          ),
        );
      } finally {
        if (identical(_pendingScreenshot, completer)) _pendingScreenshot = null;
        if (identical(_screenshotAck, ack)) _screenshotAck = null;
        if (identical(_fileRequest, fileRequest)) _fileRequest = null;
        _download = null;
        _resetV3Chunk();
      }
    } finally {
      _requestRunning = false;
    }
  }

  Future<int> _ensureCapabilities() async {
    final current = _fileTransferVersion;
    if (current != null) return current;
    final pending = _capabilities;
    if (pending != null) return pending.future;
    final completer = Completer<int>();
    _capabilities = completer;
    try {
      await _component.sendToEndpoint(
        fileTransferEndpoint,
        Uint8List.fromList(const [0x01]),
        encrypted: _fileTransferEncrypted,
        maxWriteLength: _maxWriteLength,
      );
      return await completer.future.timeout(const Duration(seconds: 5));
    } finally {
      if (identical(_capabilities, completer)) _capabilities = null;
    }
  }

  void handlePayload(int endpoint, Uint8List payload) {
    if (payload.isEmpty) return;
    if (endpoint == appsEndpoint) {
      if (payload.length > 16 &&
          payload[0] == 0x03 &&
          payload[1] == 0x00 &&
          payload[2] == 0x01) {
        final ack = _screenshotAck;
        if (ack != null && !ack.isCompleted) ack.complete(payload[16]);
      }
      return;
    }
    if (endpoint != fileTransferEndpoint) return;
    switch (payload[0]) {
      case 0x02:
        if (payload.length < 4) return;
        _fileTransferVersion = payload[1];
        if (payload[1] == 3) {
          unawaited(_prepareV3(payload[1]));
        } else {
          _completeCapabilities(payload[1]);
        }
        return;
      case 0x03:
        _beginDownload(payload);
        return;
      case 0x10:
        _receiveV2Data(payload);
        return;
    }
  }

  void _beginDownload(Uint8List payload) {
    var offset = 2;
    String readString() {
      final start = offset;
      while (offset < payload.length && payload[offset] != 0) {
        offset++;
      }
      if (offset >= payload.length) {
        throw const FormatException('Bad file name');
      }
      final value = String.fromCharCodes(payload.sublist(start, offset));
      offset++;
      return value;
    }

    try {
      final session = payload[1];
      final url = readString();
      final filename = readString();
      if (offset + 8 > payload.length) {
        throw const FormatException('Bad file size');
      }
      final view = ByteData.sublistView(payload);
      final length = view.getUint32(offset, Endian.little);
      final crc = view.getUint32(offset + 4, Endian.little);
      offset += 8;
      final compressed = offset < payload.length && payload[offset] == 1;
      if (offset < payload.length && payload[offset] > 1) {
        throw FormatException(
          'Invalid screenshot compression flag: ${payload[offset]}',
        );
      }
      if (length <= 0 || length > _maxScreenshotBytes) {
        throw FormatException('Invalid screenshot size: $length');
      }
      if (!filename.startsWith('screenshot-')) {
        throw FormatException('Unexpected file: $filename');
      }
      _download = _Download(
        session,
        url,
        filename,
        length,
        crc,
        compressed: compressed,
      );
      final fileRequest = _fileRequest;
      if (fileRequest != null && !fileRequest.isCompleted) {
        fileRequest.complete();
      }
      final response = _fileTransferVersion == 3
          ? Uint8List.fromList([0x04, session, 0, 0, 0, 0, 0, 1])
          : Uint8List.fromList([0x04, session, 0, 0, 0, 0, 0]);
      _sendFileReply(response);
    } catch (error, stackTrace) {
      final fileRequest = _fileRequest;
      if (fileRequest != null && !fileRequest.isCompleted) {
        fileRequest.completeError(error, stackTrace);
      } else {
        final pending = _pendingScreenshot;
        if (pending != null && !pending.isCompleted) {
          pending.completeError(error, stackTrace);
        }
      }
    }
  }

  Future<void> _prepareV3(int version) async {
    try {
      final transport = entity.transport;
      if (transport is! CharacteristicTransport) {
        throw UnsupportedError('File transfer v3 requires BLE');
      }
      // Zepp OS v3 only starts the transfer after both CCCDs are enabled.
      // Keep Gadgetbridge's order: send/ack first, receive/data second.
      _v3SendSubscription ??= await transport.subscribeToCharacteristic(
        _v3Send,
        (_) {},
      );
      _v3Subscription ??= await transport.subscribeToCharacteristic(
        _v3Receive,
        _receiveV3Data,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _completeCapabilities(version);
    } catch (error, stackTrace) {
      final pending = _capabilities;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(error, stackTrace);
      }
    }
  }

  void _completeCapabilities(int version) {
    final pending = _capabilities;
    if (pending != null && !pending.isCompleted) pending.complete(version);
  }

  void _receiveV3Data(Uint8List payload) {
    final download = _download;
    if (download == null || payload.isEmpty) return;
    if (_v3ChunkSize < 0) {
      if (payload.length < 5 || payload[0] != 0x12) return;
      final flags = payload[1];
      final index = payload[2];
      if (index != (download.index & 0xff)) return;
      _v3LastChunk = (flags & 2) != 0;
      _v3ChunkSize = ByteData.sublistView(payload).getUint16(3, Endian.little);
      _v3Packet.clear();
      if (payload.length > 5) _v3Packet.add(Uint8List.sublistView(payload, 5));
    } else {
      _v3Packet.add(payload);
    }
    if (_v3Packet.length < _v3ChunkSize) return;
    final chunk = _v3Packet.takeBytes();
    if (download.progress + _v3ChunkSize > download.bytes.length) {
      _pendingScreenshot?.completeError(
        const FormatException('Screenshot v3 data exceeds declared size'),
      );
      _resetV3Chunk();
      return;
    }
    download.bytes.setRange(
      download.progress,
      download.progress + _v3ChunkSize,
      chunk,
    );
    final completedIndex = download.index;
    download.progress += _v3ChunkSize;
    download.index++;
    final last = _v3LastChunk;
    _resetV3Chunk();
    _sendV3Ack(completedIndex);
    if (last) _finishDownload(download, 'v3');
  }

  void _resetV3Chunk() {
    _v3Packet.clear();
    _v3ChunkSize = -1;
    _v3LastChunk = false;
  }

  void _sendV3Ack(int index) {
    final transport = entity.transport;
    if (transport is! CharacteristicTransport) return;
    unawaited(
      transport.sendToCharacteristic(
        Uint8List.fromList([0x13, 0, index & 0xff, 1, 0, 0, 0]),
        _v3Receive,
      ),
    );
  }

  void _receiveV2Data(Uint8List payload) {
    final download = _download;
    if (download == null || payload.length < 6) return;
    final flags = payload[1];
    final session = payload[2];
    final index = payload[3];
    var offset = 4;
    if ((flags & 1) != 0) offset += 4;
    if (session != download.session || index != (download.index & 0xff)) return;
    if (offset + 2 > payload.length) return;
    final size = ByteData.sublistView(payload).getUint16(offset, Endian.little);
    offset += 2;
    if (offset + size > payload.length ||
        download.progress + size > download.bytes.length) {
      return;
    }
    download.bytes.setRange(
      download.progress,
      download.progress + size,
      payload,
      offset,
    );
    download.progress += size;
    download.index++;
    _sendFileReply(Uint8List.fromList([0x11, session, 0]));
    if ((flags & 2) != 0) _finishDownload(download, 'v2');
  }

  void _finishDownload(_Download download, String protocol) {
    try {
      final Uint8List screenshot;
      if (download.compressed) {
        screenshot = Uint8List.fromList(
          ZLibDecoder().convert(
            Uint8List.sublistView(download.bytes, 0, download.progress),
          ),
        );
      } else {
        if (download.progress != download.length) {
          throw FormatException(
            'Screenshot $protocol length mismatch: '
            '${download.progress}/${download.length}',
          );
        }
        screenshot = download.bytes;
      }
      if (screenshot.length != download.length ||
          _crc32(screenshot) != download.crc32) {
        throw FormatException('Screenshot $protocol checksum mismatch');
      }
      final pending = _pendingScreenshot;
      if (pending != null && !pending.isCompleted) pending.complete(screenshot);
    } catch (error, stackTrace) {
      final pending = _pendingScreenshot;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(error, stackTrace);
      }
    }
  }

  void _sendFileReply(Uint8List payload) {
    unawaited(
      _component.sendToEndpoint(
        fileTransferEndpoint,
        payload,
        encrypted: _fileTransferEncrypted,
        maxWriteLength: _maxWriteLength,
      ),
    );
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  @override
  void onData(Uint8List data) {
    // ZeppOsDeviceComponent decodes and routes endpoint payloads through
    // handlePayload; parsing the raw transport stream here would duplicate it.
  }

  @override
  Future<void> dispose() async {
    await _v3Subscription?.cancel();
    _v3Subscription = null;
    await _v3SendSubscription?.cancel();
    _v3SendSubscription = null;
  }
}

class _Download {
  _Download(
    this.session,
    this.url,
    this.filename,
    this.length,
    this.crc32, {
    required this.compressed,
  }) : bytes = Uint8List(length);
  final int session;
  final String url;
  final String filename;
  final int length;
  final int crc32;
  final bool compressed;
  final Uint8List bytes;
  int index = 0;
  int progress = 0;
}
