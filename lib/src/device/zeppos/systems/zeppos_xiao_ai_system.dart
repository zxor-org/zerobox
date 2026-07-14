import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsXiaoAiSystem extends System {
  static const xiaoAiEndpoint = 0x0010;
  static const zeppFlowEndpoint = 0x004a;
  static const _cmdStart = 0x01;
  static const _cmdEnd = 0x02;
  static const _cmdStartAck = 0x03;
  static const _cmdVoiceData = 0x05;
  static const _cmdReplySimple = 0x09;
  static const _cmdReplyVoiceMore = 0x0b;
  static const _cmdCapabilitiesResponse = 0x21;

  final _voiceBuffer = BytesBuilder(copy: false);
  Timer? _ackTimer;
  Timer? _continueTimer;
  Timer? _replyTimer;
  bool _continuousCapture = false;
  bool _sessionActive = false;
  String? _pendingReply;
  DateTime? _sessionStartedAt;
  int _endpoint = xiaoAiEndpoint;
  int _assistantVersion = 3;

  int get endpoint => _endpoint;

  void selectEndpoint(int endpoint) {
    if (endpoint != xiaoAiEndpoint && endpoint != zeppFlowEndpoint) {
      throw ArgumentError.value(endpoint, 'endpoint', 'Unsupported assistant');
    }
    if (_endpoint == endpoint) return;
    _endpoint = endpoint;
    _assistantVersion = endpoint == zeppFlowEndpoint ? 5 : 3;
    _continuousCapture = false;
    _sessionActive = false;
    _sessionStartedAt = null;
    _pendingReply = null;
    _ackTimer?.cancel();
    _continueTimer?.cancel();
    _replyTimer?.cancel();
    _voiceBuffer.clear();
  }

  void setContinuousCapture(bool enabled) {
    _continuousCapture = enabled;
    if (enabled) {
      _schedulePreemptiveContinuation();
    } else {
      _continueTimer?.cancel();
      _continueTimer = null;
    }
  }

  void handlePayload(int endpoint, Uint8List payload) {
    if (endpoint != _endpoint) return;
    if (payload.isEmpty) return;
    switch (payload[0]) {
      case _cmdStart:
        _handleStart(payload);
        return;
      case _cmdEnd:
        _handleEnd();
        return;
      case _cmdVoiceData:
        _handleVoiceData(payload);
        return;
      case _cmdCapabilitiesResponse:
        if (payload.length > 1 && (payload[1] == 3 || payload[1] == 5)) {
          _assistantVersion = payload[1];
        }
        return;
    }
  }

  Future<void> sendTextReply(String text) async {
    final value = text.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Reply cannot be empty');
    }
    if (_sessionActive) {
      _pendingReply = value;
      _schedulePendingReplyFallback();
      return;
    }
    await _sendTextReplyNow(value);
  }

  Future<void> _sendTextReplyNow(String value) async {
    final payload = Uint8List.fromList([
      _cmdReplySimple,
      ...utf8.encode(value),
      0x00,
    ]);
    await entity.getRequired<ZeppOsDeviceComponent>().sendToEndpoint(
      _endpoint,
      payload,
      encrypted: true,
    );
  }

  void _handleStart(Uint8List payload) {
    _sessionActive = true;
    _sessionStartedAt = DateTime.now();
    _replyTimer?.cancel();
    _continueTimer?.cancel();
    _continueTimer = null;
    _voiceBuffer.clear();
    final jsonStart = payload.indexOf(0x7b);
    var capabilities = <String, Object?>{};
    if (jsonStart >= 0) {
      final jsonEnd = payload.lastIndexOf(0x7d);
      if (jsonEnd >= jsonStart) {
        try {
          capabilities = (jsonDecode(
            utf8.decode(payload.sublist(jsonStart, jsonEnd + 1)),
          ) as Map).cast<String, Object?>();
        } catch (_) {}
      }
    }
    entity.emit(
      XiaoAiSessionStarted(deviceId: entity.id, capabilities: capabilities),
    );
    _ackTimer?.cancel();
    _ackTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(
        entity
            .getRequired<ZeppOsDeviceComponent>()
            .sendToEndpoint(
              _endpoint,
              Uint8List.fromList(const [_cmdStartAck, 0x00]),
              encrypted: true,
            )
            .catchError((Object error, StackTrace stackTrace) {
              entity.emit(
                DeviceError(deviceId: entity.id, error: error.toString()),
              );
            }),
      );
    });
    _schedulePreemptiveContinuation();
  }

  void _handleEnd() {
    _sessionActive = false;
    _sessionStartedAt = null;
    _replyTimer?.cancel();
    _ackTimer?.cancel();
    _ackTimer = null;
    _voiceBuffer.clear();
    entity.emit(XiaoAiSessionEnded(deviceId: entity.id));
    final pendingReply = _pendingReply;
    _pendingReply = null;
    if (pendingReply != null) {
      _continueTimer?.cancel();
      _continueTimer = Timer(const Duration(milliseconds: 120), () async {
        await _sendTextReplyNow(pendingReply);
        if (_continuousCapture) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await _requestMoreVoice();
        }
      });
    } else if (_continuousCapture) {
      _continueTimer?.cancel();
      _continueTimer = Timer(const Duration(milliseconds: 250), () {
        unawaited(_requestMoreVoice());
      });
    }
  }

  void _schedulePendingReplyFallback() {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) return;
    _replyTimer?.cancel();
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = const Duration(milliseconds: 10200) - elapsed;
    _replyTimer = Timer(
      remaining.isNegative ? const Duration(milliseconds: 100) : remaining,
      () async {
        final reply = _pendingReply;
        if (reply == null) return;
        _pendingReply = null;
        await _sendTextReplyNow(reply);
      },
    );
  }

  void _schedulePreemptiveContinuation() {
    if (!_continuousCapture || !_sessionActive) return;
    _continueTimer?.cancel();
    _continueTimer = Timer(const Duration(seconds: 8), () async {
      if (!_continuousCapture || !_sessionActive) return;
      await _requestMoreVoice();
      _schedulePreemptiveContinuation();
    });
  }

  Future<void> _requestMoreVoice() async {
    try {
      await entity.getRequired<ZeppOsDeviceComponent>().sendToEndpoint(
        _endpoint,
        Uint8List.fromList(const [_cmdReplyVoiceMore]),
        encrypted: true,
      );
    } catch (error) {
      entity.emit(DeviceError(deviceId: entity.id, error: error.toString()));
    }
  }

  void _handleVoiceData(Uint8List payload) {
    if (payload.length <= 5) return;
    final sequence = ByteData.sublistView(payload, 1, 5).getUint32(
      0,
      Endian.little,
    );
    _voiceBuffer.add(Uint8List.sublistView(payload, 5));
    var bytes = _voiceBuffer.takeBytes();
    var offset = 0;
    while (offset < bytes.length) {
      final headerLength = _assistantVersion >= 5 ? 8 : 1;
      if (bytes.length - offset < headerLength) break;
      final frameLength = _assistantVersion >= 5
          ? ByteData.sublistView(bytes, offset, offset + 4).getUint32(
              0,
              Endian.big,
            )
          : bytes[offset];
      if (frameLength > 65536) {
        _voiceBuffer.clear();
        entity.emit(
          DeviceError(
            deviceId: entity.id,
            error: 'Invalid assistant Opus frame length: $frameLength',
          ),
        );
        return;
      }
      if (bytes.length - offset - headerLength < frameLength) break;
      offset += headerLength;
      if (frameLength > 0) {
        entity.emit(
          XiaoAiOpusFrameReceived(
            deviceId: entity.id,
            sequence: sequence,
            frame: Uint8List.fromList(
              bytes.sublist(offset, offset + frameLength),
            ),
          ),
        );
      }
      offset += frameLength;
    }
    if (offset < bytes.length) {
      _voiceBuffer.add(Uint8List.sublistView(bytes, offset));
    }
  }

  @override
  Future<void> dispose() async {
    _sessionActive = false;
    _sessionStartedAt = null;
    _pendingReply = null;
    _ackTimer?.cancel();
    _continueTimer?.cancel();
    _replyTimer?.cancel();
    _voiceBuffer.clear();
  }

  @override
  void onData(Uint8List data) {}
}
