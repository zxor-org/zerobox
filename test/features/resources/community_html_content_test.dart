import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/features/resources/widgets/community_html_content.dart';

void main() {
  testWidgets('renders supported HTML and ignores executable elements', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityHtmlContent(
            html:
                '<p>Hello <strong>ZeroBox</strong></p><blockquote>Quote</blockquote><script>bad()</script>',
          ),
        ),
      ),
    );

    expect(find.textContaining('Hello'), findsOneWidget);
    expect(find.text('Quote'), findsOneWidget);
    expect(find.textContaining('bad()'), findsNothing);
  });
}
