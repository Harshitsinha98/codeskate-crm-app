import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';

/// Result wrapper for bridge-call calls.
class BridgeResult<T> {
  final bool ok;
  final T? data;
  final String? error;
  final String? code; // plan_upgrade_required | wallet_empty | no_voice_number
  final double? balanceInr;

  BridgeResult({
    required this.ok,
    this.data,
    this.error,
    this.code,
    this.balanceInr,
  });
}

/// Live/finished status of a bridge call (from /poll and /history).
class BridgeCallStatus {
  final String callId;
  final String status;
  final int durationSeconds;
  final int agentSeconds;
  final int customerSeconds;
  final int billedMinutes;
  final double costInr;
  final String? recordingUrl;
  final String? failureReason;

  BridgeCallStatus({
    required this.callId,
    required this.status,
    this.durationSeconds = 0,
    this.agentSeconds = 0,
    this.customerSeconds = 0,
    this.billedMinutes = 0,
    this.costInr = 0,
    this.recordingUrl,
    this.failureReason,
  });

  factory BridgeCallStatus.fromMap(Map<String, dynamic> m) {
    int i(dynamic v) => v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? 0));
    double d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return BridgeCallStatus(
      callId: m['callId']?.toString() ?? '',
      status: m['status']?.toString() ?? 'unknown',
      durationSeconds: i(m['durationSeconds']),
      agentSeconds: i(m['agentSeconds']),
      customerSeconds: i(m['customerSeconds']),
      billedMinutes: i(m['billedMinutes']),
      costInr: d(m['costInr']),
      recordingUrl: m['recordingUrl']?.toString(),
      failureReason: m['failureReason']?.toString(),
    );
  }

  /// Terminal states — polling should stop here.
  static const terminal = {
    'completed',
    'wallet-deducted',
    'failed',
    'no-answer',
    'agent_no_confirm',
    'customer_voicemail',
  };

  bool get isTerminal => terminal.contains(status);
  bool get isSuccess => status == 'completed' || status == 'wallet-deducted';
}

/// A row for the Call History / Recordings screens.
class BridgeCallRecord {
  final String callId;
  final String status;
  final String? initiatedAt;
  final int initiatedAtMs;
  final String employeeName;
  final String? employeeUid;
  final String leadName;
  final String leadPhone;
  final int durationSeconds;
  final int customerSeconds;
  final double costInr;
  final String? recordingUrl;
  final String? failureReason;

  BridgeCallRecord({
    required this.callId,
    required this.status,
    this.initiatedAt,
    this.initiatedAtMs = 0,
    this.employeeName = '',
    this.employeeUid,
    this.leadName = '',
    this.leadPhone = '',
    this.durationSeconds = 0,
    this.customerSeconds = 0,
    this.costInr = 0,
    this.recordingUrl,
    this.failureReason,
  });

  factory BridgeCallRecord.fromMap(Map<String, dynamic> m) {
    int i(dynamic v) => v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? 0));
    double d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return BridgeCallRecord(
      callId: m['callId']?.toString() ?? '',
      status: m['status']?.toString() ?? '',
      initiatedAt: m['initiatedAt']?.toString(),
      initiatedAtMs: i(m['initiatedAtMs']),
      employeeName: m['employeeName']?.toString() ?? 'Employee',
      employeeUid: m['employeeUid']?.toString(),
      leadName: m['leadName']?.toString() ?? 'Lead',
      leadPhone: m['leadPhone']?.toString() ?? '',
      durationSeconds: i(m['durationSeconds']),
      customerSeconds: i(m['customerSeconds']),
      costInr: d(m['costInr']),
      recordingUrl: m['recordingUrl']?.toString(),
      failureReason: m['failureReason']?.toString(),
    );
  }
}

class HistoryPage {
  final List<BridgeCallRecord> items;
  final int? nextCursor;
  final bool hasMore;
  HistoryPage({required this.items, this.nextCursor, this.hasMore = false});
}

/// Client for the backend bridge-call API (mirrors web `bridgeCallApi.js`).
/// All calls attach the Firebase ID token as a Bearer header.
class BridgeCallService {
  final Future<String?> Function() _getIdToken;
  BridgeCallService(this._getIdToken);

  String get _base => AppConstants.backendBaseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _headers() async {
    final h = {'Content-Type': 'application/json'};
    final token = await _getIdToken();
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      if (r.body.isNotEmpty) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  /// Start a bridge call. The agent's phone is read server-side from the token.
  Future<BridgeResult<String>> initiate({
    required String orgId,
    required String leadId,
    required String leadPhone,
    String? leadName,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/v1/bridge-call/initiate'),
            headers: await _headers(),
            body: jsonEncode({
              'orgId': orgId,
              'leadId': leadId,
              'leadPhone': leadPhone,
              if (leadName != null) 'leadName': leadName,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final b = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300 && b['ok'] == true) {
        return BridgeResult(ok: true, data: b['callId']?.toString());
      }
      final bal = b['balanceInr'];
      return BridgeResult(
        ok: false,
        error: b['error']?.toString() ?? 'Could not start the call.',
        code: b['code']?.toString(),
        balanceInr: bal is num ? bal.toDouble() : null,
      );
    } catch (e) {
      return BridgeResult(ok: false, error: 'Network error: $e');
    }
  }

  /// Poll a call's live status.
  Future<BridgeCallStatus?> poll(String callId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/v1/bridge-call/poll'),
            headers: await _headers(),
            body: jsonEncode({'callId': callId}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return BridgeCallStatus.fromMap(_decode(res));
      }
    } catch (_) {}
    return null;
  }

  /// Admin/owner: paginated call history.
  Future<HistoryPage> history({
    required String orgId,
    int limit = 50,
    int? startAfter,
  }) async {
    final q = StringBuffer('orgId=${Uri.encodeComponent(orgId)}&limit=$limit');
    if (startAfter != null) q.write('&startAfter=$startAfter');
    try {
      final res = await http
          .get(Uri.parse('$_base/api/v1/bridge-call/history?$q'),
              headers: await _headers())
          .timeout(const Duration(seconds: 25));
      final b = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300 && b['ok'] == true) {
        final list = (b['calls'] as List?) ?? [];
        return HistoryPage(
          items: list
              .whereType<Map>()
              .map((e) => BridgeCallRecord.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
          nextCursor: (b['nextCursor'] as num?)?.toInt(),
          hasMore: b['hasMore'] == true,
        );
      }
    } catch (_) {}
    return HistoryPage(items: const []);
  }

  /// Admin/owner: paginated recordings (only calls that have a recording).
  Future<HistoryPage> recordings({
    required String orgId,
    int limit = 30,
    int? startAfter,
    String? employee,
  }) async {
    final q = StringBuffer('orgId=${Uri.encodeComponent(orgId)}&limit=$limit');
    if (startAfter != null) q.write('&startAfter=$startAfter');
    if (employee != null && employee.isNotEmpty) {
      q.write('&employee=${Uri.encodeComponent(employee)}');
    }
    try {
      final res = await http
          .get(Uri.parse('$_base/api/v1/bridge-call/recordings?$q'),
              headers: await _headers())
          .timeout(const Duration(seconds: 25));
      final b = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300 && b['ok'] == true) {
        final list = (b['recordings'] as List?) ?? [];
        return HistoryPage(
          items: list
              .whereType<Map>()
              .map((e) => BridgeCallRecord.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
          nextCursor: (b['nextCursor'] as num?)?.toInt(),
          hasMore: b['hasMore'] == true,
        );
      }
    } catch (_) {}
    return HistoryPage(items: const []);
  }
}
