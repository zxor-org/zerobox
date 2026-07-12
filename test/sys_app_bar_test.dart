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

  testWidgets('narrow macOS content uses the reduced window-control inset', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await _pumpAppBar(tester, width: 600);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 84);
      expect(appBar.automaticallyImplyLeading, isFalse);
      final leading = appBar.leading! as Row;
      expect((leading.children.first as SizedBox).width, 36);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _pumpAppBar(WidgetTester tester, {required double width}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: const Scaffold(appBar: SysAppBar(title: Text('Title'))),
      ),
    ),
  );
}
