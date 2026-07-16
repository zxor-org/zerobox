import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';

class InstallLocalPage extends ConsumerStatefulWidget {
  const InstallLocalPage({super.key, required this.type});

  final InstallType type;

  @override
  ConsumerState<InstallLocalPage> createState() => _InstallLocalPageState();
}

enum InstallType { app, watchface, firmware }

class _InstallLocalPageState extends ConsumerState<InstallLocalPage> {
  static final _log = getLogger('InstallLocalPage');

  late final TextEditingController _packageController;
  late final TextEditingController _watchfaceController;
  String? _fileName;
  Uint8List? _fileBytes;
  String? _packageName;
  String? _watchfaceId;
  bool _installing = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _packageController = TextEditingController();
    _watchfaceController = TextEditingController();
  }

  @override
  void dispose() {
    _packageController.dispose();
    _watchfaceController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      // Package contents are authoritative. Extensions are often renamed and
      // must not prevent a valid package from being selected.
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    String? detectedPackageName;
    String? detectedWatchfaceId;
    try {
      if (widget.type == InstallType.app) {
        detectedPackageName =
            _extractAppPackageName(bytes) ?? _guessPackageName(file.name);
      } else if (widget.type == InstallType.watchface) {
        detectedWatchfaceId =
            _extractWatchfaceId(bytes) ?? _guessWatchfaceId(file.name);
      }
    } catch (e, st) {
      _log.warning('failed to detect metadata from ${file.name}', e, st);
    }

    setState(() {
      _fileName = file.name;
      _fileBytes = bytes;
      _error = null;
      _progress = 0;
      if (widget.type == InstallType.app) {
        _packageName = detectedPackageName;
        _packageController.text = _packageName ?? '';
      } else if (widget.type == InstallType.watchface) {
        _watchfaceId = detectedWatchfaceId;
        _watchfaceController.text = _watchfaceId ?? '';
      }
    });
  }

  String _guessPackageName(String fileName) {
    final name = fileName.split('.').first;
    if (name.isEmpty) return 'com.zerobox.unknown';
    final sanitized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return 'com.zerobox.$sanitized';
  }

  String _guessWatchfaceId(String fileName) {
    return fileName.split('.').first;
  }

  String? _extractAppPackageName(Uint8List bytes) {
    if (!_looksLikeZip(bytes)) return null;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      const candidates = ['manifest.json', 'app.json'];
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.toLowerCase();
        if (!candidates.contains(name)) continue;
        final text = utf8.decode(entry.content);
        final json = jsonDecode(text) as Map<String, dynamic>;
        final pkg =
            json['package'] ?? json['packageName'] ?? json['package_name'];
        if (pkg is String && pkg.isNotEmpty) return pkg;
      }
    } catch (e, st) {
      _log.warning('failed to parse app zip manifest', e, st);
    }
    return null;
  }

  String? _extractWatchfaceId(Uint8List bytes) {
    if (_looksLikeZip(bytes)) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final entry in archive) {
          if (!entry.isFile) continue;
          if (entry.name.toLowerCase().endsWith('.json')) {
            final text = utf8.decode(entry.content);
            final json = jsonDecode(text) as Map<String, dynamic>;
            final id =
                json['id'] ?? json['watchfaceId'] ?? json['watchface_id'];
            if (id is String && _isValidWatchfaceId(id)) return id;
          }
        }
      } catch (e, st) {
        _log.warning('failed to parse watchface zip manifest', e, st);
      }
      return null;
    }

    final id = _extractWatchfaceIdFromBin(bytes);
    if (id != null && _isValidWatchfaceId(id)) return id;
    return null;
  }

  static String? _extractWatchfaceIdFromBin(Uint8List bytes) {
    const idOffset = 0x28;
    const idLength = 12;
    if (bytes.length < idOffset + idLength) return null;
    final raw = bytes.sublist(idOffset, idOffset + idLength);
    final trimmed = raw
        .takeWhile((b) => b != 0)
        .map((b) => String.fromCharCode(b))
        .join();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _isValidWatchfaceId(String id) {
    if (id.isEmpty || id.length > 12) return false;
    if (RegExp(r'^[0]+$').hasMatch(id)) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id);
  }

  bool _looksLikeZip(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  Future<void> _install() async {
    final bytes = _fileBytes;
    if (bytes == null) return;
    final manager = ref.read(deviceManagerProvider.notifier);

    setState(() {
      _installing = true;
      _error = null;
      _progress = 0;
    });

    var appSideMissing = false;
    try {
      switch (widget.type) {
        case InstallType.app:
          await manager.installApp(
            bytes,
            packageName: _packageName ?? 'com.zerobox.unknown',
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onAppSideMissing: () => appSideMissing = true,
          );
        case InstallType.watchface:
          await manager.installWatchface(
            bytes,
            watchfaceId: _watchfaceId ?? 'unknown',
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );
        case InstallType.firmware:
          await manager.installFirmware(
            bytes,
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );
      }
      if (mounted) {
        final message = appSideMissing
            ? '安装成功，但包内没有 app-side.js；设备安装已完成，伴生服务不可用。'
            : null;
        context.pop();
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _installing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = switch (widget.type) {
      InstallType.app => l10n.deviceFeaturesInstallApp,
      InstallType.watchface => l10n.deviceFeaturesInstallWatchface,
      InstallType.firmware => l10n.deviceFeaturesInstallFirmware,
    };

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(title)),
      body: PageContainer(
        padding: EdgeInsets.zero,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
          ),
          children: [
            SectionCard(
              child: InkWell(
                onTap: _installing ? null : _pickFile,
                borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        _fileBytes == null
                            ? Icons.upload_file
                            : Icons.description,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _fileName ?? l10n.installTapToSelectFile,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (_fileBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${(_fileBytes!.length / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.type == InstallType.app && _fileBytes != null) ...[
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.installPackageName,
                  border: const OutlineInputBorder(),
                ),
                controller: _packageController,
                onChanged: (value) => _packageName = value.trim(),
                enabled: !_installing,
              ),
            ],
            if (widget.type == InstallType.watchface && _fileBytes != null) ...[
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.installWatchfaceId,
                  border: const OutlineInputBorder(),
                ),
                controller: _watchfaceController,
                onChanged: (value) => _watchfaceId = value.trim(),
                enabled: !_installing,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                localizedErrorMessage(l10n, _error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_installing) ...[
              const SizedBox(height: 24),
              SmoothLinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
              ),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toStringAsFixed(0)}%'),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _fileBytes != null && !_installing ? _install : null,
              child: Text(l10n.install),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
      ),
      child: child,
    );
  }
}
