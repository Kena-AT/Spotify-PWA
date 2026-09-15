import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pwa/screens/widgets/keyboard_shortcuts_dialog.dart';
import 'package:spotify_pwa/screens/widgets/sleep_timer_modal.dart';
import 'package:spotify_pwa/screens/widgets/equalizer_modal.dart';
import 'package:spotify_pwa/services/equalizer_service.dart';
import 'package:spotify_pwa/services/sleep_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('KeyboardShortcutsDialog renders all key shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: KeyboardShortcutsDialog())),
    );

    // Dialog starts in phone mode — verify phone header and mode tabs are present
    expect(find.text('Phone Shortcuts & Gestures'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('PC / Desktop'), findsOneWidget);

    // Switch to PC mode and verify PC shortcuts are shown
    await tester.tap(find.text('PC / Desktop'));
    // Pump past the reverse animation (200ms) and the forward animation (200ms)
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('PC / Desktop Shortcuts'), findsOneWidget);
    expect(find.text('Play / Pause'), findsOneWidget);
    expect(find.text('Next track'), findsOneWidget);
    expect(find.text('Previous track'), findsOneWidget);
    expect(find.text('Space'), findsOneWidget);
  });

  testWidgets('SleepTimerModal renders options and allows selecting timer', (
    tester,
  ) async {
    final timerService = SleepTimerService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SleepTimerModal(sleepTimerService: timerService)),
      ),
    );

    expect(find.text('Sleep Timer'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('End of Track'), findsOneWidget);

    // Tap on '15 min'
    await tester.tap(find.text('15 min'));
    await tester.pump();

    expect(timerService.state.isActive, isTrue);
    expect(timerService.state.formattedRemaining, '15:00');
    expect(find.text('Turn Off'), findsOneWidget);

    timerService.dispose();
  });

  testWidgets('EqualizerModal renders equalizer title, switch, and presets', (
    tester,
  ) async {
    final eqService = EqualizerService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EqualizerModal(equalizerService: eqService)),
      ),
    );

    expect(find.text('Equalizer'), findsOneWidget);
    expect(find.text('Bass Boost'), findsWidgets);
    expect(find.text('Flat'), findsOneWidget);

    eqService.dispose();
  });
}
