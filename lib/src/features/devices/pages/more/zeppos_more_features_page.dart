import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart' as proto;

class ZeppOsMoreFeaturesPage extends ConsumerStatefulWidget {
  const ZeppOsMoreFeaturesPage({super.key});

  @override
  ConsumerState<ZeppOsMoreFeaturesPage> createState() =>
      _ZeppOsMoreFeaturesPageState();
}

class _ZeppOsMoreFeaturesPageState
    extends ConsumerState<ZeppOsMoreFeaturesPage> {
  bool _finding = false;
  bool _busy = false;

  Future<void> _setFinding(bool finding) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .setFindingZeppOsDevice(finding);
      if (mounted) setState(() => _finding = finding);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.zeppOsMoreFeatures)),
      body: PageContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
          vertical: 16,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.record_voice_over),
                      title: const Text('小爱同学'),
                      subtitle: const Text('捕获 Opus 帧并实时解码播放'),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: ready,
                      onTap: ready
                          ? () => context.push('/devices/zeppos-more/xiao-ai')
                          : null,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tune),
                      title: const Text('应用设置'),
                      subtitle: const Text('打开已缓存的 Zepp OS 应用设置页'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/devices/zeppos-more/settings'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.code),
                      title: const Text('App-side 调试'),
                      subtitle: const Text(
                        '按 appId 调试 QuickJS 与 PeerSocket 消息',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: ready,
                      onTap: ready
                          ? () => context.push('/devices/zeppos-more/app-side')
                          : null,
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.vibration,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.zeppOsFindDevice,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.zeppOsFindDeviceDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _finding
                          ? OutlinedButton.icon(
                              onPressed: ready && !_busy
                                  ? () => _setFinding(false)
                                  : null,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.stop_circle_outlined),
                              label: Text(l10n.zeppOsFindDeviceStop),
                            )
                          : FilledButton.icon(
                              onPressed: ready && !_busy
                                  ? () => _setFinding(true)
                                  : null,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.notifications_active),
                              label: Text(l10n.zeppOsFindDeviceStart),
                            ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '实时 Zepp OS 消息',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: state.zeppOsMessages.isEmpty
                              ? null
                              : () => ref
                                    .read(deviceManagerProvider.notifier)
                                    .clearZeppOsMessages(),
                          tooltip: '清空消息',
                          icon: const Icon(Icons.delete_sweep_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '显示现有分包层已经解码的设备上行 endpoint 消息，'
                      '最多保留最近 200 条。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ZeppOsMessageList(messages: state.zeppOsMessages),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZeppOsMessageList extends StatelessWidget {
  const _ZeppOsMessageList({required this.messages});

  final List<ZeppOsMessageRecord> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('暂无设备消息'),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: ListView.separated(
        shrinkWrap: true,
        reverse: true,
        itemCount: messages.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, reverseIndex) {
          final message = messages[messages.length - 1 - reverseIndex];
          final endpoint = message.endpoint
              .toRadixString(16)
              .padLeft(4, '0')
              .toUpperCase();
          final hex = message.payload
              .map(
                (byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase(),
              )
              .join(' ');
          final text = message.payload
              .map(
                (byte) =>
                    byte >= 32 && byte <= 126 ? String.fromCharCode(byte) : '.',
              )
              .join();
          final isoTime = message.timestamp.toLocal().toIso8601String();
          final time = isoTime.length >= 23
              ? isoTime.substring(11, 23)
              : isoTime;
          final copyText =
              '$time EP 0x$endpoint (${message.payload.length} bytes)\n'
              '$hex\n$text';
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '$time  ·  0x$endpoint  ·  ${message.payload.length} bytes',
            ),
            subtitle: SelectableText('$hex\n$text', maxLines: 4),
            trailing: IconButton(
              tooltip: '复制消息',
              onPressed: () => Clipboard.setData(ClipboardData(text: copyText)),
              icon: const Icon(Icons.copy_outlined),
            ),
          );
        },
      ),
    );
  }
}
