import 'package:scan2/features/pro/domain/localized_pricing.dart';

enum ProPlan { monthly, yearly }

/// Whether Apple would grant the introductory month on each plan.
class IntroEligibility {
  const IntroEligibility({this.monthly, this.yearly});

  final bool? monthly;
  final bool? yearly;

  bool? forPlan(ProPlan plan) =>
      plan == ProPlan.monthly ? monthly : yearly;
}

/// Product identifiers to create in App Store Connect / Play Console.
class ProProducts {
  static const monthly = 'scanella_pro_monthly';
  static const yearly = 'scanella_pro_yearly';
  static const all = {monthly, yearly};
}

/// Buys and restores Scanella Pro.
abstract class ProPurchase {
  /// True subscribed, false not, null when the store could not be reached.
  ///
  /// The difference matters: a null must leave the saved answer alone, or a
  /// dropped connection would take Pro away from someone who is paying.
  Future<bool?> hasActiveEntitlement();

  /// Whether the introductory month has already been taken on this device.
  ///
  /// Apple grants it once per subscription group and will not say so through
  /// in_app_purchase, so this reads the store's own purchase history where it
  /// can and a device record where it cannot. False only ever means "no sign
  /// of one", so it errs towards offering the month rather than hiding it.
  Future<bool> trialConsumed();

  /// Records that the month has been taken, somewhere an uninstall cannot
  /// reach.
  Future<void> markTrialConsumed();

  /// Whether the store would actually grant the introductory month now.
  ///
  /// True only when an introductory offer exists AND this account is still
  /// owed one, so it is false both for someone who has already taken the
  /// month and when no offer is configured at all. Null when the store
  /// could not answer, and the app falls back to its own record.
  Future<bool?> introOfferAvailable();

  /// Per-plan answer for [introOfferAvailable].
  Future<IntroEligibility> introEligibility() async {
    final any = await introOfferAvailable();
    return IntroEligibility(monthly: any, yearly: any);
  }

  Future<bool> buy(ProPlan plan);
  Future<bool> restore();
  Future<LocalizedOffer?> storeOffer();

  /// Testing tools only. Survives an uninstall because it lives in Keychain.
  Future<({bool forceFree, bool offerTrial, bool useStore})>
      readTestingPins() async =>
          (forceFree: false, offerTrial: false, useStore: false);

  Future<void> writeTestingPins({
    bool forceFree = false,
    bool offerTrial = false,
    bool useStore = false,
  }) async {}

  /// App-granted Pro window. Survives an uninstall because it lives natively.
  Future<({bool used, DateTime? until})> readCourtesyTrial() async =>
      (used: false, until: null);

  Future<void> startCourtesyTrial({required DateTime until}) async {}
}

/// In-memory purchase used by widget tests.
class FakeProPurchase extends ProPurchase {
  FakeProPurchase({
    this.entitled = false,
    this.offer,
    this.trialUsed = false,
    this.introOffer,
    this.testingForceFree = false,
    this.testingOfferTrial = false,
    this.testingUseStore = false,
    this.courtesyUsed = false,
    this.courtesyUntil,
  });

  bool entitled;
  bool trialUsed;
  int entitlementChecks = 0;
  int buyCalls = 0;
  int courtesyStarts = 0;
  bool courtesyUsed;
  DateTime? courtesyUntil;

  /// What the store says about the introductory month; null for "no answer".
  bool? introOffer;
  bool testingForceFree;
  bool testingOfferTrial;
  bool testingUseStore;
  final LocalizedOffer? offer;

  @override
  Future<bool?> hasActiveEntitlement() async {
    entitlementChecks += 1;
    return entitled;
  }

  @override
  Future<bool> trialConsumed() async => trialUsed;

  @override
  Future<void> markTrialConsumed() async => trialUsed = true;

  @override
  Future<bool?> introOfferAvailable() async => introOffer;

  @override
  Future<IntroEligibility> introEligibility() async =>
      IntroEligibility(monthly: introOffer, yearly: introOffer);

  @override
  Future<bool> buy(ProPlan plan) async {
    buyCalls += 1;
    entitled = true;
    trialUsed = true;
    testingForceFree = false;
    testingOfferTrial = false;
    testingUseStore = true;
    return true;
  }

  @override
  Future<bool> restore() async => entitled;

  @override
  Future<LocalizedOffer?> storeOffer() async => offer;

  @override
  Future<({bool forceFree, bool offerTrial, bool useStore})>
      readTestingPins() async => (
            forceFree: testingForceFree,
            offerTrial: testingOfferTrial,
            useStore: testingUseStore,
          );

  @override
  Future<void> writeTestingPins({
    bool forceFree = false,
    bool offerTrial = false,
    bool useStore = false,
  }) async {
    testingForceFree = forceFree;
    testingOfferTrial = offerTrial;
    testingUseStore = useStore;
  }

  @override
  Future<({bool used, DateTime? until})> readCourtesyTrial() async =>
      (used: courtesyUsed, until: courtesyUntil);

  @override
  Future<void> startCourtesyTrial({required DateTime until}) async {
    courtesyStarts += 1;
    courtesyUsed = true;
    courtesyUntil = until;
  }
}
