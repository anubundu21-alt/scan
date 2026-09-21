import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/settings/presentation/testing_tools_screen.dart';
import 'package:scan2/features/shared/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      TestingTools.entitlementKey: true,
      TestingTools.trialUsedKey: true,
    });
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('scanella/pro'), (
          call,
        ) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('scanella/pro'), null);
  });

  test('forgetPro clears local Pro and pins the device free', () async {
    await TestingTools.forgetPro();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(TestingTools.entitlementKey), isFalse);
    expect(prefs.containsKey(TestingTools.trialUsedKey), isFalse);
    expect(prefs.getBool(ProController.testingForceFreeKey), isTrue);
    expect(prefs.getBool(ProController.testingOfferTrialKey), isTrue);
    expect(prefs.getBool(OnboardingNotifier.prefsKey), isFalse);
    expect(
      calls.map((c) => c.method),
      containsAll(['writePro', 'clearTrialUsed', 'writeTestingPins']),
    );
    final pins = calls.firstWhere((c) => c.method == 'writeTestingPins');
    expect(pins.arguments, {
      'forceFree': true,
      'offerTrial': true,
    });
  });

  test('listenToStoreAgain drops the pin', () async {
    await TestingTools.forgetPro();
    await TestingTools.listenToStoreAgain();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(ProController.testingForceFreeKey), isFalse);
    expect(prefs.containsKey(ProController.testingOfferTrialKey), isFalse);
    final pins = calls.lastWhere((c) => c.method == 'writeTestingPins');
    expect(pins.arguments, {
      'forceFree': false,
      'offerTrial': false,
    });
  });

  test('an App Store build does not compile the testing screen in', () {
    expect(TestingTools.enabled, isFalse);
  });
}
