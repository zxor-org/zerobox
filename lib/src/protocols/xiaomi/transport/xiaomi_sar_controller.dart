import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/protocols/xiaomi/packet/l1_packet.dart';
import 'package:zerobox/src/protocols/xiaomi/packet/l1cmd_packet.dart';
import 'package:zerobox/src/protocols/xiaomi/packet/l2_packet.dart';

class _QueuedData {
  _QueuedData(this.seq, this.payload);
  final int seq;
  final Uint8List payload;
}

class _SendItem {
  _SendItem({
    required this.packet,
    required this.waitAck,
    required this.needRetransmission,
    required this.deadline,
  });

  final L1Packet packet;
  bool waitAck;
  bool needRetransmission;
  DateTime deadline;
}

class _CommandPool {
  final List<Uint8List> _commands = [];
  final List<_QueuedData> _data = [];

  void push(_QueuedData data) => _data.add(data);
  void pushFront(_QueuedData data) => _data.insert(0, data);
  void pushCmd(Uint8List cmd) => _commands.add(cmd);
  void pushCmdFront(Uint8List cmd) => _commands.insert(0, cmd);

  Uint8List? popCmd() => _commands.isNotEmpty ? _commands.removeAt(0) : null;
  _QueuedData? popData() => _data.isNotEmpty ? _data.removeAt(0) : null;
  bool get isEmpty => _commands.isEmpty && _data.isEmpty;

  void clear() {
    _commands.clear();
    _data.clear();
  }
}

class RegisteredAck {
  RegisteredAck({required this.seq, required this.ack});
  final int seq;
  final Future<void> ack;
}

class XiaomiSarController {
  XiaomiSarController({
    required this.onSend,
    required this.onData,
    this.sendTimeout = const Duration(seconds: 10),
    this.txWinOverrunAllowance = 0,
  }) : _log = getLogger('XiaomiSarController') {
    _startTimeoutChecker();
  }

  final Future<void> Function(Uint8List data) onSend;
  final void Function(Uint8List l2Payload) onData;
  final Duration sendTimeout;
  final int txWinOverrunAllowance;
  final Logger _log;

  static const int _localTxWin = 32;

  final _commandPool = _CommandPool();
  final _txQueue = Queue<_SendItem>();
  final _acked = <int>{};
  final _ackWaiters = <int, Completer<void>>{};
  final _ackNotify = StreamController<void>.broadcast();
  Future<void> _sendTail = Future<void>.value();
  int _sendGeneration = 0;

  int _txNextSeq = 0;
  int _txBase = 0;
  int _txWin = 64;
  int _txWinEffective = _computeSoftCapWithAllowance(_localTxWin, 0);
  int _rxExpectSeq = 0;
  int _rxCumAckIndex = 0;
  int _rxCumAckSeq = 0;
  Timer? _rxCumAckTimer;
  Timer? _timeoutTimer;
  bool _cmdExchanged = false;
  Duration _effectiveSendTimeout = const Duration(seconds: 10);

  bool get isStarted => _cmdExchanged;

  int get txWindowSize => _txWinEffective.max(1);
  int get rawTxWindowSize => _txWin.max(1);
  int get sendTimeoutMs => _effectiveSendTimeout.inMilliseconds;

  bool isAcked(int seq) => _acked.contains(seq);

  bool isAllAcked(List<int> seqs) => seqs.every(_acked.contains);

  Stream<void> get ackNotifier => _ackNotify.stream;

  void markAckConsumed(int seq) => _acked.remove(seq);

  void start() {
    _log.info('SAR start, sending L1 start request');
    _sendGeneration++;
    _cmdExchanged = false;
    _txNextSeq = 0;
    _txBase = 0;
    _txWin = 64;
    _txWinEffective = _computeSoftCapWithAllowance(
      _localTxWin,
      txWinOverrunAllowance,
    );
    _rxExpectSeq = 0;
    _rxCumAckIndex = 0;
    _rxCumAckSeq = 0;
    _rxCumAckTimer?.cancel();
    _rxCumAckTimer = null;
    _txQueue.clear();
    _acked.clear();
    for (final waiter in _ackWaiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(StateError('SAR restarted'));
      }
    }
    _ackWaiters.clear();
    _commandPool.clear();
    final startReq = L1CmdBuilder()
        .cmd(CmdCode.cmdL1startReq)
        .version(1, 0, 0)
        .mps(64512)
        .txWin(_localTxWin)
        .sendTimeout(sendTimeout.inMilliseconds)
        .build();
    _commandPool.pushCmdFront(startReq.toPayloadBytes());
    _startTimeoutChecker();
    _tryRunNext();
  }

  int enqueue(Uint8List data) {
    final seq = _allocSeq();
    _commandPool.push(_QueuedData(seq, data));
    _tryRunNext();
    return seq;
  }

  List<int> enqueueBatch(List<Uint8List> payloads) {
    final seqs = <int>[];
    for (final data in payloads) {
      final seq = _allocSeq();
      _commandPool.push(_QueuedData(seq, data));
      seqs.add(seq);
    }
    _tryRunNext();
    return seqs;
  }

  int enqueueFront(Uint8List data) {
    final seq = _allocSeq();
    _commandPool.pushFront(_QueuedData(seq, data));
    _tryRunNext();
    return seq;
  }

  List<int> enqueueFrontBatch(List<Uint8List> payloads) {
    final items = List<Uint8List>.from(payloads.reversed);
    final seqs = <int>[];
    for (final data in items) {
      final seq = _allocSeq();
      _commandPool.pushFront(_QueuedData(seq, data));
      seqs.add(seq);
    }
    _tryRunNext();
    return seqs.reversed.toList();
  }

  Future<void> sendData(Uint8List data) async {
    enqueue(data);
  }

  Future<void> sendFront(Uint8List data) async {
    enqueueFront(data);
  }

  RegisteredAck sendFrontRegisterAck(Uint8List data, {Duration? timeout}) {
    final seq = enqueueFront(data);
    return _registerAckWaiter(seq, timeout);
  }

  RegisteredAck sendDataRegisterAck(Uint8List data, {Duration? timeout}) {
    final seq = enqueue(data);
    return _registerAckWaiter(seq, timeout);
  }

  RegisteredAck _registerAckWaiter(int seq, Duration? timeout) {
    final completer = Completer<void>();
    _ackWaiters[seq] = completer;
    final effectiveTimeout = timeout ?? _effectiveSendTimeout;
    final ack = completer.future.timeout(
      effectiveTimeout,
      onTimeout: () {
        _ackWaiters.remove(seq);
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('SAR ACK timeout for seq $seq', effectiveTimeout),
          );
        }
        throw TimeoutException(
          'SAR ACK timeout for seq $seq',
          effectiveTimeout,
        );
      },
    );
    return RegisteredAck(seq: seq, ack: ack);
  }

  void stop() {
    _log.info('SAR stop');
    _sendGeneration++;
    _timeoutTimer?.cancel();
    _rxCumAckTimer?.cancel();
    _timeoutTimer = null;
    _rxCumAckTimer = null;
    _txQueue.clear();
    _acked.clear();
    for (final waiter in _ackWaiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(StateError('SAR stopped'));
      }
    }
    _ackWaiters.clear();
  }

  void abortPendingTransmissions([Object? reason]) {
    _log.warning('SAR abort pending transmissions', reason);
    _sendGeneration++;
    _commandPool.clear();
    _txQueue.clear();
    _acked.clear();
    for (final waiter in _ackWaiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(StateError('SAR transmissions aborted'));
      }
    }
    _ackWaiters.clear();
    _ackNotify.add(null);
  }

  int _allocSeq() {
    final seq = _txNextSeq;
    _txNextSeq = (_txNextSeq + 1) & 0xFF;
    if (_txNextSeq == 0) {
      _acked.clear();
      _completeAllAckWaiters();
    }
    return seq;
  }

  void _completeAllAckWaiters() {
    for (final entry in _ackWaiters.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete();
      }
    }
    _ackWaiters.clear();
  }

  void _startTimeoutChecker() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkTimeoutsInternal();
    });
  }

  void _checkTimeoutsInternal() {
    final now = DateTime.now();
    var need = false;
    for (final item in _txQueue) {
      if (item.waitAck && now.isAfter(item.deadline)) {
        item.waitAck = false;
        item.needRetransmission = true;
        need = true;
      }
    }
    if (need) {
      _tryRunNext();
    }
  }

  bool onL1Packet(L1Packet packet) {
    switch (packet.pktType) {
      case L1DataType.ack:
        _handleAck(packet.seq);
        return false;
      case L1DataType.nak:
        _handleNak(packet.seq);
        return false;
      case L1DataType.cmd:
        _handleCmd(packet.payload);
        return false;
      case L1DataType.data:
        return _handleData(packet);
    }
  }

  void _handleAck(int seq) {
    var advanced = false;
    while (_txQueue.isNotEmpty) {
      final item = _txQueue.first;
      if (_seqLe(item.packet.seq, seq)) {
        final seqVal = item.packet.seq;
        _acked.add(seqVal);
        _completeAckWaiter(seqVal);
        _txQueue.removeFirst();
        _txBase = (_txBase + 1) & 0xFF;
        advanced = true;
      } else {
        break;
      }
    }
    if (advanced) {
      _ackNotify.add(null);
    }
    _tryRunNext();
  }

  void _completeAckWaiter(int seq) {
    final waiter = _ackWaiters.remove(seq);
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  void _handleNak(int seq) {
    if (seq > 0) {
      _handleAck((seq - 1) & 0xFF);
    }
    for (final item in _txQueue) {
      if (_seqLe(seq, item.packet.seq)) {
        item.needRetransmission = true;
        item.waitAck = false;
      }
    }
    _tryRunNext();
  }

  void _handleCmd(Uint8List payload) {
    final cmd = L1CmdPacket.fromPayloadBytes(payload);
    if (cmd == null) return;
    if (cmd.cmd == CmdCode.cmdL1startRsp) {
      _cmdExchanged = true;
      final win = cmd.getTxWin();
      if (win != null) {
        _txWin = win.clamp(1, 255);
      }
      final to = cmd.getSendTimeout();
      if (to != null && to > 0) {
        // 设备返回的 timeout 经常偏保守；我们自己的重传/等待逻辑用这个值即可。
        _effectiveSendTimeout = Duration(milliseconds: to.clamp(1000, 60000));
      }
      _log.info(
        'SAR started: local_tx_win=$_localTxWin remote_tx_win=$_txWin send_timeout_ms=${_effectiveSendTimeout.inMilliseconds}',
      );
    }
  }

  bool _handleData(L1Packet packet) {
    final channelByte = packet.payload.isNotEmpty ? packet.payload[0] : null;
    final channel = channelByte != null
        ? L2Channel.tryFromValue(channelByte)
        : null;

    final ackable =
        _cmdExchanged &&
        channel != L2Channel.network &&
        channel != L2Channel.multiModal;
    if (!ackable) {
      onData(packet.payload);
      return true;
    }

    if (packet.frx) {
      onData(packet.payload);
      return true;
    }

    if (packet.seq != _rxExpectSeq) {
      final ahead = ((packet.seq - _rxExpectSeq) & 0xFF) < 128;
      if (ahead) {
        _sendNak(_rxExpectSeq);
      }
      return false;
    }

    final immediate =
        _rxCumAckIndex >= (_txWin * 2 / 3) ||
        (channel == L2Channel.pb || channel == L2Channel.lyra);
    if (immediate) {
      _stopCumAckTimer();
      _sendAck(packet.seq);
    } else {
      _rxCumAckIndex = (_rxCumAckIndex + 1).clamp(0, 255);
      _rxCumAckSeq = packet.seq;
      _startCumAckTimer();
    }

    _rxExpectSeq = (_rxExpectSeq + 1) & 0xFF;
    onData(packet.payload);
    return true;
  }

  void _sendAck(int seq) {
    final pkt = L1Packet(
      pktType: L1DataType.ack,
      frx: false,
      seq: seq,
      payload: Uint8List(0),
    );
    _queueSend(pkt.toBytes());
  }

  void _sendNak(int seq) {
    final pkt = L1Packet(
      pktType: L1DataType.nak,
      frx: false,
      seq: seq,
      payload: Uint8List(0),
    );
    _queueSend(pkt.toBytes());
  }

  void _startCumAckTimer() {
    if (_rxCumAckTimer != null) return;
    _rxCumAckTimer = Timer(const Duration(milliseconds: 500), () {
      if (_rxCumAckIndex > 0) {
        final seq = _rxCumAckSeq;
        _rxCumAckIndex = 0;
        _rxCumAckTimer = null;
        _sendAck(seq);
      }
    });
  }

  void _stopCumAckTimer() {
    _rxCumAckTimer?.cancel();
    _rxCumAckTimer = null;
    _rxCumAckIndex = 0;
  }

  bool _seqLe(int a, int b) => ((b - a) & 0xFF) < 128;

  static int _computeSoftCapWithAllowance(int win, int allowance) {
    final base = win.max(1);
    return (base + allowance).clamp(base, 255);
  }

  void _tryRunNext() {
    final retransmit = _txQueue.cast<_SendItem?>().firstWhere(
      (i) => i?.needRetransmission ?? false,
      orElse: () => null,
    );
    if (retransmit != null) {
      final pkt = retransmit.packet;
      retransmit.needRetransmission = false;
      retransmit.waitAck = true;
      retransmit.deadline = DateTime.now().add(_effectiveSendTimeout);
      unawaited(onSend(pkt.toBytes()));
      return;
    }

    final cmdBatch = <Uint8List>[];
    while (true) {
      final cmd = _commandPool.popCmd();
      if (cmd == null) break;
      final pkt = L1Packet(
        pktType: L1DataType.cmd,
        frx: false,
        seq: 0,
        payload: cmd,
      );
      cmdBatch.add(pkt.toBytes());
    }
    if (cmdBatch.isNotEmpty) {
      _sendOneByOne(cmdBatch);
    }

    final dataBatch = <Uint8List>[];
    while (_txQueue.length < txWindowSize) {
      final qd = _commandPool.popData();
      if (qd == null) break;
      final pkt = L1Packet(
        pktType: L1DataType.data,
        frx: false,
        seq: qd.seq,
        payload: qd.payload,
      );
      final bytes = pkt.toBytes();
      dataBatch.add(bytes);
      _txQueue.add(
        _SendItem(
          packet: pkt,
          waitAck: true,
          needRetransmission: false,
          deadline: DateTime.now().add(_effectiveSendTimeout),
        ),
      );
    }
    if (dataBatch.isNotEmpty) {
      _sendOneByOne(dataBatch);
    }
  }

  void _sendOneByOne(List<Uint8List> packets) {
    if (packets.isEmpty) return;
    for (final packet in packets) {
      _queueSend(packet);
    }
  }

  void _queueSend(Uint8List packet) {
    final generation = _sendGeneration;
    final queued = _sendTail.catchError((_) {}).then((_) async {
      if (generation != _sendGeneration) return;
      try {
        await onSend(packet);
      } catch (e, st) {
        _log.warning('SAR onSend failed for ${packet.length} bytes', e, st);
      }
    });
    _sendTail = queued;
    unawaited(queued);
  }
}

extension _IntMax on int {
  int max(int other) => this > other ? this : other;
}
