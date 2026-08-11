import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/billing_models.dart';
import '../services/billing_service.dart';
import '../services/razorpay_checkout.dart';
import 'auth_provider.dart';

/// Outcome of a purchase attempt, for surfacing a snackbar in the UI.
class PurchaseOutcome {
  final bool ok;
  final String message;
  PurchaseOutcome(this.ok, this.message);
  factory PurchaseOutcome.success(String m) => PurchaseOutcome(true, m);
  factory PurchaseOutcome.error(String m) => PurchaseOutcome(false, m);
}

/// Owns billing state for the active org:
///  - live subscription/plan status (Firestore `organizations/{orgId}`)
///  - add-on quota + purchasable packs (REST)
///  - Voice Wallet balance + transactions (REST)
///  - Razorpay purchase orchestration (order -> checkout -> verify -> refresh)
///
/// Subscription upgrades stay on the web app; the mobile app handles add-on
/// packs and wallet top-ups, exactly as the user requested.
class BillingProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthProvider? _auth;
  late final BillingService _service = BillingService(
    () => _auth?.getIdToken() ?? Future<String?>.value(null),
  );

  StreamSubscription? _orgSub;

  OrgBilling? _org;
  BillingConfig _config = BillingConfig();
  QuotaStatus? _quota;
  WalletBalance _wallet = WalletBalance();
  List<WalletTransaction> _transactions = [];

  bool _loadingOrg = false;
  bool _loadingQuota = false;
  bool _loadingWallet = false;
  String? _error;

  // ---- getters ----
  OrgBilling? get org => _org;
  BillingConfig get config => _config;
  QuotaStatus? get quota => _quota;
  WalletBalance get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get loadingOrg => _loadingOrg;
  bool get loadingQuota => _loadingQuota;
  bool get loadingWallet => _loadingWallet;
  String? get error => _error;

  List<AddOn> get availableAddOns => _quota?.availableAddOns ?? const [];
  bool get razorpayEnabled => _config.razorpay;

  /// Voice Wallet is a Growth+ feature (mirrors the web CRM gating).
  static const Set<String> _walletPlans = {
    'growth',
    'enterprise',
    'enterprise_plus'
  };
  bool get walletUnlocked =>
      _walletPlans.contains(_org?.planId ?? 'starter');

  String? get _orgId => _auth?.user?.activeOrgId;
  String? get _contact => _auth?.user?.phone?.replaceAll('+91', '');

  void updateAuth(AuthProvider auth) {
    final changed = _auth?.user?.activeOrgId != auth.user?.activeOrgId;
    _auth = auth;
    if (changed) _startOrgListener();
  }

  void _startOrgListener() {
    _orgSub?.cancel();
    final orgId = _orgId;
    if (orgId == null) {
      _org = null;
      _quota = null;
      _transactions = [];
      _wallet = WalletBalance();
      notifyListeners();
      return;
    }

    _loadingOrg = true;
    notifyListeners();

    _orgSub = _db
        .collection('organizations')
        .doc(orgId)
        .snapshots()
        .listen((snap) {
      _org = snap.exists ? OrgBilling.fromSnapshot(snap) : null;
      _loadingOrg = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Billing org listener error: $e');
      _loadingOrg = false;
      notifyListeners();
    });
  }

  /// Load everything the billing/wallet screens need. Safe to call repeatedly.
  Future<void> loadBillingData() async {
    _config = await _service.getBillingConfig();
    notifyListeners();
    await Future.wait([refreshQuota(), refreshWallet()]);
  }

  Future<void> refreshQuota() async {
    final orgId = _orgId;
    if (orgId == null) return;
    _loadingQuota = true;
    notifyListeners();
    final res = await _service.getQuotaStatus(orgId);
    if (res.ok) {
      _quota = res.data;
      _error = null;
    } else {
      _error = res.error;
    }
    _loadingQuota = false;
    notifyListeners();
  }

  Future<void> refreshWallet() async {
    final orgId = _orgId;
    if (orgId == null) return;
    _loadingWallet = true;
    notifyListeners();
    final bal = await _service.getWalletBalance(orgId);
    if (bal.ok && bal.data != null) _wallet = bal.data!;
    _transactions = await _service.getWalletTransactions(orgId);
    _loadingWallet = false;
    notifyListeners();
  }

  /// Purchase an add-on pack: create order -> open Razorpay -> verify -> refresh.
  /// [checkout] is owned by the calling screen (for native lifecycle).
  Future<PurchaseOutcome> purchaseAddOn({
    required RazorpayCheckout checkout,
    required AddOn addOn,
  }) async {
    final orgId = _orgId;
    if (orgId == null) return PurchaseOutcome.error('No active organization.');
    if (!_config.razorpay) {
      return PurchaseOutcome.error(
          'Payments are temporarily unavailable. Please try again later.');
    }

    final order = await _service.createAddOnOrder(orgId: orgId, addOnId: addOn.id);
    if (!order.ok || order.data == null) {
      return PurchaseOutcome.error(order.error ?? 'Could not start the purchase.');
    }
    final d = order.data!;
    try {
      final success = await checkout.open(
        keyId: d['keyId']?.toString() ?? '',
        amountPaise: (d['amount'] as num?)?.toInt() ?? (addOn.monthlyPrice * 100),
        orderId: d['orderId']?.toString() ?? '',
        description: addOn.name,
        contact: _contact,
      );
      final verify = await _service.verifyAddOnPayment(
        razorpayOrderId: success.orderId,
        razorpayPaymentId: success.paymentId,
        razorpaySignature: success.signature,
      );
      if (!verify.ok) {
        return PurchaseOutcome.error(
            verify.error ?? 'Payment done but verification failed. Contact support.');
      }
      await refreshQuota();
      return PurchaseOutcome.success('${addOn.name} added to your account.');
    } on RazorpayCancelled catch (e) {
      return PurchaseOutcome.error(e.message);
    } catch (e) {
      return PurchaseOutcome.error('Something went wrong: $e');
    }
  }

  /// Top up the Voice Wallet by [amountInr] via Razorpay.
  Future<PurchaseOutcome> topUpWallet({
    required RazorpayCheckout checkout,
    required int amountInr,
  }) async {
    final orgId = _orgId;
    if (orgId == null) return PurchaseOutcome.error('No active organization.');
    if (!_config.razorpay) {
      return PurchaseOutcome.error(
          'Payments are temporarily unavailable. Please try again later.');
    }

    final order = await _service.createWalletOrder(orgId: orgId, amountInr: amountInr);
    if (!order.ok || order.data == null) {
      // The backend gates wallet to Growth+ with code 'plan_required'.
      if (order.code == 'plan_required') {
        return PurchaseOutcome.error(
            'Voice Wallet is available on the Growth plan and above. Upgrade on the web app.');
      }
      return PurchaseOutcome.error(order.error ?? 'Could not start the top-up.');
    }
    final d = order.data!;
    try {
      final success = await checkout.open(
        keyId: d['keyId']?.toString() ?? '',
        amountPaise: (d['amount'] as num?)?.toInt() ?? (amountInr * 100),
        orderId: d['orderId']?.toString() ?? '',
        description: 'Voice Wallet top-up (₹$amountInr)',
        contact: _contact,
      );
      final verify = await _service.verifyWalletPayment(
        orgId: orgId,
        razorpayOrderId: success.orderId,
        razorpayPaymentId: success.paymentId,
        razorpaySignature: success.signature,
      );
      if (!verify.ok) {
        return PurchaseOutcome.error(
            verify.error ?? 'Payment done but verification failed. Contact support.');
      }
      await refreshWallet();
      return PurchaseOutcome.success('₹$amountInr added to your Voice Wallet.');
    } on RazorpayCancelled catch (e) {
      return PurchaseOutcome.error(e.message);
    } catch (e) {
      return PurchaseOutcome.error('Something went wrong: $e');
    }
  }

  @override
  void dispose() {
    _orgSub?.cancel();
    super.dispose();
  }
}
