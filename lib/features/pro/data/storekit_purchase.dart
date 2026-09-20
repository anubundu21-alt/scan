import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:scan2/features/pro/data/iap_gateway.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_purchase.dart';

/// Buys Scanella Pro through the App Store (and Play Billing on Android).
///
/// Apple does not allow a Stripe card form — or a custom Apple Pay sheet —
/// for digital features inside the iOS app. Payment methods (card, Apple Pay,
/// carrier) are whatever is on the customer's Apple ID.
class StoreKitPurchase implements ProPurchase {
  StoreKitPurchase({IapGateway? gateway, MethodChannel? channel})
    : _gateway = gateway ?? PluginIapGateway.shared(),
      _channel = channel ?? const MethodChannel('scanella/pro') {
    _watchRenewals();
  }

  final IapGateway _gateway;

  StreamSubscription<List<IapEvent>>? _renewals;

  /// True while [buy] or [restore] is waiting on the store. Those two stamp
  /// their own end date — [buy] is the only place that knows the purchase is
  /// an introductory month rather than a full period — so the passive
  /// watcher must keep its hands off until they are done.
  bool _inFlight = false;

  /// Renewals arrive on the payment queue on their own, without anyone
  /// asking. Below iOS 15 that is the only notice a subscription is still
  /// running, so each one pushes the cached end date forward and a paying
  /// customer is never dropped to the free plan mid-subscription.
  void _watchRenewals() {
    try {
      _renewals = _gateway.purchases.listen((events) async {
        if (_inFlight) return;
        for (final event in events) {
          if (!ProProducts.all.contains(event.productId)) continue;
          if (event.status != IapStatus.purchased &&
              event.status != IapStatus.restored) {
            continue;
          }
          // No date means no stamp, and an unstamped yes is the very thing
          // that kept cancelled trials on Pro for good. Leave it alone.
          final until = _expiryFrom(event);
          if (until == null || until.isBefore(DateTime.now())) continue;
          final at = event.transactionDate;
          final basis = await _cachedBasis();
          // Only a transaction newer than the one already stamped is a
          // renewal; anything else is the queue replaying old history.
          if (at != null && basis != null && !at.isAfter(basis)) continue;
          await cacheEntitlement(entitled: true, until: until, basis: at);
        }
      }, onError: (Object _) {});
    } catch (_) {}
  }

  /// Only tests take this apart; the app keeps one for its whole life.
  Future<void> dispose() async {
    await _renewals?.cancel();
    _renewals = null;
  }

  /// Native side of the entitlement check and its Keychain copy.
  final MethodChannel _channel;

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

  /// Whether this Apple ID or Google account is subscribed right now.
  ///
  /// Silent on both platforms — nothing here shows a password prompt, so it
  /// is safe to call on launch. StoreKit 2 answers on iOS 15 and above and
  /// reports a cancelled or refunded subscription as gone; Play Billing's
  /// query does the same on Android.
  ///
  /// Older iOS has no silent API, so it falls back to the Keychain copy,
  /// which survives an uninstall. That copy carries the date the paid-up
  /// period ends, written when the purchase was made and pushed forward by
  /// every renewal the store delivers, so a cancelled subscription lapses on
  /// its own rather than granting Pro for good. Restore still corrects us
  /// if we drop someone too early.
  @override
  Future<bool?> hasActiveEntitlement() async {
    if (Platform.isAndroid) {
      // queryPurchases on Android does not prompt, unlike iOS restore.
      try {
        final live = await restore();
        await cacheEntitlement(entitled: live);
        return live;
      } catch (_) {
        return null;
      }
    }
    try {
      final live = await _channel.invokeMethod<bool>('currentEntitlement');
      if (live != null) {
        await cacheEntitlement(entitled: live);
        if (live) await markTrialConsumed();
        return live;
      }
    } catch (_) {}
    // Older iOS has no silent API. The Keychain copy outlives an uninstall,
    // so a subscriber who reinstalls keeps Pro, and the end date stamped
    // alongside it means a cancelled subscription stops counting once its
    // paid-up period runs out instead of lasting forever.
    return _cachedEntitlement();
  }

  /// Whether the introductory month has already been taken.
  ///
  /// On iOS the native side reads StoreKit's purchase history, which knows
  /// about a trial that was started and then cancelled, and survives an
  /// uninstall.
  ///
  /// Android has no equivalent here, and Play decides intro-offer
  /// eligibility itself when it shows the sheet, so this answers no and
  /// leaves [ProController] to fall back on its own saved record.
  @override
  Future<bool> trialConsumed() async {
    if (Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('trialConsumed') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markTrialConsumed() async {
    try {
      await _channel.invokeMethod<void>('markTrialUsed');
    } catch (_) {}
  }

  /// How long one paid period runs, with a day's slack for a late renewal.
  static Duration periodFor(ProPlan plan) {
    return plan == ProPlan.monthly
        ? const Duration(days: 31)
        : const Duration(days: 366);
  }

  /// The introductory offer configured in App Store Connect: one month,
  /// whichever plan carries it.
  static const introPeriod = Duration(days: 31);

  /// Apple keeps serving a subscription while it retries a failed payment,
  /// so the stamp is deliberately generous. Being a few days late to notice
  /// a lapse is cheaper than locking out someone who is paying.
  static const gracePeriod = Duration(days: 3);

  static ProPlan planOf(String productId) {
    return productId == ProProducts.monthly ? ProPlan.monthly : ProPlan.yearly;
  }

  /// Keeps the Keychain copy in step, so the next launch paints the right
  /// thing before the store has answered.
  ///
  /// [until] is when this answer stops being worth trusting. Below iOS 15
  /// nothing can silently notice a cancellation, and the Keychain outlives
  /// an uninstall, so a yes with no end date would keep a lapsed trial on
  /// Pro for good. Passing null leaves any date already stored alone.
  Future<void> cacheEntitlement({
    required bool entitled,
    DateTime? until,
    DateTime? basis,
  }) async {
    try {
      await _channel.invokeMethod<void>('writePro', <String, Object?>{
        'entitled': entitled,
        'untilMs': until?.millisecondsSinceEpoch,
        'basisMs': basis?.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// The transaction the stored end date was worked out from.
  ///
  /// A restore replays the whole history, so without this there is no way to
  /// tell a genuine renewal from the same old transaction coming round
  /// again — and mistaking one for the other is what would hand a cancelled
  /// yearly trial another year of Pro.
  Future<DateTime?> _cachedBasis() async {
    try {
      final stamp = await _channel.invokeMapMethod<String, Object?>(
        'readProStamp',
      );
      final ms = (stamp?['basisMs'] as num?)?.toInt();
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _cachedEntitlement() async {
    try {
      return await _channel.invokeMethod<bool>('readPro') ?? false;
    } catch (_) {
      return false;
    }
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
    // Asked before the sheet opens: if Apple still owes the introductory
    // month, this purchase buys one month, not a whole plan period.
    final hadTrialAlready = await trialConsumed();
    IapEvent? event;
    _inFlight = true;
    try {
      event = await _waitForEvent(
        start: () async {
          await _submitBuy(product);
        },
      );
    } finally {
      _inFlight = false;
    }
    final bought =
        event != null &&
        (event.status == IapStatus.purchased ||
            event.status == IapStatus.restored);
    if (bought) {
      final period = hadTrialAlready ? periodFor(plan) : introPeriod;
      final now = DateTime.now();
      await cacheEntitlement(
        entitled: true,
        until: now.add(period + gracePeriod),
        basis: event.transactionDate ?? now,
      );
      await markTrialConsumed();
    }
    return bought;
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
    IapEvent? event;
    _inFlight = true;
    try {
      event = await _waitForEvent(
        start: _gateway.restore,
        timeout: const Duration(seconds: 12),
      );
    } finally {
      _inFlight = false;
    }
    if (event == null) return false;
    if (event.status != IapStatus.purchased &&
        event.status != IapStatus.restored) {
      return false;
    }
    // A restore hands back lapsed subscriptions too, so finding a
    // transaction is not the same as being subscribed.
    final at = event.transactionDate;
    final basis = await _cachedBasis();
    if (at != null && basis != null && !at.isAfter(basis)) {
      // Nothing new: this is the transaction the stored end date already
      // came from. A purchase knows whether it bought an introductory month
      // or a full period and a replay does not, so the stored date stands.
      await markTrialConsumed();
      return _cachedEntitlement();
    }
    // When the store says when it last billed, a date older than a whole
    // period means this is the wreckage of a cancelled plan, not a live one.
    final until = _expiryFrom(event);
    if (until != null && until.isBefore(DateTime.now())) {
      await markTrialConsumed();
      return false;
    }
    // Only ever write a yes here. A restore that finds nothing may simply
    // have been signed into the wrong Apple ID, and that must not wipe a
    // subscription this device already knows about.
    await cacheEntitlement(entitled: true, until: until, basis: at);
    await markTrialConsumed();
    return true;
  }

  /// When a restored transaction's period runs out, as far as we can tell.
  ///
  /// Null when the store gave no date; there the old behaviour stands and
  /// the yes carries no end date.
  static DateTime? _expiryFrom(IapEvent event) {
    final at = event.transactionDate;
    if (at == null) return null;
    return at.add(periodFor(planOf(event.productId)) + gracePeriod);
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

  /// Waits for the store to settle and hands back the event that decided it.
  ///
  /// A restore arrives as a batch covering the whole history of the
  /// subscription, so the newest transaction in it wins: that is the last
  /// time the store billed. Null means nothing arrived before the timeout.
  Future<IapEvent?> _waitForEvent({
    required Future<void> Function() start,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final done = Completer<IapEvent?>();
    final sub = _gateway.purchases.listen(
      (events) async {
        IapEvent? best;
        for (final event in events) {
          if (event.status == IapStatus.pending) continue;
          try {
            await event.complete?.call();
          } catch (_) {}
          if (done.isCompleted) continue;
          if (event.status == IapStatus.error) {
            done.completeError(
              StateError(event.error ?? 'The App Store could not finish.'),
            );
            return;
          }
          if (event.status == IapStatus.canceled) {
            best ??= event;
            continue;
          }
          if (best == null || _isNewer(event, best)) best = event;
        }
        if (best != null && !done.isCompleted) done.complete(best);
      },
      onError: (Object error) {
        if (!done.isCompleted) done.completeError(error);
      },
    );
    try {
      await start();
      return await done.future.timeout(timeout, onTimeout: () => null);
    } finally {
      await sub.cancel();
    }
  }

  /// A real purchase beats a cancellation, and the later date beats the
  /// earlier one.
  static bool _isNewer(IapEvent event, IapEvent best) {
    if (best.status == IapStatus.canceled) return true;
    final at = event.transactionDate;
    final other = best.transactionDate;
    if (at == null) return false;
    if (other == null) return true;
    return at.isAfter(other);
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
