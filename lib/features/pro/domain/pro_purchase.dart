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
  Future<bool> buy(ProPlan plan);
  Future<bool> restore();
  Future<LocalizedOffer?> storeOffer();
}

/// In-memory purchase used by widget tests.
class FakeProPurchase implements ProPurchase {
  FakeProPurchase({this.entitled = false, this.offer});

  bool entitled;
  final LocalizedOffer? offer;

  @override
  Future<bool?> hasActiveEntitlement() async => entitled;

  @override
  Future<bool> buy(ProPlan plan) async {
    entitled = true;
    return true;
  }

  @override
  Future<bool> restore() async => entitled;

  @override
  Future<LocalizedOffer?> storeOffer() async => offer;
}
