import 'dart:async';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// A store product we can show and buy. Tests use [MemoryIapGateway].
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
  });

  final String id;
  final String price;
  final double rawPrice;
  final String currencyCode;
}

enum IapStatus { pending, purchased, restored, error, canceled }

class IapEvent {
  const IapEvent({
    required this.productId,
    required this.status,
    this.error,
    this.complete,
  });

  final String productId;
  final IapStatus status;
  final String? error;
  final Future<void> Function()? complete;
}

/// Talks to the App Store / Play Billing. Stripe card forms are not used:
/// digital Scanella Pro must go through store billing (Apple 3.1.1).
abstract class IapGateway {
  Future<bool> isAvailable();
  Future<List<StoreProduct>> queryProducts(Set<String> ids);
  Stream<List<IapEvent>> get purchases;
  Future<bool> buy(StoreProduct product);
  Future<void> restore();
}

/// Production StoreKit / Play Billing.
class PluginIapGateway implements IapGateway {
  PluginIapGateway({InAppPurchase? plugin})
    : _plugin = plugin ?? InAppPurchase.instance {
    _listen();
  }

  static PluginIapGateway? _shared;

  /// One listener for the life of the process. StoreKit can drop purchase
  /// updates if nothing is subscribed when the sheet completes.
  factory PluginIapGateway.shared() => _shared ??= PluginIapGateway();

  static void ensureListening() {
    PluginIapGateway.shared();
  }

  final InAppPurchase _plugin;
  final _details = <String, ProductDetails>{};
  final _events = StreamController<List<IapEvent>>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;

  void _listen() {
    if (_sub != null) return;
    try {
      _sub = _plugin.purchaseStream.listen(
        (list) async {
          await _finish(list);
          if (!_events.isClosed) _events.add(_map(list));
        },
        onError: _events.addError,
      );
    } catch (_) {}
  }

  /// StoreKit keeps a canceled or failed buy on the queue until we finish it.
  /// The next Monthly/Yearly tap then throws `storekit_duplicate_product_object`.
  Future<void> _finish(List<PurchaseDetails> list) async {
    for (final item in list) {
      if (item.status == PurchaseStatus.pending) continue;
      if (!item.pendingCompletePurchase) continue;
      try {
        await _plugin.completePurchase(item);
      } catch (_) {}
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _plugin.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async {
    final response = await _plugin.queryProductDetails(ids);
    if (response.error != null) {
      final message = response.error!.message.trim();
      throw StateError(
        message.isEmpty
            ? 'The App Store could not load Scanella Pro.'
            : message,
      );
    }
    for (final item in response.productDetails) {
      _details[item.id] = item;
    }
    return [
      for (final item in response.productDetails)
        StoreProduct(
          id: item.id,
          price: item.price,
          rawPrice: item.rawPrice,
          currencyCode: item.currencyCode,
        ),
    ];
  }

  @override
  Stream<List<IapEvent>> get purchases => _events.stream;

  @override
  Future<bool> buy(StoreProduct product) async {
    final details = _details[product.id];
    if (details == null) return false;
    return _buy(details);
  }

  Future<bool> _buy(ProductDetails details, {bool retrying = false}) async {
    try {
      return await _plugin.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
    } on PlatformException catch (e) {
      if (!retrying && e.code == 'storekit_duplicate_product_object') {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return _buy(details, retrying: true);
      }
      rethrow;
    }
  }

  @override
  Future<void> restore() => _plugin.restorePurchases();

  List<IapEvent> _map(List<PurchaseDetails> list) {
    return [
      for (final item in list)
        IapEvent(
          productId: item.productID,
          status: _status(item.status),
          error: item.error?.message,
          complete: item.pendingCompletePurchase
              ? () => _plugin.completePurchase(item)
              : null,
        ),
    ];
  }

  static IapStatus _status(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.pending:
        return IapStatus.pending;
      case PurchaseStatus.purchased:
        return IapStatus.purchased;
      case PurchaseStatus.restored:
        return IapStatus.restored;
      case PurchaseStatus.canceled:
        return IapStatus.canceled;
      case PurchaseStatus.error:
        return IapStatus.error;
    }
  }
}

/// In-memory store for tests.
class MemoryIapGateway implements IapGateway {
  MemoryIapGateway({
    this.available = true,
    List<StoreProduct>? products,
    this.buySucceeds = true,
    this.emitOnBuy = IapStatus.purchased,
    this.queryError,
    this.firstBuyError,
    this.buyError,
  }) : products = products ?? const [];

  bool available;
  List<StoreProduct> products;
  bool buySucceeds;
  IapStatus emitOnBuy;
  Object? queryError;

  /// Thrown once, then cleared, so a retry can succeed.
  Object? firstBuyError;

  /// Thrown on every buy. Used to assert the message we show the user.
  Object? buyError;

  final _out = StreamController<List<IapEvent>>.broadcast();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async {
    final error = queryError;
    if (error != null) throw error;
    return products.where((item) => ids.contains(item.id)).toList();
  }

  @override
  Stream<List<IapEvent>> get purchases => _out.stream;

  @override
  Future<bool> buy(StoreProduct product) async {
    final error = firstBuyError;
    if (error != null) {
      firstBuyError = null;
      throw error;
    }
    final always = buyError;
    if (always != null) throw always;
    if (!buySucceeds) return false;
    _out.add([IapEvent(productId: product.id, status: emitOnBuy)]);
    return true;
  }

  @override
  Future<void> restore() async {
    if (emitOnBuy == IapStatus.purchased || emitOnBuy == IapStatus.restored) {
      _out.add([
        for (final product in products)
          IapEvent(productId: product.id, status: IapStatus.restored),
      ]);
    }
  }
}
