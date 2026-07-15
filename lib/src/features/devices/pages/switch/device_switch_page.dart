import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/models/device.dart';
import 'package:zerobox/src/core/utils/layout.dart';
import 'package:zerobox/src/device/core/connect_type.dart';
import 'package:zerobox/src/device/core/device_profile.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/devices/services/device_share_link.dart';
import 'package:zerobox/src/features/devices/providers/pending_shared_device_provider.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart' as proto;

class DeviceSwitchPage extends ConsumerStatefulWidget {
  const DeviceSwitchPage({super.key});

  @override
  ConsumerState<DeviceSwitchPage> createState() => _DeviceSwitchPageState();
}

class _DeviceSwitchPageState extends ConsumerState<DeviceSwitchPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (mounted && !kIsWeb) {
        ref.read(deviceManagerProvider.notifier).startBluetoothScan();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pending = ref.read(pendingSharedDeviceProvider);
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(pendingSharedDeviceProvider.notifier).set(null);
        _showPendingDeviceDialog(pending);
      });
    }
  }

  Future<void> _showPendingDeviceDialog(MiWearState device) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(deviceManagerProvider.notifier).importSharedDevice(device);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deviceActionsShareQR),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name),
            const SizedBox(height: 4),
            Text(
              device.addr,
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.deviceConnect),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final currentAddr = state.protocolState == proto.ProtocolState.ready
        ? state.currentDevice?.addr
        : null;

    ref.listen<DeviceManagerState>(deviceManagerProvider, (previous, next) {
      final wasConnecting = previous?.connecting ?? false;
      final isReady = next.protocolState == proto.ProtocolState.ready;
      final connectedTarget = next.connectionTargetAddr;
      final justBecameReady =
          isReady &&
          wasConnecting &&
          !next.connecting &&
          connectedTarget != null &&
          previous?.connectionTargetAddr == connectedTarget &&
          next.currentDevice?.addr == connectedTarget;
      if (wasConnecting && justBecameReady) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.deviceConnected)));
        if (context.mounted) {
          context.pop();
        }
      } else if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l10n, next.error))),
        );
      }
    });

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.switchDeviceTitle)),
      body: !kIsWeb
          ? _buildLayout(context, ref, state, currentAddr)
          : _buildWebLayout(context, state, currentAddr),
    );
  }

  Widget _buildLayout(
    BuildContext context,
    WidgetRef ref,
    DeviceManagerState state,
    String? currentAddr,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = useWideLayout(constraints.maxWidth);
        final savedList = _SavedDeviceList(
          selectedAddr: currentAddr,
          onComplete: () => setState(() {}),
        );
        final scanList = _ScanDeviceList(onComplete: () => setState(() {}));

        return PageContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('connect-band7pro-test'),
                        onPressed: state.connecting
                            ? null
                            : () => _connectXiaomiBand7Pro(context),
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('连接设备 - 7 Pro'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _ListWrapper(
                              isFirst: true,
                              child: savedList,
                            ),
                          ),
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          Expanded(
                            child: _ListWrapper(
                              isFirst: false,
                              child: scanList,
                            ),
                          ),
                        ],
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _SectionHeader(
                              title: AppLocalizations.of(context)!.savedDevices,
                            ),
                          ),
                          _SliverSavedDeviceList(
                            selectedAddr: currentAddr,
                            onComplete: () => setState(() {}),
                          ),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _ScanSectionHeader(
                              onComplete: () => setState(() {}),
                            ),
                          ),
                          _SliverScanDeviceList(
                            onComplete: () => setState(() {}),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _connectXiaomiBand7Pro(BuildContext context) async {
    final authKey = await _promptBand7ProValue(
      context,
      title: 'Xiaomi Smart Band 7 Pro',
      label: 'Authkey',
      hint: '32 位十六进制 authkey',
      obscureText: true,
      validator: (value) {
        final normalized = value.toLowerCase().replaceFirst('0x', '');
        return RegExp(r'^[0-9a-f]{32}$').hasMatch(normalized)
            ? null
            : '请输入 32 位十六进制 authkey';
      },
    );
    if (authKey == null || !context.mounted) return;

    final address = await _promptBand7ProValue(
      context,
      title: 'Xiaomi Smart Band 7 Pro',
      label: '蓝牙地址',
      hint: '例如 AA:BB:CC:DD:EE:FF',
      validator: (value) => value.trim().isEmpty ? '请输入蓝牙地址' : null,
    );
    if (address == null || !context.mounted) return;

    final manager = ref.read(deviceManagerProvider.notifier);
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        // Desktop BLE backends require a peripheral discovered by the current
        // process. macOS exposes a CoreBluetooth UUID, while Windows/Linux may
        // expose a normalized address; in both cases connect with the scan ID.
        await manager.selectAndConnectXiaomiBand7Pro(
          authKey.trim(),
          expectedAddress: address.trim(),
        );
      } else {
        await manager.connectXiaomiBand7Pro(address.trim(), authKey.trim());
      }
    } catch (_) {
      // DeviceManager records the full error and publishes it in state. The
      // page listener presents that error; do not leak it as an unhandled
      // asynchronous exception from the button callback.
    }
  }

  Future<String?> _promptBand7ProValue(
    BuildContext context, {
    required String title,
    required String label,
    required String hint,
    required String? Function(String value) validator,
    bool obscureText = false,
  }) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscureText,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              errorText: errorText,
            ),
            onSubmitted: (_) {
              final error = validator(controller.text.trim());
              if (error != null) {
                setDialogState(() => errorText = error);
              } else {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final error = validator(controller.text.trim());
                if (error != null) {
                  setDialogState(() => errorText = error);
                  return;
                }
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('下一步'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _buildWebLayout(
    BuildContext context,
    DeviceManagerState state,
    String? currentAddr,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = useWideLayout(constraints.maxWidth);
        final savedList = _SavedDeviceList(
          selectedAddr: currentAddr,
          onComplete: () => setState(() {}),
        );

        return PageContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ListWrapper(isFirst: true, child: savedList),
                    ),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const Expanded(
                      child: _ListWrapper(
                        isFirst: false,
                        child: _WebSerialHint(),
                      ),
                    ),
                  ],
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: AppLocalizations.of(context)!.savedDevices,
                      ),
                    ),
                    if (state.pairedDevices.isEmpty)
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height: 96,
                          child: _EmptyState(message: ''),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: state.pairedDevices.length,
                        itemBuilder: (context, index) {
                          final device = state.pairedDevices[index];
                          return _DeviceCard(
                            key: ValueKey('web-saved-${device.addr}'),
                            device: device,
                            connected:
                                device.addr == currentAddr &&
                                !device.disconnected,
                            saved: true,
                          );
                        },
                      ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                    ),
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _WebSerialHint(),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ListWrapper extends StatelessWidget {
  const _ListWrapper({required this.child, required this.isFirst});

  final Widget child;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(left: isFirst ? 0 : 20, right: isFirst ? 20 : 0),
      decoration: isFirst
          ? BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            )
          : null,
      child: child,
    );
  }
}

class _WebSerialHint extends ConsumerWidget {
  const _WebSerialHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cable, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            l10n.webSerialTitle,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.webSerialHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showWebSerialConnectDialog(context),
            icon: const Icon(Icons.link),
            label: Text(l10n.deviceConnect),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('connect-band7pro-test-web'),
            onPressed: () => _showBand7ProConnectDialog(context, ref),
            icon: const Icon(Icons.science_outlined),
            label: const Text('连接设备 - 7 Pro'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBand7ProConnectDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final authKey = await _promptValue(
      context,
      label: 'Authkey',
      hint: '32 位十六进制 authkey',
      obscureText: true,
      validator: (value) {
        final normalized = value.toLowerCase().replaceFirst('0x', '');
        return RegExp(r'^[0-9a-f]{32}$').hasMatch(normalized)
            ? null
            : '请输入 32 位十六进制 authkey';
      },
    );
    if (authKey == null || !context.mounted) return;
    await ref
        .read(deviceManagerProvider.notifier)
        .selectAndConnectXiaomiBand7Pro(authKey.trim());
  }

  Future<String?> _promptValue(
    BuildContext context, {
    required String label,
    required String hint,
    required String? Function(String value) validator,
    bool obscureText = false,
  }) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Xiaomi Smart Band 7 Pro'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscureText,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              errorText: errorText,
            ),
            onSubmitted: (_) {
              final error = validator(controller.text.trim());
              if (error != null) {
                setDialogState(() => errorText = error);
                return;
              }
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final error = validator(controller.text.trim());
                if (error != null) {
                  setDialogState(() => errorText = error);
                  return;
                }
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('下一步'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _showWebSerialConnectDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final container = ProviderScope.containerOf(context, listen: false);
    final authController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.webSerialConnectDialogTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.webSerialConnectDialogHint,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: authController,
                  decoration: InputDecoration(
                    labelText: l10n.authkeyPrompt,
                    hintText: l10n.authkeyPlaceholder,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final authKey = authController.text.trim();
                if (authKey.isEmpty) {
                  return;
                }
                final saved = _buildWebSerialSavedDevice(authKey: authKey);
                Navigator.of(context).pop();
                final manager = container.read(deviceManagerProvider.notifier);
                await manager.connect(
                  saved.addr,
                  saved.name,
                  authKey,
                  connectType: saved.connectType,
                );
              },
              child: Text(l10n.deviceConnect),
            ),
          ],
        );
      },
    );
    authController.dispose();
  }

  MiWearState _buildWebSerialSavedDevice({required String authKey}) {
    final addr = _webSerialStorageId(authKey);
    return MiWearState(
      name: 'Web Serial',
      addr: addr,
      connectType: ConnectType.spp.name,
      authkey: authKey,
      disconnected: true,
    );
  }

  String _webSerialStorageId(String authKey) {
    final normalized = authKey.trim().toLowerCase();
    final suffix = normalized.length <= 8
        ? normalized
        : normalized.substring(0, 8);
    return 'web-serial:$suffix';
  }
}

class _SavedDeviceList extends ConsumerWidget {
  const _SavedDeviceList({
    required this.selectedAddr,
    required this.onComplete,
  });

  final String? selectedAddr;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.savedDevices, hiddenOnMobile: true),
        if (state.pairedDevices.isEmpty)
          const Flexible(
            child: SizedBox(height: 240, child: _EmptyState(message: '')),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: state.pairedDevices.length,
              itemBuilder: (context, index) {
                final device = state.pairedDevices[index];
                return _DeviceCard(
                  key: ValueKey('saved-${device.addr}'),
                  device: device,
                  connected:
                      device.addr == selectedAddr && !device.disconnected,
                  saved: true,
                  onComplete: onComplete,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ScanDeviceList extends ConsumerStatefulWidget {
  const _ScanDeviceList({required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<_ScanDeviceList> createState() => _ScanDeviceListState();
}

class _ScanDeviceListState extends ConsumerState<_ScanDeviceList> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedOpacity(
          opacity: state.scanning ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: const LinearProgressIndicator(minHeight: 2),
        ),
        _SectionHeader(
          title: l10n.scanAndAdd,
          trailing: IconButton(
            icon: AnimatedRotation(
              turns: state.scanning ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: const Icon(Icons.refresh),
            ),
            onPressed: state.scanning
                ? null
                : () => ref
                      .read(deviceManagerProvider.notifier)
                      .startBluetoothScan(),
            tooltip: l10n.refresh,
          ),
        ),
        if (!state.scanning && state.scannedDevices.isEmpty)
          const Flexible(
            child: SizedBox(height: 240, child: _EmptyState(message: '')),
          )
        else if (state.scanning && state.scannedDevices.isEmpty)
          const Flexible(
            child: SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: state.scannedDevices.length,
              itemBuilder: (context, index) {
                final device = state.scannedDevices[index];
                return _DeviceCard(
                  key: ValueKey('scan-${device.addr}'),
                  device: MiWearState(
                    name: device.name,
                    addr: device.addr,
                    connectType: device.connectType,
                    disconnected: true,
                  ),
                  saved: false,
                  onComplete: widget.onComplete,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SliverSavedDeviceList extends ConsumerWidget {
  const _SliverSavedDeviceList({
    required this.selectedAddr,
    required this.onComplete,
  });

  final String? selectedAddr;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceManagerProvider);

    if (state.pairedDevices.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(height: 240, child: _EmptyState(message: '')),
      );
    }
    return SliverList.builder(
      itemCount: state.pairedDevices.length,
      itemBuilder: (context, index) {
        final device = state.pairedDevices[index];
        return _DeviceCard(
          key: ValueKey('saved-${device.addr}'),
          device: device,
          connected: device.addr == selectedAddr && !device.disconnected,
          saved: true,
          onComplete: onComplete,
        );
      },
    );
  }
}

class _ScanSectionHeader extends ConsumerWidget {
  const _ScanSectionHeader({required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedOpacity(
          opacity: state.scanning ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: const LinearProgressIndicator(minHeight: 2),
        ),
        _SectionHeader(
          title: l10n.scanAndAdd,
          trailing: IconButton(
            icon: AnimatedRotation(
              turns: state.scanning ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: const Icon(Icons.refresh),
            ),
            onPressed: state.scanning
                ? null
                : () => ref
                      .read(deviceManagerProvider.notifier)
                      .startBluetoothScan(),
            tooltip: l10n.refresh,
          ),
        ),
      ],
    );
  }
}

class _SliverScanDeviceList extends ConsumerStatefulWidget {
  const _SliverScanDeviceList({required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<_SliverScanDeviceList> createState() =>
      _SliverScanDeviceListState();
}

class _SliverScanDeviceListState extends ConsumerState<_SliverScanDeviceList> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagerProvider);

    if (!state.scanning && state.scannedDevices.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(height: 240, child: _EmptyState(message: '')),
      );
    }
    if (state.scanning && state.scannedDevices.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return SliverList.builder(
      itemCount: state.scannedDevices.length,
      itemBuilder: (context, index) {
        final device = state.scannedDevices[index];
        return _DeviceCard(
          key: ValueKey('scan-${device.addr}'),
          device: MiWearState(
            name: device.name,
            addr: device.addr,
            connectType: device.connectType,
            disconnected: true,
          ),
          saved: false,
          onComplete: widget.onComplete,
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.hiddenOnMobile = false,
  });

  final String title;
  final Widget? trailing;
  final bool hiddenOnMobile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isWide = useWideLayout(MediaQuery.sizeOf(context).width);
    if (hiddenOnMobile && !isWide) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard({
    super.key,
    required this.device,
    this.connected = false,
    this.saved = false,
    this.onComplete,
  });

  final MiWearState device;
  final bool connected;
  final bool saved;
  final VoidCallback? onComplete;

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  bool _showInput = false;
  bool _showConnectionError = false;
  late final TextEditingController _authController;

  @override
  void initState() {
    super.initState();
    _authController = TextEditingController(text: widget.device.authkey ?? '');
  }

  @override
  void didUpdateWidget(covariant _DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.addr != widget.device.addr ||
        oldWidget.saved != widget.saved) {
      _showInput = false;
      _showConnectionError = false;
      _authController.text = widget.device.authkey ?? '';
    } else if (oldWidget.device.authkey != widget.device.authkey &&
        !_showInput) {
      _authController.text = widget.device.authkey ?? '';
    }
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final authKey = _authController.text;
    setState(() {
      _showInput = false;
      _showConnectionError = false;
    });
    await ref
        .read(deviceManagerProvider.notifier)
        .connect(
          widget.device.addr,
          widget.device.name,
          authKey,
          connectType: widget.device.connectType,
        );
    widget.onComplete?.call();
    if (mounted) {
      final state = ref.read(deviceManagerProvider);
      final connectedThisDevice =
          state.protocolState == proto.ProtocolState.ready &&
          state.currentDevice?.addr == widget.device.addr;
      if (connectedThisDevice) {
        if (context.canPop()) {
          context.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(deviceManagerProvider);
    final profile = DeviceRegistry.resolveIdentity(
      name: widget.device.name,
      codename: widget.device.codename,
    );
    final isUnrecognized =
        !widget.saved && profile.id == DeviceRegistry.unknown.id;
    final transportLabel = widget.device.connectType.toLowerCase() == 'spp'
        ? l10n.deviceTransportSpp
        : l10n.deviceTransportBle;
    final isConnectionTarget = state.connectionTargetAddr == widget.device.addr;
    final isConnectingThisDevice = state.connecting && isConnectionTarget;

    ref.listen<DeviceManagerState>(deviceManagerProvider, (previous, next) {
      final failedThisDevice =
          (previous?.connecting ?? false) &&
          !next.connecting &&
          next.connectStatus == 3 &&
          next.connectionTargetAddr == widget.device.addr;
      if (failedThisDevice && mounted) {
        setState(() {
          _showInput = true;
          _showConnectionError = true;
        });
      }
    });

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 5),
      color: widget.connected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: widget.connected
                ? null
                : () => setState(() => _showInput = !_showInput),
            borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isUnrecognized)
                    Icon(
                      Icons.warning_rounded,
                      size: 32,
                      color: colorScheme.onSurfaceVariant,
                    )
                  else
                    SvgPicture.asset(
                      widget.device.illustrationAsset(),
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.device.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        Text(
                          isUnrecognized
                              ? '${widget.device.addr} · $transportLabel · '
                                    '${l10n.deviceCompatibilityUnknown}'
                              : '${widget.device.addr} · $transportLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isConnectingThisDevice)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.cancel,
                          onPressed: () => ref
                              .read(deviceManagerProvider.notifier)
                              .cancelConnect(),
                        ),
                      ],
                    )
                  else if (widget.saved)
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        final manager = ref.read(
                          deviceManagerProvider.notifier,
                        );
                        if (value == 'delete') {
                          await manager.removeDevice(widget.device.addr);
                        } else if (value == 'disconnect') {
                          await manager.disconnect();
                        } else if (value == 'share') {
                          await Future.delayed(
                            const Duration(milliseconds: 50),
                          );
                          if (context.mounted) {
                            await _showQrDialog(context, widget.device);
                          }
                        }
                        widget.onComplete?.call();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline),
                              const SizedBox(width: 8),
                              Text(l10n.deviceActionsDelete),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'disconnect',
                          enabled: widget.connected,
                          child: Row(
                            children: [
                              const Icon(Icons.power_off_outlined),
                              const SizedBox(width: 8),
                              Text(l10n.deviceActionsDisconnect),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'share',
                          enabled: widget.device.authkey?.isNotEmpty ?? false,
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code_2),
                              const SizedBox(width: 8),
                              Text(l10n.deviceActionsShareQR),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _showInput || isConnectingThisDevice
                ? Padding(
                    padding: isConnectingThisDevice && !_showInput
                        ? const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          )
                        : const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showInput)
                          TextField(
                            controller: _authController,
                            enabled: !state.connecting && !widget.connected,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: l10n.authkeyPrompt,
                              hintText: l10n.authkeyPlaceholder,
                              errorText: _showConnectionError
                                  ? l10n.connectFailed
                                  : null,
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: colorScheme.error,
                                  width: 2,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: colorScheme.error,
                                  width: 2,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: state.connecting ? null : _connect,
                              ),
                            ),
                          ),
                        if (isConnectingThisDevice)
                          Text(
                            _connectionPhaseLabel(l10n, state),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _connectionPhaseLabel(
    AppLocalizations l10n,
    DeviceManagerState state,
  ) {
    final deviceName = state.connectionTargetName ?? widget.device.name;
    return switch (state.connectionPhase) {
      DeviceConnectionPhase.preparing => l10n.deviceConnectionPreparing,
      DeviceConnectionPhase.connectingTransport =>
        l10n.deviceConnectionEstablishing(
          widget.device.connectType.toUpperCase(),
        ),
      DeviceConnectionPhase.initializingProtocol =>
        l10n.deviceConnectionInitializing,
      DeviceConnectionPhase.authenticating =>
        l10n.deviceConnectionAuthenticating,
      DeviceConnectionPhase.fetchingDeviceStatus =>
        l10n.deviceConnectionFetchingStatus,
      null => l10n.deviceConnectingTo(deviceName),
    };
  }

  Future<void> _showQrDialog(BuildContext context, MiWearState device) async {
    final l10n = AppLocalizations.of(context)!;
    var compatibleMode = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final link =
              (compatibleMode
                      ? DeviceShareLink.buildAstroBoxCompatible(device)
                      : DeviceShareLink.build(device))
                  .toString();
          return AlertDialog(
            title: Text(l10n.deviceActionsShareQR),
            content: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: link,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    link,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setDialogState(() => compatibleMode = !compatibleMode);
                    },
                    icon: Icon(compatibleMode ? Icons.link : Icons.swap_horiz),
                    label: Text(
                      compatibleMode
                          ? l10n.deviceShareZeroBoxCode
                          : l10n.deviceShareAstroBoxCompatibleCode,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                },
                child: Text(l10n.copy),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          if (message != null && message!.isNotEmpty)
            Text(
              message!,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
