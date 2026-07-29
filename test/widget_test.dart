import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_gps_pro/main.dart';

void main() {
  testWidgets('Fake GPS PRO app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FakeGPSProApp()));

    expect(find.text('Fake GPS PRO'), findsOneWidget);
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);
  });
}
