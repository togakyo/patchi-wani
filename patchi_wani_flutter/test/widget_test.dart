import 'package:flutter_test/flutter_test.dart';
import 'package:patchi_wani_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PatchiWaniApp());
    expect(find.byType(PatchiWaniApp), findsOneWidget);
  });
}
