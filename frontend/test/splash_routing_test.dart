import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail_image_network/mocktail_image_network.dart'; 
import 'package:ai_coach_app/screens/splash_screen.dart'; 

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Splash Screen Routing Tests - DIAGNOSTIC', () {
    
    testWidgets('DIAGNOSTIC: step-by-step trace', (WidgetTester tester) async {
      var tokenReaderWasCalled = false;

      await mockNetworkImages(() async {
        debugPrint('STEP 0: pumping widget...');
        await tester.pumpWidget(MaterialApp(
          home: SplashScreen(
            tokenReader: () async {
              debugPrint('STEP X: tokenReader() was actually invoked!');
              tokenReaderWasCalled = true;
              return null;
            },
          ),
        ));
        debugPrint('STEP 0 DONE. Tree after first pump: ${tester.allWidgets.map((w) => w.runtimeType).toSet()}');

        await tester.pump(const Duration(seconds: 1));
        debugPrint('STEP 1 (1s pump) DONE. tokenReaderWasCalled=$tokenReaderWasCalled');

        await tester.pump(const Duration(seconds: 1));
        debugPrint('STEP 2 (another 1s pump, total 2s) DONE. tokenReaderWasCalled=$tokenReaderWasCalled');

        await tester.pump(const Duration(milliseconds: 1));
        debugPrint('STEP 3 (tiny 1ms pump past animation end) DONE. tokenReaderWasCalled=$tokenReaderWasCalled');

        await tester.pump(Duration.zero);
        debugPrint('STEP 4 (Duration.zero flush) DONE. tokenReaderWasCalled=$tokenReaderWasCalled');

        // Try runAsync as an additional flush mechanism.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        debugPrint('STEP 5 (runAsync 10ms real delay) DONE. tokenReaderWasCalled=$tokenReaderWasCalled');

        await tester.pump(const Duration(milliseconds: 600));
        debugPrint('STEP 6 (600ms pump) DONE. tokenReaderWasCalled=$tokenReaderWasCalled');

        await tester.pump(const Duration(milliseconds: 400));
        debugPrint('STEP 7 (400ms pump) DONE. tokenReaderWasCalled=$tokenReaderWasCalled');

        await tester.pump(const Duration(seconds: 1));
        debugPrint('STEP 8 (extra 1s safety pump) DONE. tokenReaderWasCalled=$tokenReaderWasCalled');
      });

      debugPrint('FINAL: tokenReaderWasCalled=$tokenReaderWasCalled');
      debugPrint('FINAL WIDGET TREE: ${tester.allWidgets.map((w) => w.runtimeType).toSet()}');

      // Non-fatal assertions just to see how far we get - this test is
      // expected to print diagnostics; the outcome doesn't matter, the
      // debugPrint output does.
      expect(true, true);
    });
    
  });
}