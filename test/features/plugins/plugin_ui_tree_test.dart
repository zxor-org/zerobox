import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/features/plugins/widgets/plugin_ui_tree.dart';

void main() {
  testWidgets('renders a centered tree with flexible rows and callbacks', (
    tester,
  ) async {
    String? callback;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PluginUITree(
            root: {
              'type': 'Column',
              'props': const <String, Object?>{},
              'children': [
                {
                  'type': 'Image',
                  'props': {
                    'data':
                        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
                        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
                    'width': 1,
                    'height': 1,
                  },
                },
                {
                  'type': 'Row',
                  'props': const <String, Object?>{},
                  'children': [
                    {
                      'type': 'Text',
                      'props': {'value': 'left'},
                    },
                    {'type': 'Spacer'},
                    {
                      'type': 'Button',
                      'props': {'text': 'run', 'onClick': 'callback-1'},
                    },
                  ],
                },
              ],
            },
            onInvoke: (id, [value]) async => callback = id,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('left'), findsOneWidget);
    await tester.tap(find.text('run'));
    expect(callback, 'callback-1');
  });
}
