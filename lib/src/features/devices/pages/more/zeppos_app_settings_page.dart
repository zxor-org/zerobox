import 'dart:typed_data';

import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:zerobox/src/features/devices/pages/more/zeppos_setting_viewer_page.dart';

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
      result.add(
        _Item(
          appId: appId,
          name: await _storage.readAppName(appId),
          hasAppSide: await _storage.exists(appId),
          hasSetting: await _storage.settingExists(appId),
        ),
      );
    }
    return result;
  }

  void _reload() => setState(() => _items = _load());

  Future<void> _supplement({_Item? item}) async {
    final result = await showDialog<_SupplementResult>(
      context: context,
      builder: (context) => _SupplementDialog(item: item),
    );
    if (result == null) return;
    try {
      if (result.appSide != null) {
        await _storage.save(result.appId, result.appSide!);
      }
      if (result.setting != null) {
        await _storage.saveSetting(
          result.appId,
          result.setting!,
          appName: result.name,
        );
      }
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_formatId(result.appId)} 兼容文件已保存')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _open(_Item item) async {
    try {
      await showZeppOsAppSettings(
        context,
        appId: item.appId,
        title: item.name ?? _formatId(item.appId),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _editStorage(_Item item) async {
    try {
      final coordinator = ZeppOsSettingsCoordinator.instance;
      final current = await coordinator.read(item.appId);
      if (!mounted) return;
      final updated = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _StorageEditorDialog(
          appId: item.appId,
          appName: item.name,
          initialValues: current,
        ),
      );
      if (updated == null) return;
      await coordinator.replace(item.appId, updated, origin: this);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_formatId(item.appId)} settingsStorage 已保存')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SysAppBar(
      secondary: true,
      title: const Text('应用设置'),
      actions: [
        IconButton(
          onPressed: _supplement,
          icon: const Icon(Icons.add),
          tooltip: '补全 app-side / setting',
        ),
      ],
    ),
    body: PageContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: StyleConstants.pagePadding,
      ),
      child: FutureBuilder<List<_Item>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: _supplement,
                icon: const Icon(Icons.add),
                label: const Text('补全小程序兼容文件'),
              ),
            );
          }
          return ListView(
            children: [
              SettingsSection(
                margin: EdgeInsetsDirectional.zero,
                tiles: [
                  for (final item in items)
                    SettingsTile.navigation(
                      leading: Icon(
                        item.hasSetting ? Icons.tune : Icons.extension_outlined,
                      ),
                      title: Text(item.name ?? _formatId(item.appId)),
                      description: Text(
                        '${_formatId(item.appId)} · '
                        '${item.hasAppSide ? 'app-side ✓' : 'app-side 缺失'} · '
                        '${item.hasSetting ? 'setting ✓' : 'setting 缺失'}',
                      ),
                      onPressed: item.hasSetting ? (_) => _open(item) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _editStorage(item),
                            icon: const Icon(Icons.storage_outlined),
                            tooltip: '编辑 settingsStorage',
                          ),
                          IconButton(
                            onPressed: () => _supplement(item: item),
                            icon: const Icon(Icons.upload_file_outlined),
                            tooltip: '补全或替换兼容文件',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _StorageEditorDialog extends StatefulWidget {
  const _StorageEditorDialog({
    required this.appId,
    required this.appName,
    required this.initialValues,
  });

  final int appId;
  final String? appName;
  final Map<String, String> initialValues;

  @override
  State<_StorageEditorDialog> createState() => _StorageEditorDialogState();
}

class _StorageEditorDialogState extends State<_StorageEditorDialog> {
  late final List<_StorageEntry> _entries = widget.initialValues.entries
      .map((entry) => _StorageEntry(entry.key, entry.value))
      .toList();
  String? _error;

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _add() {
    setState(() {
      _entries.add(_StorageEntry('', ''));
      _error = null;
    });
  }

  void _remove(int index) {
    setState(() {
      _entries.removeAt(index).dispose();
      _error = null;
    });
  }

  void _clear() {
    setState(() {
      for (final entry in _entries) {
        entry.dispose();
      }
      _entries.clear();
      _error = null;
    });
  }

  void _save() {
    final result = <String, String>{};
    for (final entry in _entries) {
      final key = entry.key.text.trim();
      if (key.isEmpty) {
        setState(() => _error = '键名不能为空');
        return;
      }
      if (result.containsKey(key)) {
        setState(() => _error = '键名重复：$key');
        return;
      }
      result[key] = entry.value.text;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.appName ?? _formatId(widget.appId)),
    content: SizedBox(
      width: 720,
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_formatId(widget.appId)} · settingsStorage'),
          const SizedBox(height: 8),
          const Text('这里的数据由 setting 页面和 app-side 共享。值按 Zepp OS 规范以字符串保存。'),
          const SizedBox(height: 12),
          Expanded(
            child: _entries.isEmpty
                ? const Center(child: Text('暂无存储项'))
                : ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: entry.key,
                              decoration: const InputDecoration(
                                labelText: '键',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: entry.value,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: '值',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _remove(index),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除',
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _clear, child: const Text('清空')),
      OutlinedButton.icon(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('保存')),
    ],
  );
}

class _StorageEntry {
  _StorageEntry(String key, String value)
    : key = TextEditingController(text: key),
      value = TextEditingController(text: value);

  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

class _SupplementDialog extends StatefulWidget {
  const _SupplementDialog({this.item});

  final _Item? item;

  @override
  State<_SupplementDialog> createState() => _SupplementDialogState();
}

class _SupplementDialogState extends State<_SupplementDialog> {
  late final TextEditingController _appId = TextEditingController(
    text: widget.item == null
        ? ''
        : widget.item!.appId.toRadixString(16).padLeft(8, '0'),
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.item?.name ?? '',
  );
  Uint8List? _appSide;
  Uint8List? _setting;
  String? _appSideName;
  String? _settingName;
  String? _error;

  @override
  void dispose() {
    _appId.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool setting}) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['js'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = '无法读取所选文件');
      return;
    }
    setState(() {
      _error = null;
      if (setting) {
        _setting = bytes;
        _settingName = file.name;
      } else {
        _appSide = bytes;
        _appSideName = file.name;
      }
    });
  }

  void _submit() {
    var value = _appId.text.trim().toLowerCase();
    if (value.startsWith('0x')) value = value.substring(2);
    final id = int.tryParse(value, radix: 16);
    if (id == null || id <= 0 || id > 0xffffffff) {
      setState(() => _error = '请输入有效的十六进制 App ID');
      return;
    }
    if (_appSide == null && _setting == null) {
      setState(() => _error = '请至少选择一个 app-side.js 或 setting.js');
      return;
    }
    Navigator.pop(
      context,
      _SupplementResult(
        appId: id,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        appSide: _appSide,
        setting: _setting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? '补全小程序兼容文件' : '补全或替换兼容文件'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _appId,
              enabled: widget.item == null,
              decoration: const InputDecoration(
                labelText: 'App ID（十六进制）',
                hintText: '000f9467',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '显示名称（可选）'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.javascript),
              title: const Text('app-side.js'),
              subtitle: Text(_appSideName ?? '不修改现有 app-side'),
              trailing: OutlinedButton(
                onPressed: () => _pick(setting: false),
                child: const Text('选择文件'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune),
              title: const Text('setting.js'),
              subtitle: Text(_settingName ?? '不修改现有 setting'),
              trailing: OutlinedButton(
                onPressed: () => _pick(setting: true),
                child: const Text('选择文件'),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('保存会覆盖该 App ID 下同名的兼容文件，不会修改手表内的小程序。'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}

class _SupplementResult {
  const _SupplementResult({
    required this.appId,
    required this.name,
    required this.appSide,
    required this.setting,
  });

  final int appId;
  final String? name;
  final Uint8List? appSide;
  final Uint8List? setting;
}

class _Item {
  const _Item({
    required this.appId,
    required this.name,
    required this.hasAppSide,
    required this.hasSetting,
  });

  final int appId;
  final String? name;
  final bool hasAppSide;
  final bool hasSetting;
}

String _formatId(int value) => '0x${value.toRadixString(16).padLeft(8, '0')}';
