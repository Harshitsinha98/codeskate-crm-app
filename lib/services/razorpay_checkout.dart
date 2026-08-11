import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// A completed Razorpay payment handshake — the three fields the backend
/// `verify` endpoints need.
class RazorpaySuccess {
  final String orderId;
  final String paymentId;
  final String signature;

  RazorpaySuccess({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });
}

/// Raised when the user cancels or the payment fails.
class RazorpayCancelled implements Exception {
  final String message;
  RazorpayCancelled(this.message);
  @override
  String toString() => message;
}

/// Wraps the event-based `razorpay_flutter` plugin in a simple awaitable API.
///
/// Usage:
/// ```dart
/// final checkout = RazorpayCheckout();
/// try {
///   final result = await checkout.open(
///     keyId: order['keyId'],
///     amountPaise: order['amount'],
///     orderId: order['orderId'],
///     description: 'AI Reply Pack',
///     name: 'Codeskate CRM',
///     contact: '9876543210',
///   );
///   // hand result.orderId/paymentId/signature to the verify endpoint
/// } on RazorpayCancelled catch (e) {
///   // user dismissed / payment failed
/// } finally {
///   checkout.dispose();
/// }
/// ```
class RazorpayCheckout {
  final Razorpay _razorpay = Razorpay();
  Completer<RazorpaySuccess>? _completer;

  RazorpayCheckout() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  Future<RazorpaySuccess> open({
    required String keyId,
    required int amountPaise,
    required String orderId,
    required String description,
    String name = 'Codeskate CRM',
    String? contact,
    String? email,
    String currency = 'INR',
    String themeColor = '#E8652B',
  }) {
    _completer = Completer<RazorpaySuccess>();

    final options = <String, dynamic>{
      'key': keyId,
      'amount': amountPaise,
      'currency': currency,
      'order_id': orderId,
      'name': name,
      'description': description,
      'theme': {'color': themeColor},
      'prefill': {
        if (contact != null && contact.isNotEmpty) 'contact': contact,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      // Keep the checkout open if a payment attempt fails so the user can retry.
      'retry': {'enabled': true, 'max_count': 1},
      'timeout': 300,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _completer?.completeError(RazorpayCancelled('Could not open checkout: $e'));
    }
    return _completer!.future;
  }

  void _onSuccess(PaymentSuccessResponse r) {
    if (_completer == null || _completer!.isCompleted) return;
    if (r.orderId == null || r.paymentId == null || r.signature == null) {
      _completer!.completeError(
          RazorpayCancelled('Payment response was incomplete. Please retry.'));
      return;
    }
    _completer!.complete(RazorpaySuccess(
      orderId: r.orderId!,
      paymentId: r.paymentId!,
      signature: r.signature!,
    ));
  }

  void _onError(PaymentFailureResponse r) {
    if (_completer == null || _completer!.isCompleted) return;
    final msg = (r.message == null || r.message!.trim().isEmpty)
        ? 'Payment was cancelled.'
        : r.message!;
    _completer!.completeError(RazorpayCancelled(msg));
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // Selecting an external wallet doesn't complete the payment here; the
    // success/error callback will still fire. No-op.
  }

  /// Must be called to release native listeners (e.g. in State.dispose()).
  void dispose() {
    _razorpay.clear();
  }
}
