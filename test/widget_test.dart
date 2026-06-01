import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsons_tracker/main.dart';

void main() {
  testWidgets('App launches scan screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Connect Your Device'), findsOneWidget);
  });
}
