import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';

/// Result of a WhatsApp backend call.
class WhatsAppResult {
  final bool ok;
  final String? error;
  final String? code; // e.g. 'template_required', 'plan_limit'
  final Map<String, dynamic>? data;

  WhatsAppResult({required this.ok, this.error, this.code, this.data});

  factory WhatsAppResult.success([Map<String, dynamic>? data]) =>
      WhatsAppResult(ok: true, data: data);
  factory WhatsAppResult.failure(String error, [String? code]) =>
      WhatsAppResult(ok: false, error: error, code: code);
}

/// Thin client for the CRM/WhatsApp backend (mirrors the web CRM API).
/// All calls require a Firebase ID token (Bearer auth).
class WhatsAppService {
  final Future<String?> Function() _getIdToken;
  final _uuid = const Uuid();

  WhatsAppService(this._getIdToken);

  String get _base => AppConstants.backendBaseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _headers() async {
    final token = await _getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  WhatsAppResult _parse(http.Response res) {
    Map<String, dynamic> body = {};
    try {
      if (res.body.isNotEmpty) body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return WhatsAppResult.success(body);
    }
    return WhatsAppResult.failure(
      body['error']?.toString() ?? 'Request failed (${res.statusCode})',
      body['code']?.toString(),
    );
  }

  /// Send a free-form WhatsApp text message (valid inside 24h service window).
  Future<WhatsAppResult> sendMessage({
    required String orgId,
    required String leadId,
    required String text,
  }) async {
    if (!AppConstants.hasBackend) {
      return WhatsAppResult.failure(
          'Backend URL not configured. Set BACKEND_URL to enable sending.',
          'no_backend');
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/whatsapp/messages'),
            headers: await _headers(),
            body: jsonEncode({
              'orgId': orgId,
              'leadId': leadId,
              'text': text,
              'clientMessageId': _uuid.v4(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      return _parse(res);
    } catch (e) {
      return WhatsAppResult.failure('Network error: $e');
    }
  }

  /// Take over the conversation from AI (disables AI for this lead).
  Future<WhatsAppResult> takeOver({
    required String orgId,
    required String leadId,
    String reason = 'manual_takeover',
  }) async {
    if (!AppConstants.hasBackend) {
      return WhatsAppResult.failure('Backend URL not configured.', 'no_backend');
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/v1/chat-sessions/takeover'),
            headers: await _headers(),
            body: jsonEncode({'orgId': orgId, 'leadId': leadId, 'reason': reason}),
          )
          .timeout(const Duration(seconds: 30));
      return _parse(res);
    } catch (e) {
      return WhatsAppResult.failure('Network error: $e');
    }
  }

  /// Re-enable AI auto-replies for this lead.
  Future<WhatsAppResult> reEnableAI({
    required String orgId,
    required String leadId,
  }) async {
    if (!AppConstants.hasBackend) {
      return WhatsAppResult.failure('Backend URL not configured.', 'no_backend');
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/v1/chat-sessions/re-enable-ai'),
            headers: await _headers(),
            body: jsonEncode({'orgId': orgId, 'leadId': leadId}),
          )
          .timeout(const Duration(seconds: 30));
      return _parse(res);
    } catch (e) {
      return WhatsAppResult.failure('Network error: $e');
    }
  }
}
