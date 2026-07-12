import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/features/settings/pages/about_software_page.dart';

void main() {
  testWidgets('log disclosure confirmation is locked for five seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutSoftwarePage(),
      ),
    );
    await tester.pump();

    final openLogs = find.text('打开日志文件夹');
    await tester.ensureVisible(openLogs);
    await tester.pumpAndSettle();
    await tester.tap(openLogs);
    await tester.pump();

    final initialConfirm = find.widgetWithText(TextButton, '我知道了(5s)');
    expect(initialConfirm, findsOneWidget);
    expect(tester.widget<TextButton>(initialConfirm).onPressed, isNull);

    final cancel = find.widgetWithText(TextButton, '取消');
    expect(cancel, findsOneWidget);
    expect(tester.widget<TextButton>(cancel).onPressed, isNotNull);

    await tester.pump(const Duration(seconds: 4));
    final finalCountdown = find.widgetWithText(TextButton, '我知道了(1s)');
    expect(finalCountdown, findsOneWidget);
    expect(tester.widget<TextButton>(finalCountdown).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    final enabledConfirm = find.widgetWithText(TextButton, '我知道了');
    expect(enabledConfirm, findsOneWidget);
    expect(tester.widget<TextButton>(enabledConfirm).onPressed, isNotNull);

    await tester.tap(cancel);
    await tester.pump();
  });
}
