import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';

class DeviceInfoPage extends ConsumerStatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  ConsumerState<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends ConsumerState<DeviceInfoPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final manager = ref.read(deviceManagerProvider.notifier);
      try {
        await manager.refreshDeviceData();
      } catch (_) {
        // Saved device metadata is still useful when the watch is disconnected.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final device = state.currentDevice;
    final unavailable = Localizations.localeOf(context).languageCode == 'zh'
        ? '未提供'
        : 'Not provided';
    String shown(String value) => value.trim().isEmpty ? unavailable : value;
    String shownCodename(String? value) {
      if (value == null || value.trim().isEmpty) return '-';
      return value.startsWith('zepp:')
          ? value.substring('zepp:'.length)
          : value;
    }

    final items = <Widget>[
      if (device != null)
        _InfoGroup(
          title: l10n.deviceInfoGroupDevice,
          children: [
            _InfoRow(label: l10n.fieldName, value: device.name),
            _InfoRow(label: l10n.fieldAddress, value: device.addr),
            _InfoRow(label: l10n.fieldAuthkey, value: device.authkey ?? '-'),
            _InfoRow(
              label: l10n.fieldConnectionType,
              value: device.connectType,
            ),
            _InfoRow(
              label: l10n.fieldCodename,
              value: shownCodename(device.codename),
            ),
          ],
        ),
      if (state.systemInfo != null)
        _InfoGroup(
          title: l10n.deviceInfoGroupSystem,
          children: [
            _InfoRow(
              label: l10n.fieldModel,
              value: shown(state.systemInfo!.model),
            ),
            _InfoRow(
              label: l10n.fieldImei,
              value: shown(state.systemInfo!.imei),
            ),
            _InfoRow(
              label: l10n.fieldFirmware,
              value: shown(state.systemInfo!.firmwareVersion),
            ),
            _InfoRow(
              label: l10n.fieldSerial,
              value: shown(state.systemInfo!.serialNumber),
            ),
            if (state.systemInfo!.storageInfo != null)
              _InfoRow(
                label: l10n.fieldStorage,
                value: _formatStorage(state.systemInfo!.storageInfo!),
              ),
          ],
        ),
      if (state.battery != null)
        _InfoGroup(
          title: l10n.deviceInfoGroupStatus,
          children: [
            _InfoRow(
              label: l10n.fieldBattery,
              value: '${state.battery!.capacity}%',
            ),
            _InfoRow(
              label: l10n.fieldChargeStatus,
              value: state.battery!.chargeStatus.name,
            ),
          ],
        ),
    ];

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.deviceInfoTitle)),
      body: PageContainer(
        padding: EdgeInsets.zero,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => items[index],
        ),
      ),
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.copy)),
                  );
                },
                child: Text(
                  value,
                  textAlign: TextAlign.start,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatStorage(StorageInfo info) {
  final used = _formatBytes(info.used);
  final total = _formatBytes(info.total);
  return '$used / $total';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
}
