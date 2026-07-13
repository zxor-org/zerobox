// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerobox/src/app/zerobox_app.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';

void main() {
  testWidgets('ZeroBox app builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();

    await tester.pumpWidget(const ProviderScope(child: ZeroBoxApp()));
    for (var attempt = 0; attempt < 4; attempt += 1) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
