import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;
import 'package:zerobox/src/protocols/xiaomi/packet/l2_packet.dart';
import 'package:zerobox_network/zerobox_network.dart';

class XiaomiNetworkSystem extends XiaomiSystem {
  static final _log = getLogger('XiaomiNetworkSystem');

  ZeroboxNetworkSession? _session;
  StreamSubscription<Uint8List>? _outboundSubscription;
  StreamSubscription<ZeroboxNetworkEvent>? _eventSubscription;
  ZeroboxNetworkStatistics? _statistics;
  Future<void> _outboundTail = Future<void>.value();
  bool _disposed = false;

  ZeroboxNetworkStatistics? get statistics => _statistics;

  Future<void> start() async {
    if (_disposed) {
      throw StateError('Xiaomi network system is disposed');
    }
    if (_session != null) return;

    final ZeroboxNetworkSession session;
    try {
      session = await ZeroboxNetworkSession.open();
    } on UnsupportedError catch (error) {
      _log.info('[${entity.id}] network proxy unavailable: $error');
      return;
    }

    _session = session;
    _outboundSubscription = session.outboundPackets.listen(_queueOutbound);
    _eventSubscription = session.events.listen(
      _onNetworkEvent,
      onError: (Object error, StackTrace stackTrace) {
        _log.warning(
          '[${entity.id}] network runtime event failed',
          error,
          stackTrace,
        );
      },
    );

    try {
      await component.sendPbPacket(_buildNetworkStatusPacket());
      _log.info('[${entity.id}] network proxy enabled');
    } catch (_) {
      await _closeSession();
      rethrow;
    }
  }

  @override
  void onLayer2Packet(L2Channel channel, L2OpCode opcode, Uint8List payload) {
    if (channel != L2Channel.network) return;
    final session = _session;
    if (session == null) return;
    try {
      session.pushInbound(payload);
    } catch (error, stackTrace) {
      _log.warning('[${entity.id}] network packet rejected', error, stackTrace);
    }
  }

  void _queueOutbound(Uint8List packet) {
    _outboundTail = _outboundTail
        .then((_) => component.sendL2NetworkData(packet))
        .catchError((Object error, StackTrace stackTrace) {
          _log.warning(
            '[${entity.id}] network packet send failed',
            error,
            stackTrace,
          );
        });
  }

  void _onNetworkEvent(ZeroboxNetworkEvent event) {
    switch (event) {
      case ZeroboxNetworkStatus(:final message):
        _log.info('[${entity.id}] $message');
      case ZeroboxNetworkWarning(:final message):
        _log.warning('[${entity.id}] $message');
      case ZeroboxNetworkStatistics():
        _statistics = event;
      case ZeroboxNetworkPacket():
      case ZeroboxNetworkClosed():
        break;
    }
  }

  Future<void> _closeSession() async {
    final session = _session;
    _session = null;
    await _outboundSubscription?.cancel();
    _outboundSubscription = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    if (session != null) {
      await session.close();
    }
    await _outboundTail;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _closeSession();
    await super.dispose();
  }
}

pb.WearPacket _buildNetworkStatusPacket() {
  return pb.WearPacket(
    type: pb.WearPacket_Type.SYSTEM,
    id: pb_system.System_SystemID.SYNC_NETWORK_STATUS.value,
    system: pb_system.System(
      networkStatus: pb_system.NetworkStatus(capability: 2),
    ),
  );
}
