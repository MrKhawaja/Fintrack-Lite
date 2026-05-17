import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack_lite/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FinTrackApp());
    expect(find.text('FinTrack Lite'), findsOneWidget);
  });
}
