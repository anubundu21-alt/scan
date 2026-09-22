import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/features/pro/data/storekit_purchase.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:scan2/features/pro/domain/pro_purchase.dart';

/// App-granted Pro, separate from Apple's introductory month.
class ProTrial {
  static const courtesyDays = 7;
  static const courtesy = Duration(days: courtesyDays);

  static String get freeTitle => '$courtesyDays days FREE';
  static String get startButton => 'Start $courtesyDays-day free trial';
}

@immutable
class ProState {
  const ProState({
    this.isPro = false,
    this.offer,
    this.busy = false,
    this.error,
    this.storeProductsReady = false,
    this.trialUsed = false,
    this.canStartTrial = false,
    this.canStartCourtesyTrial = false,
    this.testingBuild = false,
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

  /// Whether to offer the introductory month.
  ///
  /// The store's answer where there is one, because only it knows both
  /// whether an offer is configured and whether this account is still owed
  /// it. [trialUsed] is the fallback. False means the plain plan price is
  /// what gets shown — never a free month the customer would be billed for
  /// on the spot. A TestFlight testing build paints the first-time layout
  /// anyway, so the screens can be walked on an Apple ID that already used
  /// the real month.
  final bool canStartTrial;

  /// Compiled in only for TestFlight testing tools. Lets onboarding still
  /// show the upgrade screen so a tester can see it.
  final bool testingBuild;

  /// Whether this device may still start the app-granted 7-day Pro window.
  ///
  /// This is the trial the app can start without Apple. It is offered when
  /// this Apple ID is not owed the introductory month, and only once.
  final bool canStartCourtesyTrial;

  ProState copyWith({
    bool? isPro,
    LocalizedOffer? offer,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? storeProductsReady,
    bool? trialUsed,
    bool? canStartTrial,
    bool? canStartCourtesyTrial,
    bool? testingBuild,
  }) {
    return ProState(
      isPro: isPro ?? this.isPro,
      offer: offer ?? this.offer,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      storeProductsReady: storeProductsReady ?? this.storeProductsReady,
      trialUsed: trialUsed ?? this.trialUsed,
      canStartTrial: canStartTrial ?? this.canStartTrial,
      canStartCourtesyTrial:
          canStartCourtesyTrial ?? this.canStartCourtesyTrial,
      testingBuild: testingBuild ?? this.testingBuild,
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
    bool testingTools = const bool.fromEnvironment('SCANELLA_TESTING'),
    DateTime Function()? clock,
  }) : _purchase = purchase ?? StoreKitPurchase(),
       _pricing = pricing,
       _testingTools = testingTools,
       _now = clock ?? DateTime.now,
       super(const ProState()) {
    restore();
  }

  static const _entitlementKey = 'scanella.pro.entitled';
  static const _trialUsedKey = 'scanella.pro.trial_used';

  /// Testing tools only. App Store builds never read these.
  static const testingForceFreeKey = 'scanella.pro.testing_force_free';
  static const testingOfferTrialKey = 'scanella.pro.testing_offer_trial';
  static const testingUseStoreKey = 'scanella.pro.testing_use_store';

  /// Shown instead of Apple’s sheet when the app painted a free month that
  /// this Apple ID is not owed. The payment window is Apple’s: the date on
  /// it cannot be changed from here.
  static const trialWouldChargeTodayMessage =
      'This Apple ID already used the 1 month free, so Apple would charge '
      'today. To test a real trial, open iPhone Settings → App Store → '
      'Sandbox Account and sign in with a new sandbox tester, then try again.';

  final ProPurchase _purchase;
  final LocalizedPricing _pricing;
  final Locale? locale;
  final bool _testingTools;
  final DateTime Function() _now;

  Future<void> restore() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      var entitled = prefs.getBool(_entitlementKey) ?? false;
      var trialUsed = prefs.getBool(_trialUsedKey) ?? false;

      var courtesyUsed = false;
      DateTime? courtesyUntil;
      try {
        final courtesy = await _purchase.readCourtesyTrial();
        courtesyUsed = courtesy.used;
        courtesyUntil = courtesy.until;
      } catch (_) {}
      final courtesyActive = courtesyUntil != null &&
          courtesyUntil.isAfter(_now());

      var useStore =
          _testingTools && (prefs.getBool(testingUseStoreKey) ?? false);
      var forceFree = false;
      var offerTrial = false;
      if (_testingTools) {
        try {
          final pins = await _purchase.readTestingPins();
          if (pins.useStore) useStore = true;
          if (pins.forceFree || pins.offerTrial) useStore = false;
          if (pins.forceFree) forceFree = true;
          if (pins.offerTrial) offerTrial = true;
        } catch (_) {}
        // Leftover Apple / Keychain Pro must not skip the 7-day tap.
        if (!courtesyUsed) {
          forceFree = true;
          useStore = false;
        } else if (!useStore) {
          forceFree = true;
        }
      }
      try {
        // Asking the store also writes the Keychain copy. While a testing
        // pin is on, skip that: it would stamp Pro back on, and a reinstall
        // would look subscribed again.
        if (!forceFree) {
          final live = await _purchase.hasActiveEntitlement();
          if (live != null && live != entitled) {
            entitled = live;
            await prefs.setBool(_entitlementKey, live);
          }
        }
      } catch (_) {}
      if (forceFree) entitled = false;

      // SharedPreferences is wiped by an uninstall, so a lapsed subscriber
      // who reinstalls would otherwise be offered the introductory month a
      // second time and be charged straight away. Ask the store, which
      // remembers the trial even after it was cancelled.
      if (!offerTrial && !trialUsed) {
        try {
          if (await _purchase.trialConsumed()) trialUsed = true;
        } catch (_) {}
      }
      if (offerTrial) trialUsed = false;

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

      if (entitled && !trialUsed) trialUsed = true;
      if (!offerTrial &&
          trialUsed &&
          !(prefs.getBool(_trialUsedKey) ?? false)) {
        await prefs.setBool(_trialUsedKey, true);
        await _purchase.markTrialConsumed();
      }

      // Whether to say "1 month free" anywhere. The store answers both
      // halves of it — is an offer configured, and is this account still
      // owed one — so a build with no offer set up in App Store Connect
      // quietly shows the plain price instead of promising a month that
      // would bill straight away. The testing pin is the exception: it
      // only paints the first-time UI so a tester can walk the screens.
      var canStartTrial = false;
      if (!entitled) {
        if (offerTrial) {
          canStartTrial = true;
        } else {
          bool? eligible;
          try {
            eligible = await _purchase.introOfferAvailable();
          } catch (_) {}
          canStartTrial = eligible ?? !trialUsed;
        }
      }

      if (courtesyActive) entitled = true;
      if (_testingTools && offerTrial && !courtesyUsed && !entitled) {
        canStartTrial = false;
      }
      final canStartCourtesyTrial =
          !entitled && !courtesyUsed && !canStartTrial;

      state = state.copyWith(
        isPro: entitled,
        offer: offer,
        busy: false,
        storeProductsReady: storeReady,
        error: storeError,
        trialUsed: trialUsed,
        canStartTrial: canStartTrial,
        canStartCourtesyTrial: canStartCourtesyTrial,
        testingBuild: _testingTools,
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
      // The Apple sheet decides the billing date. If this account is not
      // owed a free month, opening it after a "Start trial" button would
      // charge today. Do not open it.
      if (state.canStartTrial) {
        final eligible = (await _purchase.introEligibility()).forPlan(plan);
        if (eligible == false) {
          state = state.copyWith(
            busy: false,
            error: trialWouldChargeTodayMessage,
          );
          return false;
        }
      }
      final ok = await _purchase.buy(plan);
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_entitlementKey, true);
        await prefs.setBool(_trialUsedKey, true);
        await prefs.remove(testingForceFreeKey);
        await prefs.remove(testingOfferTrialKey);
        await prefs.setBool(testingUseStoreKey, true);
        await _purchase.writeTestingPins(useStore: true);
        await _purchase.markTrialConsumed();
        state = state.copyWith(
          isPro: true,
          busy: false,
          trialUsed: true,
          canStartTrial: false,
          canStartCourtesyTrial: false,
        );
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
        await prefs.remove(testingForceFreeKey);
        await prefs.remove(testingOfferTrialKey);
        await prefs.setBool(testingUseStoreKey, true);
        await _purchase.writeTestingPins(useStore: true);
        await _purchase.markTrialConsumed();
        state = state.copyWith(
          isPro: true,
          busy: false,
          trialUsed: true,
          canStartTrial: false,
          canStartCourtesyTrial: false,
        );
        return true;
      }
      // A restore that finds nothing is also the customer asking why the
      // app thinks they are subscribed. Where the store gives a definite
      // no — StoreKit 2 does — the saved yes is simply wrong and Pro goes
      // off. An unsure answer comes back null and changes nothing, so a
      // dropped connection cannot take Pro away from someone paying.
      bool? live;
      try {
        live = await _purchase.hasActiveEntitlement();
      } catch (_) {}
      if (live == false) {
        final courtesy = await _purchase.readCourtesyTrial();
        final courtesyActive = courtesy.until != null &&
            courtesy.until!.isAfter(_now());
        if (courtesyActive) {
          state = state.copyWith(isPro: true, busy: false);
          return false;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_entitlementKey, false);
        state = state.copyWith(
          isPro: false,
          busy: false,
          error: state.isPro
              ? 'This Apple ID has no Scanella Pro subscription, so Pro has '
                    'been switched off on this iPhone.'
              : 'No Pro purchase found for this Apple ID.',
        );
        return false;
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

  /// Unlocks Pro for [ProTrial.courtesy] without Apple. Once per device.
  Future<bool> startCourtesyTrial() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final existing = await _purchase.readCourtesyTrial();
      if (existing.used) {
        state = state.copyWith(
          busy: false,
          error: 'The ${ProTrial.courtesyDays}-day trial has already been used '
              'on this iPhone.',
        );
        return false;
      }
      final until = _now().add(ProTrial.courtesy);
      await _purchase.startCourtesyTrial(until: until);
      state = state.copyWith(
        isPro: true,
        busy: false,
        canStartCourtesyTrial: false,
        canStartTrial: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _readable(e));
      return false;
    }
  }

  /// Starts the 7-day app trial when that is on offer, otherwise Apple.
  Future<bool> startOfferedTrialOrSubscribe(ProPlan plan) {
    if (state.canStartCourtesyTrial) return startCourtesyTrial();
    return subscribe(plan);
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
