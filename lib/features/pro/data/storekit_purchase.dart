import 'dart:async';

import 'package:scan2/features/pro/data/iap_gateway.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_purchase.dart';

/// Buys Scanella Pro through the App Store (and Play Billing on Android).
///
/// Apple does not allow a Stripe card form — or a custom Apple Pay sheet —
/// for digital features inside the iOS app. Payment methods (card, Apple Pay,
/// carrier) are whatever is on the customer's Apple ID.
class StoreKitPurchase implements ProPurchase {
  StoreKitPurchase({IapGateway? gateway})
    : _gateway = gateway ?? PluginIapGateway.shared();

  final IapGateway _gateway;

  /// Shown when StoreKit returns no products. Reinstalling TestFlight does
  /// not help — Apple is not listing the subscriptions for this app yet.
  ///
  /// Sandbox/TestFlight can charge before App Review if the products are
  /// Ready to Submit (localization + price) and the Paid Apps Agreement is
  /// Active. The first subscription group still has to be attached to a new
  /// app version before customers can buy.
  static const missingProductsMessage =
      'The App Store has not listed Scanella Pro for this Apple ID yet. '
      'Reinstalling TestFlight will not fix this. In App Store Connect, '
      'open Subscriptions → Scanella Pro and add a localization (display '
      'name) for the group and for ${ProProducts.monthly} and '
      '${ProProducts.yearly}, then wait until both are Ready to Submit. '
      'Confirm Business → Agreements, Tax, and Banking shows an Active '
      'Paid Apps Agreement. Version 1.0 is already approved, so attach '
      'the subscriptions to a new version before customers can buy.';

  static const _storeUnavailable =
      'The App Store is not available on this device.';

  @override
  Future<bool> hasActiveEntitlement() async {
    // Do not call restore() here — that can ask for the Apple ID every
    // time the paywall opens. The Restore button is the path after a
    // reinstall.
    return false;
  }

  @override
  Future<bool> buy(ProPlan plan) async {
    if (!await _gateway.isAvailable()) {
      throw StateError(_storeUnavailable);
    }
    final id = plan == ProPlan.monthly
        ? ProProducts.monthly
        : ProProducts.yearly;
    final products = await _gateway.queryProducts({id});
    if (products.isEmpty) {
      throw StateError(missingProductsMessage);
    }
    final product = products.first;
    final result = await _waitForResult(
      start: () async {
        await _submitBuy(product);
      },
    );
    return result == true;
  }

  Future<void> _submitBuy(StoreProduct product) async {
    try {
      final submitted = await _gateway.buy(product);
      if (!submitted) {
        throw StateError('Could not start the App Store purchase.');
      }
    } catch (error) {
      if (!_isDuplicateProduct(error)) rethrow;
      final submitted = await _gateway.buy(product);
      if (!submitted) {
        throw StateError('Could not start the App Store purchase.');
      }
    }
  }

  @override
  Future<bool> restore() async {
    if (!await _gateway.isAvailable()) return false;
    final found = await _waitForResult(
      start: _gateway.restore,
      timeout: const Duration(seconds: 12),
      treatEmptyAsFalse: true,
    );
    return found == true;
  }

  @override
  Future<LocalizedOffer?> storeOffer() async {
    if (!await _gateway.isAvailable()) return null;
    final products = await _gateway.queryProducts({
      ProProducts.monthly,
      ProProducts.yearly,
    });
    StoreProduct? monthly;
    StoreProduct? yearly;
    for (final item in products) {
      if (item.id == ProProducts.monthly) monthly = item;
      if (item.id == ProProducts.yearly) yearly = item;
    }
    if (monthly == null || yearly == null) return null;
    return LocalizedOffer(
      currencyCode: yearly.currencyCode.isEmpty
          ? monthly.currencyCode
          : yearly.currencyCode,
      countryCode: '',
      countryName: '',
      monthly: monthly.rawPrice,
      yearly: yearly.rawPrice,
      monthlyLabel: monthly.price,
      yearlyLabel: yearly.price,
      source: 'store',
    );
  }

  Future<bool?> _waitForResult({
    required Future<void> Function() start,
    Duration timeout = const Duration(minutes: 2),
    bool treatEmptyAsFalse = false,
  }) async {
    final done = Completer<bool?>();
    final sub = _gateway.purchases.listen(
      (events) async {
        for (final event in events) {
          if (event.status == IapStatus.pending) continue;
          try {
            await event.complete?.call();
          } catch (_) {}
          if (done.isCompleted) continue;
          if (event.status == IapStatus.purchased ||
              event.status == IapStatus.restored) {
            done.complete(true);
          } else if (event.status == IapStatus.canceled) {
            done.complete(false);
          } else if (event.status == IapStatus.error) {
            done.completeError(
              StateError(event.error ?? 'The App Store could not finish.'),
            );
          }
        }
      },
      onError: (Object error) {
        if (!done.isCompleted) done.completeError(error);
      },
    );
    try {
      await start();
      return await done.future.timeout(
        timeout,
        onTimeout: () => treatEmptyAsFalse ? false : null,
      );
    } finally {
      await sub.cancel();
    }
  }

  static bool _isDuplicateProduct(Object error) {
    final text = error.toString();
    return text.contains('storekit_duplicate_product_object') ||
        text.contains('pending transaction for the same product');
  }

  static const pendingSheetMessage =
      'The App Store is still finishing the last payment sheet. '
      'Dismiss it, wait a moment, then try again.';
}
