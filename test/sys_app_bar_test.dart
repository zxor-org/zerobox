import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/utils/layout.dart';

void main() {
  test('global wide layout switches at the shared 840px breakpoint', () {
    expect(useWideLayout(839.9), isFalse);
    expect(useWideLayout(840), isTrue);
  });

  testWidgets('wide macOS content does not avoid window controls', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await _pumpAppBar(tester, width: 1200);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, isNull);
      expect(appBar.automaticallyImplyLeading, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('narrow macOS primary content keeps the leading area empty', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await _pumpAppBar(tester, width: 600);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, 72);
      expect(appBar.leadingWidth, isNull);
      expect(appBar.automaticallyImplyLeading, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('narrow macOS secondary content positions its back button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await _pumpAppBar(tester, width: 600, secondary: true);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, 72);
      expect(appBar.leadingWidth, 68);
      expect(appBar.automaticallyImplyLeading, isFalse);
      final leading = appBar.leading! as Padding;
      expect(leading.padding, const EdgeInsets.only(left: 12, top: 20));
      expect(leading.child, isA<BackButton>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _pumpAppBar(
  WidgetTester tester, {
  required double width,
  bool secondary = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Scaffold(
          appBar: SysAppBar(
            secondary: secondary,
            title: const Text('Title'),
            leading: secondary ? const BackButton() : null,
          ),
        ),
      ),
    ),
  );
}
