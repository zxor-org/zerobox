import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/zeppos/crypto/zeppos_auth_crypto.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsAuthSystem extends System {
  ZeppOsAuthSystem() : _log = getLogger('ZeppOsAuthSystem');

  static const _response = 0x10;
  static const _success = 0x01;
  static const _cmdPubKey = 0x04;
  static const _cmdSessionKey = 0x05;

  final Logger _log;
  Completer<void>? _authCompleter;
  String? _authKey;
  ZeppOsAuthKeyPair? _keyPair;

  ZeppOsDeviceComponent get _component =>
      entity.getRequired<ZeppOsDeviceComponent>();

  Future<void> authenticate(String authKey) async {
    if (_authCompleter != null) {
      throw StateError('ZeppOS authentication is already running');
    }
    _authCompleter = Completer<void>();
    _authKey = authKey;
    _keyPair = createZeppOsAuthKeyPair();
    final command = Uint8List(52)
      ..[0] = _cmdPubKey
      ..[1] = 0x02
      ..[2] = 0x00
      ..[3] = 0x02;
    command.setRange(4, 52, _keyPair!.publicKey);
    _log.info('starting ZeppOS authentication');
    await _component.sendToEndpoint(
      ZeppOsDeviceComponent.endpointAuthentication,
      command,
    );
    return _authCompleter!.future.timeout(const Duration(seconds: 12));
  }

  @override
  void onData(Uint8List data) {
    try {
      _component.handleIncoming(data);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  void handlePayload(Uint8List payload) {
    if (payload.length < 3 || payload[0] != _response) return;
    switch (payload[1]) {
      case _cmdPubKey:
        _handlePubKeyResponse(payload);
        return;
      case _cmdSessionKey:
        _handleSessionKeyResponse(payload);
        return;
    }
  }

  void _handlePubKeyResponse(Uint8List payload) {
    if (payload[2] != _success) {
      _fail(StateError('ZeppOS public key exchange failed: ${payload[2]}'));
      return;
    }
    if (payload.length < 67) {
      _fail(StateError('ZeppOS public key response is too short'));
      return;
    }
    final remoteRandom = Uint8List.sublistView(payload, 3, 19);
    final remotePublicKey = Uint8List.sublistView(payload, 19, 67);
    final keyPair = _keyPair;
    final authKey = _authKey;
    if (keyPair == null || authKey == null) {
      _fail(StateError('ZeppOS authentication keypair is missing'));
      return;
    }

    final authKeys = completeZeppOsAuth(
      authKey: authKey,
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
      remotePublicKey: remotePublicKey,
    );
    _component.authKeys = authKeys;
    final secretKey = parseZeppOsAuthKey(authKey);
    final encryptedRandom1 = zeppOsAesEcbEncrypt(secretKey, remoteRandom);
    final encryptedRandom2 = zeppOsAesEcbEncrypt(
      authKeys.sessionKey,
      remoteRandom,
    );
    final command = Uint8List(33)..[0] = _cmdSessionKey;
    command.setRange(1, 17, encryptedRandom1);
    command.setRange(17, 33, encryptedRandom2);
    unawaited(
      _component.sendToEndpoint(
        ZeppOsDeviceComponent.endpointAuthentication,
        command,
      ),
    );
  }

  void _handleSessionKeyResponse(Uint8List payload) {
    if (payload[2] == 0x25) {
      _fail(StateError('ZeppOS authentication failed: wrong auth key'));
      return;
    }
    if (payload[2] != _success) {
      _fail(StateError('ZeppOS authentication failed: ${payload[2]}'));
      return;
    }
    _log.info('ZeppOS authentication succeeded');
    entity.emit(DeviceAuthenticated(deviceId: entity.id));
    _authCompleter?.complete();
    _authCompleter = null;
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    _log.warning('ZeppOS authentication failed', error, stackTrace);
    entity.emit(AuthFailed(deviceId: entity.id, error: error.toString()));
    final completer = _authCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    _authCompleter = null;
  }
}
