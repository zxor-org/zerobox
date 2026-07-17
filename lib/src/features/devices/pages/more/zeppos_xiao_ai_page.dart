import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/wasm/wasm_opus_decoder.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart' as proto;

class ZeppOsXiaoAiPage extends ConsumerStatefulWidget {
  const ZeppOsXiaoAiPage({super.key});

  @override
  ConsumerState<ZeppOsXiaoAiPage> createState() => _ZeppOsXiaoAiPageState();
}

class _ZeppOsXiaoAiPageState extends ConsumerState<ZeppOsXiaoAiPage> {
  final _audio = SoLoud.instance;
  final _replyController = TextEditingController();
  final _opusFrames = <Uint8List>[];
  final _opusDurations = <int>[];
  final _pcmBytes = BytesBuilder(copy: false);
  final _waveform = <double>[];
  StreamSubscription<Uint8List>? _frameSubscription;
  WasmOpusDecoder? _decoder;
  AudioSource? _audioSource;
  bool _playback = true;
  bool _continuousCapture = false;
  int _assistantEndpoint = 0x0010;
  bool _ready = false;
  String? _error;
  int _frames = 0;
  int _opusBytes = 0;
  int _pcmSamples = 0;

  @override
  void initState() {
    super.initState();
    _frameSubscription = ref
        .read(deviceManagerProvider.notifier)
        .xiaoAiOpusFrames
        .listen(_onFrame);
    unawaited(_initializeAudio());
  }

  Future<void> _initializeAudio() async {
    WasmOpusDecoder? decoder;
    try {
      decoder = await WasmOpusDecoder.create();
      if (!mounted) {
        decoder.dispose();
        return;
      }
      await _audio.init(channels: Channels.mono);
      if (!mounted) {
        decoder.dispose();
        _audio.deinit();
        return;
      }
      final source = _audio.setBufferStream(
        maxBufferSizeDuration: const Duration(seconds: 5),
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.08,
        sampleRate: 16000,
        channels: Channels.mono,
        format: BufferType.f32le,
      );
      _audio.play(source);
      if (!mounted) {
        decoder.dispose();
        _audio.deinit();
        return;
      }
      _decoder = decoder;
      _audioSource = source;
      setState(() => _ready = true);
    } catch (error) {
      decoder?.dispose();
      if (_audio.isInitialized) _audio.deinit();
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _onFrame(Uint8List frame) {
    final decoder = _decoder;
    if (decoder == null) return;
    try {
      final pcm = decoder.decode(frame);
      final bytes = ByteData(pcm.length * 2);
      for (var i = 0; i < pcm.length; i += 1) {
        final sample = (pcm[i].clamp(-1.0, 1.0) * 32767).round();
        bytes.setInt16(i * 2, sample, Endian.little);
      }
      if (pcm.isNotEmpty) {
        var peak = 0.0;
        for (final sample in pcm) {
          peak = max(peak, sample.abs());
        }
        _waveform.add(peak.clamp(0.0, 1.0));
        if (_waveform.length > 180) _waveform.removeAt(0);
      }
      _opusFrames.add(Uint8List.fromList(frame));
      _opusDurations.add(pcm.length * 3);
      _pcmBytes.add(bytes.buffer.asUint8List());
      final audioSource = _audioSource;
      if (_playback && pcm.isNotEmpty && audioSource != null) {
        _audio.addAudioDataStream(
          audioSource,
          pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes),
        );
      }
      if (!mounted) return;
      setState(() {
        _frames += 1;
        _opusBytes += frame.length;
        _pcmSamples += pcm.length;
        if (_error?.startsWith('音频处理失败') == true) _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '音频处理失败：$error');
    }
  }

  Future<void> _sendReply() async {
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      await manager.setXiaoAiEndpoint(_assistantEndpoint);
      await manager.sendXiaoAiReply(_replyController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(deviceManagerProvider).xiaoAiActive
                  ? '消息已排队，将在本轮录音结束后返回手表'
                  : '消息已发送到手表',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '发送失败：$error');
    }
  }

  Future<void> _setContinuousCapture(bool enabled) async {
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      await manager.setXiaoAiEndpoint(_assistantEndpoint);
      await manager.setXiaoAiContinuousCapture(enabled);
      if (mounted) setState(() => _continuousCapture = enabled);
    } catch (error) {
      if (mounted) setState(() => _error = '连续采集设置失败：$error');
    }
  }

  Future<void> _setAssistantEndpoint(int endpoint) async {
    if (endpoint == _assistantEndpoint) return;
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .setXiaoAiEndpoint(endpoint);
      if (_ready) {
        _decoder?.dispose();
        _decoder = null;
        final decoder = await WasmOpusDecoder.create();
        if (!mounted) {
          decoder.dispose();
          return;
        }
        _decoder = decoder;
      }
      if (mounted) {
        setState(() {
          _assistantEndpoint = endpoint;
          _continuousCapture = false;
          _waveform.clear();
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '语音助手切换失败：$error');
    }
  }

  Future<void> _saveWav() async {
    try {
      await FilePicker.saveFile(
        dialogTitle: '保存语音助手录音',
        fileName: 'xiaoai-${DateTime.now().millisecondsSinceEpoch}.wav',
        type: FileType.custom,
        allowedExtensions: const ['wav'],
        bytes: _wavFile(_pcmBytes.toBytes()),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '导出 WAV 失败：$error');
    }
  }

  Future<void> _saveOpus() async {
    try {
      await FilePicker.saveFile(
        dialogTitle: '保存语音助手 Opus',
        fileName: 'xiaoai-${DateTime.now().millisecondsSinceEpoch}.opus',
        type: FileType.custom,
        allowedExtensions: const ['opus'],
        bytes: _oggOpusFile(_opusFrames, _opusDurations),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '导出 Opus 失败：$error');
    }
  }

  void _clearCapture() {
    _opusFrames.clear();
    _opusDurations.clear();
    _pcmBytes.clear();
    _waveform.clear();
    setState(() {
      _frames = 0;
      _opusBytes = 0;
      _pcmSamples = 0;
    });
  }

  @override
  void dispose() {
    if (_continuousCapture) {
      unawaited(
        ref
            .read(deviceManagerProvider.notifier)
            .setXiaoAiContinuousCapture(false)
            .catchError((_) {}),
      );
    }
    unawaited(_frameSubscription?.cancel());
    _replyController.dispose();
    _decoder?.dispose();
    if (_audio.isInitialized) _audio.deinit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagerProvider);
    final colors = Theme.of(context).colorScheme;
    final assistantName = _assistantEndpoint == 0x004a ? 'Zepp Flow' : '小爱同学';
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text('语音实验室 · $assistantName')),
      body: PageContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
          vertical: 16,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final main = _SectionCard(
              color: colors.primaryContainer,
              child: _buildSessionPanel(context, state, assistantName),
            );
            final side = _SectionCard(child: _buildCapturePanel(context));
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: main),
                          const SizedBox(width: 16),
                          Expanded(child: side),
                        ],
                      )
                    else ...[
                      main,
                      const SizedBox(height: 16),
                      side,
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSessionPanel(
    BuildContext context,
    DeviceManagerState state,
    String assistantName,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final endpoint = _assistantEndpoint
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: Icon(
                state.xiaoAiActive ? Icons.graphic_eq : Icons.mic_none,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assistantName, style: theme.textTheme.headlineSmall),
                  Text(
                    state.xiaoAiActive ? '正在接收手表音频' : '等待语音会话',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            _StatusBadge(active: state.xiaoAiActive),
          ],
        ),
        const SizedBox(height: 20),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0x0010,
              icon: Icon(Icons.watch),
              label: Text('小爱同学'),
            ),
            ButtonSegment(
              value: 0x004a,
              icon: Icon(Icons.auto_awesome),
              label: Text('Zepp Flow'),
            ),
          ],
          selected: {_assistantEndpoint},
          onSelectionChanged: state.protocolState == proto.ProtocolState.ready
              ? (values) => _setAssistantEndpoint(values.first)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          'Endpoint 0x$endpoint · Opus 16 kHz Mono',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 20),
        Container(
          height: 156,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
          ),
          child: CustomPaint(
            painter: _AudioWaveformPainter(
              samples: List<double>.of(_waveform),
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('连续采集'),
                subtitle: const Text('自动请求下一段语音'),
                value: _continuousCapture,
                onChanged: state.protocolState == proto.ProtocolState.ready
                    ? _setContinuousCapture
                    : null,
              ),
            ),
            IconButton.filledTonal(
              tooltip: _playback ? '关闭监听' : '开启监听',
              onPressed: _ready
                  ? () => setState(() => _playback = !_playback)
                  : null,
              icon: Icon(_playback ? Icons.volume_up : Icons.volume_off),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _replyController,
          decoration: InputDecoration(
            labelText: '返回给手表的消息',
            hintText: '输入回复内容',
            filled: true,
            suffixIcon: IconButton(
              tooltip: '发送',
              icon: const Icon(Icons.send),
              onPressed: _sendReply,
            ),
          ),
          onSubmitted: (_) => _sendReply(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCapturePanel(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.analytics_outlined),
          const SizedBox(width: 12),
          Text('捕获数据', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
      const SizedBox(height: 16),
      _StatRow(label: '解码器', value: _ready ? '已就绪' : '初始化中'),
      _StatRow(label: 'Opus 帧', value: '$_frames'),
      _StatRow(label: '数据量', value: '$_opusBytes B'),
      _StatRow(label: 'PCM 采样', value: '$_pcmSamples'),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: _frames == 0 ? null : _saveOpus,
          icon: const Icon(Icons.save_alt),
          label: const Text('导出 Opus'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _pcmSamples == 0 ? null : _saveWav,
          icon: const Icon(Icons.audio_file),
          label: const Text('导出 WAV'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _frames == 0 ? null : _clearCapture,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('清空捕获'),
        ),
      ),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card.filled(
    color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? colors.primary : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'LIVE' : 'IDLE',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active ? colors.onPrimary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

class _AudioWaveformPainter extends CustomPainter {
  const _AudioWaveformPainter({required this.samples, required this.color});

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, center), Offset(size.width, center), axisPaint);
    if (samples.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = max(1.5, size.width / samples.length * 0.55)
      ..strokeCap = StrokeCap.round;
    final step = size.width / max(samples.length, 1);
    for (var i = 0; i < samples.length; i += 1) {
      final x = (i + 0.5) * step;
      final height = max(1.5, samples[i] * (center - 8));
      canvas.drawLine(
        Offset(x, center - height),
        Offset(x, center + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AudioWaveformPainter oldDelegate) => true;
}

Uint8List _wavFile(Uint8List pcm) {
  final result = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(result);
  void ascii(int offset, String value) =>
      result.setRange(offset, offset + value.length, value.codeUnits);
  ascii(0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  result.setRange(44, result.length, pcm);
  return result;
}

Uint8List _oggOpusFile(List<Uint8List> frames, List<int> durations) {
  final output = BytesBuilder(copy: false);
  const serial = 0x5a455050;
  var sequence = 0;
  var granule = 0;
  final head = Uint8List.fromList([
    ...'OpusHead'.codeUnits,
    1,
    1,
    0,
    0,
    0x80,
    0x3e,
    0,
    0,
    0,
    0,
    0,
  ]);
  final vendor = 'ZeroBox';
  final tags = BytesBuilder()
    ..add('OpusTags'.codeUnits)
    ..add(_le32(vendor.length))
    ..add(vendor.codeUnits)
    ..add(_le32(0));
  output.add(_oggPage(head, serial, sequence++, 0, 0x02));
  output.add(_oggPage(tags.toBytes(), serial, sequence++, 0, 0));
  for (var i = 0; i < frames.length; i += 1) {
    granule += durations[i];
    output.add(
      _oggPage(
        frames[i],
        serial,
        sequence++,
        granule,
        i == frames.length - 1 ? 0x04 : 0,
      ),
    );
  }
  return output.toBytes();
}

Uint8List _oggPage(
  Uint8List packet,
  int serial,
  int sequence,
  int granule,
  int headerType,
) {
  final segments = <int>[];
  var remaining = packet.length;
  while (remaining >= 255) {
    segments.add(255);
    remaining -= 255;
  }
  segments.add(remaining);
  final page = Uint8List(27 + segments.length + packet.length);
  final data = ByteData.sublistView(page);
  page.setRange(0, 4, 'OggS'.codeUnits);
  page[4] = 0;
  page[5] = headerType;
  data.setUint64(6, granule, Endian.little);
  data.setUint32(14, serial, Endian.little);
  data.setUint32(18, sequence, Endian.little);
  page[26] = segments.length;
  page.setRange(27, 27 + segments.length, segments);
  page.setRange(27 + segments.length, page.length, packet);
  data.setUint32(22, _oggCrc(page), Endian.little);
  return page;
}

int _oggCrc(Uint8List bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte << 24;
    for (var bit = 0; bit < 8; bit += 1) {
      crc = (crc & 0x80000000) != 0
          ? ((crc << 1) ^ 0x04c11db7) & 0xffffffff
          : (crc << 1) & 0xffffffff;
    }
  }
  return crc;
}

Uint8List _le32(int value) {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setUint32(0, value, Endian.little);
  return bytes;
}
