import 'package:scan2/features/pro/domain/localized_pricing.dart';

enum ProPlan { monthly, yearly }

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

  Future<bool> buy(ProPlan plan);
  Future<bool> restore();
  Future<LocalizedOffer?> storeOffer();
}

/// In-memory purchase used by widget tests.
class FakeProPurchase implements ProPurchase {
  FakeProPurchase({
    this.entitled = false,
    this.offer,
    this.trialUsed = false,
    this.introOffer,
  });

  bool entitled;
  bool trialUsed;

  /// What the store says about the introductory month; null for "no answer".
  bool? introOffer;
  final LocalizedOffer? offer;

  @override
  Future<bool?> hasActiveEntitlement() async => entitled;

  @override
  Future<bool> trialConsumed() async => trialUsed;

  @override
  Future<void> markTrialConsumed() async => trialUsed = true;

  @override
  Future<bool?> introOfferAvailable() async => introOffer;

  @override
  Future<bool> buy(ProPlan plan) async {
    entitled = true;
    trialUsed = true;
    return true;
  }

  @override
  Future<bool> restore() async => entitled;

  @override
  Future<LocalizedOffer?> storeOffer() async => offer;
}
