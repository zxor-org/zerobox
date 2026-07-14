import 'package:flutter/material.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:zerobox/src/features/devices/services/zeppos_app_settings_service.dart';

class ZeppOsAppSettingsPage extends StatefulWidget {
  const ZeppOsAppSettingsPage({super.key});

  @override
  State<ZeppOsAppSettingsPage> createState() => _ZeppOsAppSettingsPageState();
}

class _ZeppOsAppSettingsPageState extends State<ZeppOsAppSettingsPage> {
  final _storage = ZeppOsAppSideStorage();
  late Future<List<_Item>> _items = _load();

  Future<List<_Item>> _load() async {
    final result = <_Item>[];
    for (final appId in await _storage.listAppIds()) {
      if (!await _storage.settingExists(appId)) continue;
      result.add(
        _Item(
          appId,
          await _storage.readAppName(appId),
          await _storage.exists(appId),
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const SysAppBar(secondary: true, title: Text('应用设置')),
    body: PageContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: StyleConstants.pagePadding,
      ),
      child: FutureBuilder<List<_Item>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty)
            return const Center(child: Text('没有缓存设置页的 Zepp OS 应用'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final id = item.appId.toRadixString(16).padLeft(8, '0');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(item.name ?? '0x$id'),
                  subtitle: Text(
                    '0x$id · ${item.hasAppSide ? '包含 app-side' : '仅设置页'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      await ZeppOsAppSettingsService.instance.open(
                        item.appId,
                        title: item.name ?? '0x$id',
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$error')));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

class _Item {
  const _Item(this.appId, this.name, this.hasAppSide);
  final int appId;
  final String? name;
  final bool hasAppSide;
}
