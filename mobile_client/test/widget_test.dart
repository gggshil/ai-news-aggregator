import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/main.dart';

void main() {
  testWidgets('App renders auth screen properly', (WidgetTester tester) async {
    await tester.pumpWidget(const AiNewsApp());
    expect(find.text('AI News Aggregator'), findsOneWidget);
    expect(find.text('Gmail Address'), findsOneWidget);
  });
}
