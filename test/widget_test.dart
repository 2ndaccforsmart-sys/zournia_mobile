import 'package:flutter_test/flutter_test.dart';

import 'package:zournia_pc/main.dart';

void main() {
  testWidgets('Shell layout and navigation test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ZourniaOS());

    // Verify that navigation label exists in the sidebar.
    expect(find.text('NAVIGATION'), findsOneWidget);

    // Verify that settings button/tab is present.
    expect(find.text('Settings'), findsOneWidget);
  });
}

