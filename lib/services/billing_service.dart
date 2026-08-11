import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../models/billing_models.dart';

/// Result wrapper for billing calls.
class BillingResult<T> {
  final bool ok;
  final T? data;
  final String? error;
  final String? code; // e.g. 'plan_required'

  BillingResult({required this.ok, this.data, this.error, this.code});
}

/// Thin client for the CRM billing backend — mirrors the web CRM's
/// `src/utils/billingApi.js`. All authenticated calls attach the Firebase ID
/// token as a Bearer header. Endpoints and request/response shapes match the
/// existing SNS-ADS-ERP whatsapp-backend so no backend changes are required.
class BillingService {
  final Future<String?> Function() _getIdToken;

  BillingService(this._getIdToken);

  String get _base =>
      AppConstants.backendBaseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _getIdToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      if (res.body.isNotEmpty) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  // ---- Gateway config (no auth) ----
  Future<BillingConfig> getBillingConfig() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/api/billing/config'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return BillingConfig.fromMap(_decode(res));
      }
    } catch (_) {}
    return BillingConfig();
  }

  // ---- Add-on quota + available packs ----
  Future<BillingResult<QuotaStatus>> getQuotaStatus(String orgId) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$_base/api/billing/quota-status?orgId=${Uri.encodeComponent(orgId)}'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 25));
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return BillingResult(ok: true, data: QuotaStatus.fromMap(body));
      }
      return BillingResult(
          ok: false,
          error: body['error']?.toString() ?? 'Could not load add-ons.',
          code: body['code']?.toString());
    } catch (e) {
      return BillingResult(ok: false, error: 'Network error: $e');
    }
  }

  // ---- Add-on purchase (order -> [Razorpay] -> verify) ----
  /// Step 1: create a Razorpay order for an add-on pack.
  /// Returns { orderId, amount (paise), currency, keyId, addOnName }.
  Future<BillingResult<Map<String, dynamic>>> createAddOnOrder({
    required String orgId,
    required String addOnId,
    int quantity = 1,
  }) async {
    return _post('/api/billing/razorpay/addon/order', {
      'orgId': orgId,
      'addOnId': addOnId,
      'quantity': quantity,
    });
  }

  /// Step 3: verify the add-on payment. The backend resolves the add-on from
  /// the order, so only the Razorpay handshake fields are required.
  Future<BillingResult<Map<String, dynamic>>> verifyAddOnPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    return _post('/api/billing/razorpay/addon/verify', {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
  }

  // ---- Voice Wallet ----
  Future<BillingResult<WalletBalance>> getWalletBalance(String orgId) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$_base/api/wallet/balance?orgId=${Uri.encodeComponent(orgId)}'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 25));
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return BillingResult(ok: true, data: WalletBalance.fromMap(body));
      }
      return BillingResult(
          ok: false,
          error: body['error']?.toString() ?? 'Could not load balance.',
          code: body['code']?.toString());
    } catch (e) {
      return BillingResult(ok: false, error: 'Network error: $e');
    }
  }

  Future<List<WalletTransaction>> getWalletTransactions(String orgId) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$_base/api/wallet/transactions?orgId=${Uri.encodeComponent(orgId)}'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = _decode(res);
        final list = (body['transactions'] as List?) ?? [];
        return list
            .whereType<Map>()
            .map((e) => WalletTransaction.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Create a Razorpay order to top up the Voice Wallet (min ₹100, Growth+).
  Future<BillingResult<Map<String, dynamic>>> createWalletOrder({
    required String orgId,
    required int amountInr,
  }) async {
    return _post('/api/wallet/order', {'orgId': orgId, 'amountInr': amountInr});
  }

  Future<BillingResult<Map<String, dynamic>>> verifyWalletPayment({
    required String orgId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    return _post('/api/wallet/verify', {
      'orgId': orgId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
  }

  // ---- shared POST helper ----
  Future<BillingResult<Map<String, dynamic>>> _post(
      String path, Map<String, dynamic> body) async {
    if (!AppConstants.hasBackend) {
      return BillingResult(
          ok: false, error: 'Backend URL not configured.', code: 'no_backend');
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      final data = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return BillingResult(ok: true, data: data);
      }
      return BillingResult(
        ok: false,
        error: data['error']?.toString() ?? 'Request failed (${res.statusCode}).',
        code: data['code']?.toString(),
      );
    } catch (e) {
      return BillingResult(ok: false, error: 'Network error: $e');
    }
  }
}
