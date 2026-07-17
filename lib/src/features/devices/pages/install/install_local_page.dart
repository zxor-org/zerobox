import 'dart:typed_data';

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
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';
import 'package:zerobox/src/features/resources/widgets/resource_install_confirmation.dart';

class InstallLocalPage extends ConsumerStatefulWidget {
  const InstallLocalPage({super.key, required this.type});

  final InstallType type;

  @override
  ConsumerState<InstallLocalPage> createState() => _InstallLocalPageState();
}

enum InstallType { app, watchface, firmware }

class _InstallLocalPageState extends ConsumerState<InstallLocalPage> {
  String? _fileName;
  Uint8List? _fileBytes;
  bool _installing = false;
  double _progress = 0;
  String? _error;

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

    setState(() {
      _fileName = file.name;
      _fileBytes = bytes;
      _error = null;
      _progress = 0;
    });
    await _confirmAndEnqueue();
  }

  LocalDeviceInstallType get _selectedType => switch (widget.type) {
    InstallType.app => LocalDeviceInstallType.app,
    InstallType.watchface => LocalDeviceInstallType.watchface,
    InstallType.firmware => LocalDeviceInstallType.firmware,
  };

  Future<void> _install() async {
    final bytes = _fileBytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null) return;
    try {
      setState(() => _installing = true);
      final enqueued = await confirmAndEnqueueResourceFile(
        context: context,
        ref: ref,
        selectedType: _selectedType,
        fileName: fileName,
        bytes: bytes,
      );
      if (!mounted) return;
      if (enqueued) {
        context.pop();
      } else {
        setState(() => _installing = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _installing = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _confirmAndEnqueue() => _install();

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
