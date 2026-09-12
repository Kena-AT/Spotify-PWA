import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pwa/main.dart';

void main() {
  testWidgets('SpotifyPWAApp launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SpotifyPWAApp());
    expect(find.byType(SpotifyPWAApp), findsOneWidget);
  });
}
