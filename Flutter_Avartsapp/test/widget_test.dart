// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:avarts/main.dart';

void main() {
  setUpAll(() async {
    // Load a minimal .env for testing
    await dotenv.load(fileName: '.env', mergeWith: {'BASE_URL': 'http://localhost:3000'});
  });

  testWidgets('App loads login page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AvartsApp());
    await tester.pumpAndSettle();

    // Verify that login page is shown
    expect(find.text('Welcome back, slacker'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
