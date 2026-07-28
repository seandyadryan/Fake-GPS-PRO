import 'package:flutter_test/flutter_test.dart';
import 'package:fake_gps_pro/main.dart';

void main() {
  testWidgets('Fake GPS PRO app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FakeGPSProApp());

    expect(find.text('Fake GPS PRO'), findsOneWidget);
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);
    expect(find.text('Set'), findsOneWidget);
    expect(find.text('Spoof'), findsOneWidget);
  });
}
