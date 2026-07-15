import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/features/devices/services/zeppos_app_settings_service.dart';

Future<void> showZeppOsAppSettings(
  BuildContext context, {
  required int appId,
  required String title,
}) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            ZeppOsSettingViewerPage(appId: appId, title: title),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    return;
  }
  await ZeppOsAppSettingsService.instance.open(appId, title: title);
}

class ZeppOsSettingViewerPage extends StatefulWidget {
  const ZeppOsSettingViewerPage({
    required this.appId,
    required this.title,
    super.key,
  });

  final int appId;
  final String title;

  @override
  State<ZeppOsSettingViewerPage> createState() =>
      _ZeppOsSettingViewerPageState();
}

class _ZeppOsSettingViewerPageState extends State<ZeppOsSettingViewerPage> {
  Object? _error;
  bool _opened = false;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    final contentTop = MediaQuery.paddingOf(context).top + kToolbarHeight;
    try {
      await ZeppOsAppSettingsService.instance.open(
        widget.appId,
        title: widget.title,
        contentTop: contentTop,
      );
      if (!mounted) {
        await ZeppOsAppSettingsService.instance.close(widget.appId);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    if (_opened && !_closing) {
      unawaited(ZeppOsAppSettingsService.instance.close(widget.appId));
    }
    super.dispose();
  }

  Future<bool> _onWillPop() {
    if (!_closing) {
      _closing = true;
      unawaited(ZeppOsAppSettingsService.instance.close(widget.appId));
    }
    return SynchronousFuture(true);
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
    onWillPop: _onWillPop,
    child: Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(widget.title)),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text('设置页面加载失败：$_error'),
              ),
      ),
    ),
  );
}
