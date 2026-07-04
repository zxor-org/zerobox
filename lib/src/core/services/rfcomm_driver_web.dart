import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/rfcomm_driver.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';

@JS('navigator.serial')
external _Serial? get _navigatorSerial;

extension type _Serial._(JSObject _) implements JSObject {
  external JSPromise<SerialPort> requestPort();
}

extension type SerialPort._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(SerialOptions options);
  external WebSerialReadableStream? get readable;
  external WebSerialWritableStream? get writable;
  external SerialPortInfo getInfo();
  external JSPromise<JSAny?> close();
}

extension type SerialPortInfo._(JSObject _) implements JSObject {
  external JSString? get serialNumber;
  external JSNumber? get usbVendorId;
  external JSNumber? get usbProductId;
}

extension type SerialOptions._(JSObject _) implements JSObject {
  external factory SerialOptions({int baudRate});
}

extension type WebSerialReadableStream._(JSObject _) implements JSObject {
  external ReadableStreamDefaultReader getReader();
}

extension type ReadableStreamDefaultReader._(JSObject _) implements JSObject {
  external JSPromise<ReadableStreamReadResult> read();
  external JSPromise<JSAny?> cancel([JSAny? reason]);
  external JSPromise<JSAny?> releaseLock();
}

extension type ReadableStreamReadResult._(JSObject _) implements JSObject {
  external JSBoolean get done;
  external JSUint8Array? get value;
}

extension type WebSerialWritableStream._(JSObject _) implements JSObject {
  external WritableStreamDefaultWriter getWriter();
}

extension type WritableStreamDefaultWriter._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSAny? chunk);
  external JSPromise<JSAny?> close();
}

class WebSerialRfcommConnection implements RfcommConnection {
  WebSerialRfcommConnection({
    required this.deviceId,
    required this.deviceName,
    required this._port,
  });

  @override
  final String deviceId;

  @override
  final String deviceName;

  final SerialPort _port;
  final _incomingController = StreamController<Uint8List>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _log = getLogger('WebSerialRfcommConnection');

  ReadableStreamDefaultReader? _reader;
  WritableStreamDefaultWriter? _writer;
  bool _disposed = false;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  @override
  Future<void> start() async {
    _connectionController.add(true);

    final readable = _port.readable;
    if (readable == null) {
      throw StateError('Serial port readable stream is null');
    }
    _reader = readable.getReader();

    final writable = _port.writable;
    if (writable == null) {
      throw StateError('Serial port writable stream is null');
    }
    _writer = writable.getWriter();

    _readLoop();
  }

  void _readLoop() {
    final reader = _reader;
    if (reader == null) return;

    Future<void> loop() async {
      try {
        while (!_disposed) {
          final result = await reader.read().toDart;
          if (_disposed) break;

          final done = result.done.toDart;
          if (done) {
            _log.info('[$deviceId] serial read done');
            _onDisconnected();
            break;
          }

          final value = result.value;
          if (value != null) {
            final data = value.toDart;
            _incomingController.add(data);
          }
        }
      } catch (e, st) {
        _log.warning('[$deviceId] serial read error', e, st);
        _onDisconnected();
      } finally {
        try {
          await reader.releaseLock().toDart;
        } catch (e) {
          _log.fine('[$deviceId] releaseLock in read loop: $e');
        }
      }
    }

    unawaited(loop());
  }

  void _onDisconnected() {
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  @override
  Future<void> send(Uint8List data) async {
    final writer = _writer;
    if (writer == null) {
      throw StateError('Serial port writer not ready');
    }
    final chunk = data.toJS;
    await writer.write(chunk).toDart;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _log.info('[$deviceId] disposing web serial connection');

    final reader = _reader;
    _reader = null;
    final writer = _writer;
    _writer = null;

    try {
      await reader?.cancel().toDart;
    } catch (e) {
      _log.fine('[$deviceId] reader cancel: $e');
    }

    try {
      await writer?.close().toDart;
    } catch (e) {
      _log.warning('[$deviceId] writer close error', e);
    }

    try {
      await _port.close().toDart;
    } catch (e) {
      _log.warning('[$deviceId] port close error', e);
    }

    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
  }
}

class WebSerialRfcommDriver implements RfcommDriver {
  WebSerialRfcommDriver() : _log = getLogger('WebSerialRfcommDriver');

  final Logger _log;
  final _scanController = StreamController<BluetoothEndpoint>.broadcast();
  WebSerialRfcommConnection? _currentConnection;

  @override
  Stream<BluetoothEndpoint> get scanStream => _scanController.stream;

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {}

  @override
  Future<List<BluetoothEndpoint>> stopScan() async => const [];

  @override
  Future<RfcommConnection> connect(
    String deviceId,
    String deviceName, {
    String? serviceUuid,
    List<int> fallbackChannels = const [5, 1],
  }) async {
    if (serviceUuid != null || fallbackChannels.isNotEmpty) {
      _log.fine(
        'web serial ignores classic bluetooth options '
        'serviceUuid=$serviceUuid fallbackChannels=$fallbackChannels',
      );
    }
    _log.info('requesting web serial port');

    final serial = _navigatorSerial;
    if (serial == null) {
      throw UnsupportedError(
        'Web Serial API is not available in this browser. '
        'Use a Chromium-based browser with web serial enabled.',
      );
    }

    final port = await serial.requestPort().toDart;

    final info = port.getInfo();
    final serialNumber = info.serialNumber?.toDart;
    final vendorId = info.usbVendorId?.toDartInt;
    final productId = info.usbProductId?.toDartInt;

    final finalDeviceId = serialNumber != null
        ? 'serial:$serialNumber'
        : (vendorId != null && productId != null)
        ? 'usb:${vendorId.toRadixString(16).padLeft(4, '0')}:${productId.toRadixString(16).padLeft(4, '0')}'
        : deviceId;

    final finalDeviceName =
        serialNumber ??
        ((vendorId != null && productId != null)
            ? 'Web Serial ${vendorId.toRadixString(16).padLeft(4, '0')}:${productId.toRadixString(16).padLeft(4, '0')}'
            : 'Web Serial');

    _log.info('opening web serial port $finalDeviceId');
    await port.open(SerialOptions(baudRate: 115200)).toDart;

    final connection = WebSerialRfcommConnection(
      deviceId: finalDeviceId,
      deviceName: finalDeviceName,
      port: port,
    );
    _currentConnection = connection;
    await connection.start();
    return connection;
  }

  @override
  Future<void> send(Uint8List data) async {
    final connection = _currentConnection;
    if (connection == null) {
      throw StateError('No active web serial connection');
    }
    await connection.send(data);
  }

  @override
  Future<void> disconnect() async {
    final connection = _currentConnection;
    _currentConnection = null;
    if (connection != null) {
      await connection.dispose();
    }
  }
}

RfcommDriver createRfcommDriver() => WebSerialRfcommDriver();
RfcommConnection createRfcommConnection({
  required String deviceId,
  required String deviceName,
  required RfcommDriver service,
}) => throw UnsupportedError(
  'Web serial connection is created by the service; use connect() instead.',
);
