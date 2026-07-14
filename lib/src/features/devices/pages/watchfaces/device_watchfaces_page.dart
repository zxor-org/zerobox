import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart' as proto;

class DeviceWatchfacesPage extends ConsumerStatefulWidget {
  const DeviceWatchfacesPage({super.key});

  @override
  ConsumerState<DeviceWatchfacesPage> createState() =>
      _DeviceWatchfacesPageState();
}

class _DeviceWatchfacesPageState extends ConsumerState<DeviceWatchfacesPage> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(deviceManagerProvider.notifier).fetchWatchfaces();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.watchfaceManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: PageContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
        ),
        child: !ready
            ? Center(child: Text(l10n.deviceNotConnected))
            : _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(localizedErrorMessage(l10n, _error)))
            : state.watchfaces.isEmpty
            ? Center(child: Text(l10n.watchfaceManagementNone))
            : ListView.builder(
                itemCount: state.watchfaces.length,
                itemBuilder: (context, index) {
                  final watchface = state.watchfaces[index];
                  return SectionCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(watchface.name),
                      subtitle: watchface.isCurrent
                          ? Text(l10n.currentDevice)
                          : Text('ID: ${watchface.id}'),
                      trailing: _WatchfaceActions(
                        watchface: watchface,
                        onRefresh: _refresh,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _WatchfaceActions extends StatelessWidget {
  const _WatchfaceActions({required this.watchface, required this.onRefresh});

  final WatchfaceInfo watchface;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer(
      builder: (context, ref, child) {
        return PopupMenuButton<String>(
          onSelected: (value) async {
            final manager = ref.read(deviceManagerProvider.notifier);
            if (value == 'enable') {
              await manager.setWatchface(watchface);
              onRefresh();
            } else if (value == 'uninstall') {
              await manager.uninstallWatchface(watchface);
              onRefresh();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'enable',
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  Text(l10n.enable),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'uninstall',
              enabled: watchface.canRemove,
              child: Row(
                children: [
                  const Icon(Icons.delete_outline),
                  const SizedBox(width: 8),
                  Text(l10n.uninstall),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
