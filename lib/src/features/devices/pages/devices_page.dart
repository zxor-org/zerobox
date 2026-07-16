import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/models/device.dart';
import 'package:zerobox/src/core/utils/layout.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/resources/services/install_queue_notifier.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart' as proto;

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final device = state.currentDevice;

    final isReady = state.protocolState == proto.ProtocolState.ready;
    void reconnectCurrent() {
      final current = state.currentDevice;
      if (current == null || current.authkey == null) return;
      ref
          .read(deviceManagerProvider.notifier)
          .connect(
            current.addr,
            current.name,
            current.authkey!,
            connectType: current.connectType,
          );
    }

    Future<void> refreshOrReconnect() async {
      final current = state.currentDevice;
      if (current == null) return;
      final manager = ref.read(deviceManagerProvider.notifier);
      if (current.disconnected) {
        reconnectCurrent();
        return;
      }
      await manager.refreshDeviceData();
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        final files = detail.files
            .where((file) => file.path.isNotEmpty)
            .toList();
        if (files.isEmpty) return;
        final queue = ref.read(installQueueProvider.notifier);
        for (final file in files) {
          queue.enqueueLocalFile(file);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.queueAddedFiles(files.length))),
        );
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: Text(l10n.devicesTab),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: state.connecting || device == null
                  ? null
                  : refreshOrReconnect,
              tooltip: device?.disconnected ?? true
                  ? l10n.deviceReconnect
                  : l10n.refresh,
            ),
          ],
        ),
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = useWideLayout(constraints.maxWidth);
                final infoPanel = _DeviceInfoPanel(
                  device: device,
                  isReady: isReady,
                  battery: state.battery,
                  onReconnect: reconnectCurrent,
                  onSwitch: () {
                    context.push('/devices/switch');
                  },
                );
                final featuresPanel = _DeviceFeaturesPanel(
                  enabled: isReady,
                  hasDevice: device != null,
                  isZeppOs: device?.codename?.startsWith('zepp:') ?? false,
                );

                return PageContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                  ),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: infoPanel),
                            Expanded(child: featuresPanel),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              infoPanel,
                              const SizedBox(height: 24),
                              featuresPanel,
                            ],
                          ),
                        ),
                );
              },
            ),
            if (_dragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.upload_file,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(l10n.queueDragToInstall),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeviceInfoPanel extends StatelessWidget {
  const _DeviceInfoPanel({
    required this.device,
    required this.isReady,
    this.battery,
    required this.onReconnect,
    required this.onSwitch,
  });

  final MiWearState? device;
  final bool isReady;
  final BatteryStatus? battery;
  final VoidCallback onReconnect;
  final VoidCallback onSwitch;

  bool get _isConnected => isReady && device != null && !device!.disconnected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final illustration =
        device?.illustrationAsset() ?? 'assets/images/devices/xiaomi-watch.svg';
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    Widget infoContent;
    if (device != null) {
      infoContent = Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            device!.name,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isConnected ? l10n.deviceConnected : l10n.deviceDisconnected,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: _isConnected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              if (_isConnected && battery != null) ...[
                _VerticalDivider(),
                _BatteryIndicator(battery: battery!),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (!_isConnected)
                _ActionButton(
                  icon: Icons.link,
                  label: l10n.deviceReconnect,
                  onPressed: onReconnect,
                ),
              _ActionButton(
                icon: Icons.swap_horiz,
                label: _isConnected ? l10n.deviceSwitch : l10n.deviceConnect,
                onPressed: onSwitch,
              ),
            ],
          ),
        ],
      );
    } else {
      infoContent = Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.deviceNotConnected,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.swap_horiz,
            label: l10n.deviceConnect,
            onPressed: onSwitch,
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: isNarrow
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  illustration,
                  width: 120,
                  height: 120,
                  colorFilter: ColorFilter.mode(
                    colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 16),
                infoContent,
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  illustration,
                  width: 150,
                  height: 150,
                  colorFilter: ColorFilter.mode(
                    colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 24),
                infoContent,
              ],
            ),
    );
  }
}

class _DeviceFeaturesPanel extends ConsumerWidget {
  const _DeviceFeaturesPanel({
    required this.enabled,
    required this.hasDevice,
    required this.isZeppOs,
  });

  final bool enabled;
  final bool hasDevice;
  final bool isZeppOs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSection(
              title: Text(l10n.install),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) => _pickAndEnqueue(context, ref),
                  enabled: enabled,
                  leading: const Icon(Icons.apps_outlined),
                  title: Text(l10n.deviceFeaturesInstallApp),
                  description: Text(l10n.deviceFeaturesInstallAppDesc),
                ),
                SettingsTile.navigation(
                  onPressed: (_) => _pickAndEnqueue(context, ref),
                  enabled: enabled,
                  leading: const Icon(Icons.watch_outlined),
                  title: Text(l10n.deviceFeaturesInstallWatchface),
                  description: Text(l10n.deviceFeaturesInstallWatchfaceDesc),
                ),
                SettingsTile.navigation(
                  onPressed: (_) => _pickAndEnqueue(context, ref),
                  enabled: enabled,
                  leading: const Icon(Icons.memory_outlined),
                  title: Text(l10n.deviceFeaturesInstallFirmware),
                  description: Text(l10n.deviceFeaturesInstallFirmwareDesc),
                ),
              ],
            ),
            SettingsSection(
              title: Text(l10n.manage),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) => context.push('/devices/apps'),
                  enabled: enabled,
                  leading: const Icon(Icons.apps),
                  title: Text(l10n.deviceFeaturesManageApps),
                  description: Text(l10n.deviceFeaturesManageAppsDesc),
                ),
                SettingsTile.navigation(
                  onPressed: (_) => context.push('/devices/watchfaces'),
                  enabled: enabled,
                  leading: const Icon(Icons.watch),
                  title: Text(l10n.deviceFeaturesManageWatchfaces),
                  description: Text(l10n.deviceFeaturesManageWatchfacesDesc),
                ),
                if (isZeppOs)
                  SettingsTile.navigation(
                    onPressed: (_) => context.push('/devices/zeppos-more'),
                    enabled: enabled,
                    leading: const Icon(Icons.functions),
                    title: Text(l10n.zeppOsMoreFeatures),
                    description: Text(l10n.zeppOsMoreFeaturesDescription),
                  ),
                SettingsTile.navigation(
                  onPressed: (_) => context.push('/devices/info'),
                  enabled: hasDevice,
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.deviceFeaturesDeviceInfo),
                  description: Text(l10n.deviceFeaturesDeviceInfoDesc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndEnqueue(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final queue = ref.read(installQueueProvider.notifier);
    queue.enqueueLocalFile(
      XFile.fromData(bytes, name: file.name, path: file.path ?? ''),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: colorScheme.outlineVariant,
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({required this.battery});

  final BatteryStatus battery;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final charging = battery.chargeStatus == ChargeStatus.charging;
    final indicatorColor = charging
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 10,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: 20,
                height: 10,
                decoration: BoxDecoration(
                  border: Border.all(color: indicatorColor, width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Positioned(
                left: 1.5,
                top: 1.5,
                bottom: 1.5,
                child: Container(
                  width: ((20 - 3) * (battery.capacity / 100)).clamp(
                    0.0,
                    20.0 - 3,
                  ),
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        if (charging) ...[
          Icon(Icons.bolt, size: 15, color: colorScheme.primary),
          const SizedBox(width: 2),
        ],
        Text(
          '${battery.capacity}%',
          style: TextStyle(color: indicatorColor, fontSize: 13, height: 1),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
