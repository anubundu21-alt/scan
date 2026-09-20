import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/features/pro/data/storekit_purchase.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:scan2/features/pro/domain/pro_purchase.dart';

@immutable
class ProState {
  const ProState({
    this.isPro = false,
    this.offer,
    this.busy = false,
    this.error,
    this.storeProductsReady = false,
    this.trialUsed = false,
  });

  final bool isPro;
  final LocalizedOffer? offer;
  final bool busy;
  final String? error;
  final bool storeProductsReady;

  /// Whether this device has already taken the introductory month.
  ///
  /// Apple decides eligibility, and StoreKit does not hand that back through
  /// in_app_purchase, so this is our own record: it turns true the first time
  /// a subscription goes through here, or whenever an entitlement is found.
  /// It errs towards hiding the offer rather than promising a free month
  /// Apple will not give.
  final bool trialUsed;

  ProState copyWith({
    bool? isPro,
    LocalizedOffer? offer,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? storeProductsReady,
    bool? trialUsed,
  }) {
    return ProState(
      isPro: isPro ?? this.isPro,
      offer: offer ?? this.offer,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      storeProductsReady: storeProductsReady ?? this.storeProductsReady,
      trialUsed: trialUsed ?? this.trialUsed,
    );
  }
}

/// Entitlement + localised prices. Purchases go through [ProPurchase] so
/// tests and the simulator can run without StoreKit products.
class ProController extends StateNotifier<ProState> {
  ProController({
    ProPurchase? purchase,
    LocalizedPricing pricing = const LocalizedPricing(),
    this.locale,
  }) : _purchase = purchase ?? StoreKitPurchase(),
       _pricing = pricing,
       super(const ProState()) {
    restore();
  }

  static const _entitlementKey = 'scanella.pro.entitled';
  static const _trialUsedKey = 'scanella.pro.trial_used';

  final ProPurchase _purchase;
  final LocalizedPricing _pricing;
  final Locale? locale;

  Future<void> restore() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      var entitled = prefs.getBool(_entitlementKey) ?? false;
      var trialUsed = prefs.getBool(_trialUsedKey) ?? false;
      try {
        if (await _purchase.hasActiveEntitlement()) {
          entitled = true;
          await prefs.setBool(_entitlementKey, true);
        }
      } catch (_) {}

      LocalizedOffer? store;
      var storeReady = false;
      String? storeError;
      try {
        store = await _purchase.storeOffer();
        storeReady = store != null && store.source == 'store';
        if (!storeReady && !entitled) {
          storeError = StoreKitPurchase.missingProductsMessage;
        }
      } catch (e) {
        storeError = entitled ? null : _readable(e);
      }
      final located = await _pricing.resolve(locale: locale);
      final offer = LocalizedPricing.forDisplay(
        located: located,
        store: store,
      );

      if (entitled && !trialUsed) {
        trialUsed = true;
        await prefs.setBool(_trialUsedKey, true);
      }

      state = state.copyWith(
        isPro: entitled,
        offer: offer,
        busy: false,
        storeProductsReady: storeReady,
        error: storeError,
        trialUsed: trialUsed,
      );
    } catch (e) {
      state = state.copyWith(
        busy: false,
        error: 'Could not load Scanella Pro prices.',
      );
    }
  }

  Future<bool> subscribe(ProPlan plan) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final ok = await _purchase.buy(plan);
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_entitlementKey, true);
        await prefs.setBool(_trialUsedKey, true);
        state = state.copyWith(isPro: true, busy: false, trialUsed: true);
        return true;
      }
      state = state.copyWith(
        busy: false,
        error:
            'Purchase did not finish. Pay with the Apple ID on this iPhone, '
            'or tap Restore if you already bought Pro.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: _readable(e));
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final ok = await _purchase.restore();
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_entitlementKey, true);
        await prefs.setBool(_trialUsedKey, true);
        state = state.copyWith(isPro: true, busy: false, trialUsed: true);
        return true;
      }
      state = state.copyWith(
        busy: false,
        error: 'No Pro purchase found for this Apple ID.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(busy: false, error: _readable(e));
      return false;
    }
  }

  /// Tests and the first store-less builds unlock from SharedPreferences.
  Future<void> unlockForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementKey, true);
    state = state.copyWith(isPro: true);
  }

  /// Clears a leftover App Store error when the user picks another plan.
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  static String _readable(Object error) {
    if (error is PlatformException) {
      if (_isDuplicateProduct(error.toString()) ||
          error.code == 'storekit_duplicate_product_object') {
        return StoreKitPurchase.pendingSheetMessage;
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
    }
    var text = error.toString();
    if (_isDuplicateProduct(text)) {
      return StoreKitPurchase.pendingSheetMessage;
    }
    for (final prefix in const ['Exception: ', 'Bad state: ', 'StateError: ']) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length);
        break;
      }
    }
    return text;
  }

  static bool _isDuplicateProduct(String text) {
    return text.contains('storekit_duplicate_product_object') ||
        text.contains('pending transaction for the same product');
  }
}

final proProvider = StateNotifierProvider<ProController, ProState>((ref) {
  return ProController();
});
