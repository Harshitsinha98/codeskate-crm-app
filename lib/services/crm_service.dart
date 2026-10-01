import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';

/// Result of a CRM backend call.
class CrmResult {
  final bool ok;
  final String? error;
  final Map<String, dynamic> data;

  CrmResult({required this.ok, this.error, this.data = const {}});
}

/// Client for the secured lead / follow-up workflows on the backend.
///
/// Firestore rules make lead status, assignment and follow-up tasks
/// server-owned, so every mutation goes through these endpoints (the same
/// ones the web CRM uses in `src/utils/billingApi.js`):
///   POST /api/follow-ups/schedule
///   POST /api/follow-ups/:taskId/complete
///   POST /api/follow-ups/:leadId/status
///   POST /api/follow-ups/:leadId/reassign
///   POST /api/leads/manual            (org admins only)
class CrmService {
  final Future<String?> Function() _getIdToken;

  CrmService(this._getIdToken);

  String get _base => AppConstants.backendBaseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<CrmResult> _post(String path, Map<String, dynamic> body) async {
    if (!AppConstants.hasBackend) {
      return CrmResult(ok: false, error: 'Backend URL not configured.');
    }
    try {
      final token = await _getIdToken();
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      Map<String, dynamic> data = {};
      try {
        if (res.body.isNotEmpty) data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return CrmResult(ok: true, data: data);
      }
      return CrmResult(
        ok: false,
        error: data['error']?.toString() ?? 'Request failed (${res.statusCode})',
        data: data,
      );
    } catch (e) {
      return CrmResult(ok: false, error: 'Network error — please check your internet.');
    }
  }

  Future<CrmResult> updateLeadStatus({
    required String orgId,
    required String leadId,
    required String status,
  }) =>
      _post('/api/follow-ups/${Uri.encodeComponent(leadId)}/status', {
        'orgId': orgId,
        'status': status,
      });

  Future<CrmResult> reassignLead({
    required String orgId,
    required String leadId,
    required String assignedTo,
  }) =>
      _post('/api/follow-ups/${Uri.encodeComponent(leadId)}/reassign', {
        'orgId': orgId,
        'assignedTo': assignedTo,
      });

  Future<CrmResult> scheduleFollowUp({
    required String orgId,
    required String leadId,
    required DateTime dueAt,
    required String type,
    String? title,
  }) =>
      _post('/api/follow-ups/schedule', {
        'orgId': orgId,
        'leadId': leadId,
        'dueAt': dueAt.toUtc().toIso8601String(),
        'type': type,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      });

  Future<CrmResult> completeFollowUp({
    required String orgId,
    required String taskId,
    required int expectedRevision,
    required String outcome,
    String? note,
    String? leadStatus,
    DateTime? nextDueAt,
  }) =>
      _post('/api/follow-ups/${Uri.encodeComponent(taskId)}/complete', {
        'orgId': orgId,
        'expectedRevision': expectedRevision,
        'outcome': outcome,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (leadStatus != null) 'leadStatus': leadStatus,
        if (nextDueAt != null) 'nextDueAt': nextDueAt.toUtc().toIso8601String(),
      });

  Future<CrmResult> createManualLead({
    required String orgId,
    required String name,
    required String phone,
    String? email,
    String? requirement,
    String priority = 'Warm',
  }) =>
      _post('/api/leads/manual', {
        'orgId': orgId,
        'name': name,
        'phone': phone,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (requirement != null && requirement.trim().isNotEmpty) 'requirement': requirement.trim(),
        'priority': priority,
      });
}
