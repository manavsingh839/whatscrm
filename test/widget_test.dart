import 'package:flutter_test/flutter_test.dart';
import 'package:whtsappcrm/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WaCrmApp());
    expect(find.byType(WaCrmApp), findsOneWidget);
  });
}
