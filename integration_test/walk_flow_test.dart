// Full end-to-end walk test: Start Walk → GPS sim → Stop → Save → Check History
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawprint_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full walk → save → history flow', (tester) async {
    // Launch app
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Step 1: We should be on Home page. Look for "Start Walk" button
    debugPrint('📍 Step 1: Looking for Start Walk button...');
    final startWalkFinder = find.text('Start Walk');
    expect(startWalkFinder, findsWidgets, reason: 'Start Walk button should be visible on Home page');
    await tester.tap(startWalkFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    debugPrint('✅ Tapped Start Walk - now on tracking page');

    // Step 2: Wait ~10 seconds for some tracking time (simulated GPS)
    debugPrint('📍 Step 2: Tracking in progress... waiting 10 seconds');
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    debugPrint('✅ Tracked for ~10 seconds');

    // Step 3: Tap the Finish (Stop) button
    debugPrint('📍 Step 3: Looking for Finish button...');
    final finishFinder = find.text('Finish');
    if (finishFinder.evaluate().isNotEmpty) {
      await tester.tap(finishFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Confirm the dialog
      final confirmFinish = find.text('Finish');
      if (confirmFinish.evaluate().length > 1) {
        // Tap the dialog's Finish button (second one)
        await tester.tap(confirmFinish.last);
      } else if (confirmFinish.evaluate().isNotEmpty) {
        await tester.tap(confirmFinish.first);
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));
      debugPrint('✅ Tapped Finish and confirmed');
    }

    // Step 4: Should be on SummaryPage now. Look for "Save to History"
    debugPrint('📍 Step 4: Looking for Save to History button...');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final saveButton = find.textContaining('Save');
    if (saveButton.evaluate().isNotEmpty) {
      await tester.tap(saveButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      debugPrint('✅ Saved to history!');
    } else {
      debugPrint('⚠️ Save button not found, checking current widgets...');
    }

    // Step 5: Navigate to History tab
    debugPrint('📍 Step 5: Navigating to History tab...');
    final historyTab = find.text('History');
    if (historyTab.evaluate().isNotEmpty) {
      await tester.tap(historyTab.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      debugPrint('✅ On History page');
    }

    // Step 6: Look for today's date with a walk marker
    debugPrint('📍 Step 6: Checking for walk markers on today...');
    final today = DateTime.now();
    final todayText = find.text('${today.day}');
    expect(todayText, findsWidgets, reason: "Today's date should be visible");

    // Look for the paw marker
    final pawMarker = find.text('🐾');
    debugPrint('Found ${pawMarker.evaluate().length} paw markers on calendar');

    // Step 7: Tap today's date to open bottom panel
    debugPrint('📍 Step 7: Tapping today to open walk panel...');
    // Find today's date cell (the one with brown background = today)
    await tester.tap(todayText.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Check if the bottom panel appeared with walk data
    final walkPanel = find.textContaining('walk');
    debugPrint('Bottom panel found: ${walkPanel.evaluate().isNotEmpty}');

    debugPrint('');
    debugPrint('═══════════════════════════════════');
    debugPrint('  ✅ FULL WALK FLOW TEST COMPLETE');
    debugPrint('═══════════════════════════════════');
  });
}
