import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'analytics_service.dart';
import 'entitlement_service.dart';

/// Wraps `in_app_purchase` for FitForge Premium (auto-renewing subscriptions).
///
/// On a purchased/restored subscription it grants entitlement through
/// [EntitlementService]. Receipt verification is currently client-side only —
/// add a server (Cloud Function) check inside [_deliver] before launch.
class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService instance = BillingService._();

  /// Configure these to match the subscription products you create in the
  /// Play Console (and App Store Connect for iOS).
  static const String monthlyId = 'fitforge_premium_monthly';
  static const String yearlyId = 'fitforge_premium_yearly';
  static const Set<String> _productIds = {monthlyId, yearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available = false;
  bool _initialized = false;
  bool _purchasePending = false;
  String? _error;
  List<ProductDetails> _products = const <ProductDetails>[];

  bool get isAvailable => _available;
  bool get initialized => _initialized;
  bool get purchasePending => _purchasePending;
  String? get error => _error;
  List<ProductDetails> get products => _products;

  ProductDetails? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        notifyListeners();
        return;
      }

      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (Object error) {
          _error = '$error';
          notifyListeners();
        },
      );

      final response = await _iap.queryProductDetails(_productIds);
      _products = response.productDetails;
      if (response.error != null) {
        _error = response.error!.message;
      }
      notifyListeners();

      // Re-grant entitlement for users who already subscribed (e.g. new device).
      await _iap.restorePurchases();
    } catch (error) {
      _error = '$error';
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    _error = null;
    _purchasePending = true;
    notifyListeners();
    AnalyticsService.instance.log('premium_purchase_started', {
      'product': product.id,
    });
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (error) {
      _error = '$error';
      _purchasePending = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    _error = null;
    try {
      await _iap.restorePurchases();
    } catch (error) {
      _error = '$error';
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final status = purchase.status;
      if (status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else if (status == PurchaseStatus.error) {
        _error = purchase.error?.message ?? 'Purchase failed.';
        _purchasePending = false;
        AnalyticsService.instance.log('premium_purchase_error');
      } else if (status == PurchaseStatus.canceled) {
        _purchasePending = false;
      } else if (status == PurchaseStatus.purchased ||
          status == PurchaseStatus.restored) {
        await _deliver(purchase);
        _purchasePending = false;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      notifyListeners();
    }
  }

  Future<void> _deliver(PurchaseDetails purchase) async {
    // Server-side verification: the Cloud Function checks the purchase token
    // against the Play Developer API and writes the authoritative isPremium
    // flag. Clients cannot grant themselves premium (Firestore rules block it).
    final token = purchase.verificationData.serverVerificationData;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyPlayPurchase',
      );
      final result = await callable.call(<String, dynamic>{
        'productId': purchase.productID,
        'purchaseToken': token,
      });
      final data = result.data;
      final granted = data is Map && data['isPremium'] == true;
      await EntitlementService.instance.applyVerifiedEntitlement(granted);
      AnalyticsService.instance.log('premium_verified', {
        'product': purchase.productID,
        'granted': granted,
      });
    } catch (error) {
      // Verification unavailable (e.g. function not deployed yet, transient
      // network error). Grant locally so a paying user isn't blocked; the
      // server reconciles on the next restore/RTDN.
      debugPrint('Server verification failed, granting locally: $error');
      await EntitlementService.instance.setPremium(true);
      AnalyticsService.instance.log('premium_verify_fallback', {
        'product': purchase.productID,
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
