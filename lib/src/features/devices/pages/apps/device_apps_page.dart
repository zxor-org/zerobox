import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart' as proto;

class DeviceAppsPage extends ConsumerStatefulWidget {
  const DeviceAppsPage({super.key});

  @override
  ConsumerState<DeviceAppsPage> createState() => _DeviceAppsPageState();
}

class _DeviceAppsPageState extends ConsumerState<DeviceAppsPage> {
  bool _loading = false;
  String? _error;
  bool _showSystemApps = false;

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
      await ref.read(deviceManagerProvider.notifier).fetchApps();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppInfo> _filterApps(List<AppInfo> apps) {
    if (_showSystemApps) return apps;
    return apps
        .where((app) => !app.packageName.startsWith('com.xiaomi.miwear.'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    final displayedApps = _filterApps(state.apps);

    return Scaffold(
      appBar: SysAppBar(
        title: Text(l10n.appManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: l10n.refresh,
          ),
          IconButton(
            icon: Icon(
              _showSystemApps
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
            ),
            onPressed: () => setState(() => _showSystemApps = !_showSystemApps),
            tooltip: l10n.appManagementShowSystemApps,
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
            ? Center(child: Text('${l10n.error}: $_error'))
            : displayedApps.isEmpty
            ? Center(child: Text(l10n.appManagementNone))
            : ListView.builder(
                itemCount: displayedApps.length,
                itemBuilder: (context, index) {
                  final app = displayedApps[index];
                  return SectionCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(app.appName),
                      subtitle: Text(app.packageName),
                      trailing: _AppActions(app: app, onRefresh: _refresh),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AppActions extends StatelessWidget {
  const _AppActions({required this.app, required this.onRefresh});

  final AppInfo app;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer(
      builder: (context, ref, child) {
        return PopupMenuButton<String>(
          onSelected: (value) async {
            final manager = ref.read(deviceManagerProvider.notifier);
            if (value == 'uninstall') {
              await manager.uninstallApp(app);
              onRefresh();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'uninstall',
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
