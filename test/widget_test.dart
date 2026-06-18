import 'package:flutter_test/flutter_test.dart';
import 'package:zournia_mobile/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ZourniaOS());
    await tester.pumpAndSettle();
    expect(find.byType(ZourniaOS), findsOneWidget);
  });
}
