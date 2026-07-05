import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
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
        await manager.refreshBattery();
        await manager.fetchSystemInfo();
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

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.deviceInfoTitle)),
      body: PageContainer(
        padding: EdgeInsets.zero,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                l10n.deviceInfoNotRealtime,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            if (device != null)
              _InfoGroup(
                title: l10n.deviceInfoGroupDevice,
                children: [
                  _InfoRow(label: l10n.fieldName, value: device.name),
                  _InfoRow(label: l10n.fieldAddress, value: device.addr),
                  _InfoRow(
                    label: l10n.fieldAuthkey,
                    value: device.authkey ?? '-',
                    secret: true,
                  ),
                  _InfoRow(
                    label: l10n.fieldConnectionType,
                    value: device.connectType,
                  ),
                  _InfoRow(
                    label: l10n.fieldCodename,
                    value: device.codename ?? '-',
                  ),
                ],
              ),
            if (state.systemInfo != null)
              _InfoGroup(
                title: l10n.deviceInfoGroupSystem,
                children: [
                  _InfoRow(
                    label: l10n.fieldModel,
                    value: state.systemInfo!.model,
                  ),
                  _InfoRow(
                    label: l10n.fieldImei,
                    value: state.systemInfo!.imei,
                    secret: true,
                  ),
                  _InfoRow(
                    label: l10n.fieldFirmware,
                    value: state.systemInfo!.firmwareVersion,
                  ),
                  _InfoRow(
                    label: l10n.fieldSerial,
                    value: state.systemInfo!.serialNumber,
                    secret: true,
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
          ],
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
      margin: const EdgeInsets.only(bottom: 16),
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

class _InfoRow extends StatefulWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.secret = false,
  });

  final String label;
  final String value;
  final bool secret;

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _visible = !widget.secret;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = _visible
        ? widget.value
        : String.fromCharCodes(List.filled(widget.value.length, 0x2a));

    return InkWell(
      onTap: () {
        if (widget.secret) {
          setState(() => _visible = !_visible);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            Flexible(
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.copy)),
                  );
                },
                child: Text(
                  displayValue,
                  textAlign: TextAlign.end,
                  maxLines: 1,
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
