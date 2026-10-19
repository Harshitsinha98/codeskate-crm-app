import 'package:uuid/uuid.dart';

import '../core/api/api_client.dart';

/// Typed wrappers for every backend endpoint used by the web CRM
/// (SNS-ADS-ERP/whatsapp-backend). Grouped by module.
const _uuid = Uuid();

List<Map<String, dynamic>> _list(dynamic v) =>
    (v is List) ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

// ── Team ───────────────────────────────────────────────────────────────────
class TeamApi {
  static Future<void> invite({required String orgId, required String name, required String phone, String? email, String role = 'employee'}) =>
      ApiClient.post('/api/billing/team/invite', body: {
        'orgId': orgId,
        'name': name,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        'role': role,
      });

  static Future<void> setStatus({required String orgId, required String uid, required bool active}) =>
      ApiClient.post('/api/billing/team/member-status', body: {'orgId': orgId, 'uid': uid, 'active': active});

  static Future<void> setRole({required String orgId, required String uid, required String role}) =>
      ApiClient.post('/api/billing/team/member-role', body: {'orgId': orgId, 'uid': uid, 'role': role});

  static Future<int> reassignAll({required String orgId, required String fromUid, required String toUid}) async {
    final r = await ApiClient.post('/api/billing/leads/reassign-bulk',
        body: {'orgId': orgId, 'fromEmployeeId': fromUid, 'toEmployeeId': toUid});
    return (r['count'] as num?)?.toInt() ?? 0;
  }

  static Future<void> claimInvites() => ApiClient.post('/api/billing/team/claim-invites', body: {});
}

// ── Onboarding / billing misc ──────────────────────────────────────────────
class OnboardingApi {
  static Future<Map<String, dynamic>> provisionTrial({required String orgName, required String fullName}) =>
      ApiClient.post('/api/billing/trial/provision', body: {'orgName': orgName, 'fullName': fullName});

  static Future<Map<String, dynamic>> quota(String orgId) => ApiClient.get('/api/billing/quota-status', query: {'orgId': orgId});
}

// ── Leads (bulk) ───────────────────────────────────────────────────────────
class LeadsApi {
  static Future<void> delete({required String orgId, required String leadId}) =>
      ApiClient.post('/api/leads/${Uri.encodeComponent(leadId)}/delete', body: {'orgId': orgId});

  static Future<void> setBlacklisted({required String orgId, required String leadId, required String status, required bool blacklisted}) =>
      ApiClient.post('/api/follow-ups/${Uri.encodeComponent(leadId)}/status',
          body: {'orgId': orgId, 'status': status, 'blacklisted': blacklisted});

  static Future<int> bulkImport({required String orgId, required List<Map<String, dynamic>> rows}) async {
    final r = await ApiClient.post('/api/billing/leads/bulk-import',
        body: {'orgId': orgId, 'rows': rows, 'importId': _uuid.v4(), 'assigner': 'round-robin'});
    return (r['imported'] as num?)?.toInt() ?? 0;
  }
}

// ── Shared WhatsApp inbox / chat sessions ──────────────────────────────────
class InboxApi {
  static const _p = '/api/v1/chat-sessions';

  static Future<Map<String, dynamic>> claim(String orgId, String leadId) => ApiClient.post('$_p/claim', body: {'orgId': orgId, 'leadId': leadId});
  static Future<Map<String, dynamic>> release(String orgId, String leadId, {String? summary}) =>
      ApiClient.post('$_p/release', body: {'orgId': orgId, 'leadId': leadId, if (summary != null && summary.isNotEmpty) 'summary': summary});
  static Future<void> markRead(String orgId, String leadId) => ApiClient.post('$_p/mark-read', body: {'orgId': orgId, 'leadId': leadId});
  static Future<Map<String, dynamic>> reassign(String orgId, String leadId, String uid, String name) =>
      ApiClient.post('$_p/reassign', body: {'orgId': orgId, 'leadId': leadId, 'newEmployeeId': uid, 'newEmployeeName': name});
  static Future<Map<String, dynamic>> takeover(String orgId, String leadId) =>
      ApiClient.post('$_p/takeover', body: {'orgId': orgId, 'leadId': leadId, 'reason': 'manual_takeover'});
  static Future<Map<String, dynamic>> reEnableAi(String orgId, String leadId) => ApiClient.post('$_p/re-enable-ai', body: {'orgId': orgId, 'leadId': leadId});
  static Future<Map<String, dynamic>> rebuildIndex(String orgId) => ApiClient.post('$_p/rebuild-index', body: {'orgId': orgId});
}

// ── Broadcast ──────────────────────────────────────────────────────────────
class BroadcastApi {
  static const _p = '/api/broadcast';

  static Future<Map<String, dynamic>> preview({required String orgId, Map<String, String>? filters}) =>
      ApiClient.post('$_p/preview', body: {'orgId': orgId, 'filters': filters});

  static Future<Map<String, dynamic>> create({
    required String orgId,
    required String templateId,
    required List<String> parameters,
    Map<String, String>? filters,
    String? name,
    DateTime? scheduledAt,
  }) =>
      ApiClient.post('$_p/create', body: {
        'orgId': orgId,
        'templateId': templateId,
        'parameters': parameters,
        'filters': (filters == null || filters.isEmpty) ? null : filters,
        'leadIds': null,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'scheduledAtMs': scheduledAt?.millisecondsSinceEpoch,
      });

  static Future<List<Map<String, dynamic>>> list(String orgId) async => _list((await ApiClient.get('$_p/list', query: {'orgId': orgId}))['broadcasts']);
  static Future<Map<String, dynamic>> analytics(String orgId) => ApiClient.get('$_p/analytics', query: {'orgId': orgId});
  static Future<Map<String, dynamic>> status(String id) => ApiClient.get('$_p/status', query: {'broadcastId': id});
  static Future<Map<String, dynamic>> recipients(String id, {String? status}) =>
      ApiClient.get('$_p/recipients', query: {'broadcastId': id, 'status': status, 'limit': 200});
  static Future<Map<String, dynamic>> retry(String orgId, String id) => ApiClient.post('$_p/retry', body: {'orgId': orgId, 'broadcastId': id});
  static Future<void> cancel(String orgId, String id) => ApiClient.post('$_p/cancel', body: {'orgId': orgId, 'broadcastId': id});
}

// ── Internal tickets ───────────────────────────────────────────────────────
class TicketsApi {
  static const _p = '/api/v1/org-tickets';
  static Future<List<Map<String, dynamic>>> list(String orgId) async => _list((await ApiClient.get('$_p/list', query: {'orgId': orgId}))['tickets']);
  static Future<Map<String, dynamic>> create({required String orgId, required String subject, required String description, String priority = 'medium'}) =>
      ApiClient.post('$_p/create', body: {'orgId': orgId, 'subject': subject, 'description': description, 'priority': priority});
  static Future<Map<String, dynamic>> reply(String orgId, String id, String text) => ApiClient.post('$_p/$id/reply', body: {'orgId': orgId, 'text': text});
  static Future<void> setStatus(String orgId, String id, String status) => ApiClient.post('$_p/$id/status', body: {'orgId': orgId, 'status': status});
}

// ── Product catalogue ──────────────────────────────────────────────────────
class ProductsApi {
  static const _p = '/api/v1/ai/catalogue';
  static Future<List<Map<String, dynamic>>> list(String orgId) async => _list((await ApiClient.get(_p, query: {'orgId': orgId}))['products']);
  static Future<Map<String, dynamic>> stats(String orgId) => ApiClient.get('$_p/stats', query: {'orgId': orgId});
  static Future<Map<String, dynamic>> create(String orgId, Map<String, dynamic> product) => ApiClient.post(_p, body: {'orgId': orgId, ...product});
  static Future<Map<String, dynamic>> update(String orgId, String id, Map<String, dynamic> product) => ApiClient.patch('$_p/$id', body: {'orgId': orgId, ...product});
  static Future<void> delete(String orgId, String id) => ApiClient.delete('$_p/$id', query: {'orgId': orgId});
}

// ── AI customer care ───────────────────────────────────────────────────────
class AiApi {
  static const _p = '/api/v1/ai';
  static Future<Map<String, dynamic>> config(String orgId) => ApiClient.get('$_p/config', query: {'orgId': orgId});
  static Future<Map<String, dynamic>> saveConfig(String orgId, Map<String, dynamic> cfg) {
    final body = Map<String, dynamic>.from(cfg)
      ..remove('configured')
      ..remove('updatedAt')
      ..remove('updatedBy');
    body['orgId'] = orgId;
    return ApiClient.patch('$_p/config', body: body);
  }

  static Future<List<Map<String, dynamic>>> articles(String orgId) async => _list((await ApiClient.get('$_p/knowledge-base', query: {'orgId': orgId}))['articles']);
  static Future<Map<String, dynamic>> kbStats(String orgId) => ApiClient.get('$_p/knowledge-base/stats', query: {'orgId': orgId});
  static Future<Map<String, dynamic>> createArticle(String orgId, Map<String, dynamic> a) => ApiClient.post('$_p/knowledge-base', body: {'orgId': orgId, ...a});
  static Future<Map<String, dynamic>> updateArticle(String orgId, String id, Map<String, dynamic> a) =>
      ApiClient.patch('$_p/knowledge-base/$id', body: {'orgId': orgId, ...a});
  static Future<void> deleteArticle(String orgId, String id) => ApiClient.delete('$_p/knowledge-base/$id', query: {'orgId': orgId});
  static Future<Map<String, dynamic>> test(String orgId, String message) => ApiClient.post('$_p/test', body: {'orgId': orgId, 'message': message});
  static Future<Map<String, dynamic>> usage(String orgId, {int days = 30}) => ApiClient.get('$_p/usage', query: {'orgId': orgId, 'days': days});
}

// ── Workflows ──────────────────────────────────────────────────────────────
class WorkflowApi {
  static const _p = '/api/v1/workflows';
  static Future<List<Map<String, dynamic>>> list(String orgId) async => _list((await ApiClient.get(_p, query: {'orgId': orgId}))['workflows']);
  static Future<Map<String, dynamic>> create(String orgId, {required String name, String description = '', required String triggerType, int priority = 100}) async =>
      Map<String, dynamic>.from((await ApiClient.post(_p, body: {
        'orgId': orgId,
        'name': name,
        'description': description,
        'triggerType': triggerType,
        'priority': priority,
      }))['workflow'] as Map);
  static Future<Map<String, dynamic>> get(String orgId, String id) => ApiClient.get('$_p/$id', query: {'orgId': orgId});
  static Future<Map<String, dynamic>> update(String orgId, String id, Map<String, dynamic> fields) => ApiClient.patch('$_p/$id', body: {'orgId': orgId, ...fields});
  static Future<Map<String, dynamic>> setStatus(String orgId, String id, String status) => ApiClient.post('$_p/$id/status', body: {'orgId': orgId, 'status': status});
  static Future<Map<String, dynamic>> saveDraft(String orgId, String id, Map<String, dynamic> definition, {String? note}) =>
      ApiClient.post('$_p/$id/draft', body: {'orgId': orgId, 'definition': definition, if (note != null && note.isNotEmpty) 'changeNote': note});
  static Future<Map<String, dynamic>> publish(String orgId, String id) => ApiClient.post('$_p/$id/publish', body: {'orgId': orgId});
  static Future<Map<String, dynamic>> rollback(String orgId, String id, int version) => ApiClient.post('$_p/$id/rollback', body: {'orgId': orgId, 'toVersion': version});
  static Future<Map<String, dynamic>> testRun(String orgId, String id, Map<String, dynamic> sample) =>
      ApiClient.post('$_p/$id/test-run', body: {'orgId': orgId, 'sampleEntity': sample});
  static Future<List<Map<String, dynamic>>> runs(String orgId, String id) async =>
      _list((await ApiClient.get('$_p/$id/runs', query: {'orgId': orgId, 'limit': 25}))['runs']);
}

// ── Integrations (WhatsApp, website, ads) ──────────────────────────────────
class IntegrationsApi {
  static Future<Map<String, dynamic>> whatsappStatus(String orgId) => ApiClient.post('/api/whatsapp/status', body: {'orgId': orgId});
  static Future<Map<String, dynamic>> whatsappSync(String orgId) => ApiClient.post('/api/whatsapp/sync-now', body: {'orgId': orgId});
  static Future<Map<String, dynamic>> whatsappRepair(String orgId) => ApiClient.post('/api/whatsapp/repair-webhook', body: {'orgId': orgId});
  static Future<void> whatsappDisconnect(String orgId) => ApiClient.post('/api/whatsapp/disconnect', body: {'orgId': orgId});
  static Future<Map<String, dynamic>> templatesSync(String orgId) => ApiClient.post('/api/whatsapp/templates/sync', body: {'orgId': orgId});

  static Future<Map<String, dynamic>> websiteIntegration(String orgId) => ApiClient.get('/api/leads/integrations', query: {'orgId': orgId});
  static Future<Map<String, dynamic>> createWebsiteIntegration(String orgId, {List<String> domains = const [], String? title}) =>
      ApiClient.post('/api/leads/integrations', body: {'orgId': orgId, 'allowedDomains': domains, if (title != null && title.isNotEmpty) 'formTitle': title});
  static Future<Map<String, dynamic>> websiteKey(String orgId) => ApiClient.post('/api/leads/website-key', body: {'orgId': orgId});

  static Future<Map<String, dynamic>> adLeadsStatus(String orgId) => ApiClient.get('/api/ad-leads/status', query: {'orgId': orgId});
  static Future<Map<String, dynamic>> googleAdsWebhook(String orgId) => ApiClient.post('/api/ad-leads/google', body: {'orgId': orgId});
  static Future<void> metaDisconnect(String orgId) => ApiClient.post('/api/ad-leads/meta/disconnect', body: {'orgId': orgId});
}

// ── Automation / follow-ups ────────────────────────────────────────────────
class AutomationApi {
  static Future<Map<String, dynamic>> runNow(String orgId) => ApiClient.post('/api/follow-ups/run-automation', body: {'orgId': orgId});
}

// ── Voice ──────────────────────────────────────────────────────────────────
class VoiceApi {
  static Future<Map<String, dynamic>> status(String orgId) => ApiClient.get('/api/v1/voice/status', query: {'orgId': orgId});
}

// ── Support (AI help desk) ─────────────────────────────────────────────────
class SupportApi {
  static Future<String> chat(String message, List<Map<String, String>> history) async {
    final r = await ApiClient.post('/api/v1/support/chat', body: {'message': message, 'history': history});
    return r['reply']?.toString() ?? '';
  }

  static Future<void> ticket({required String subject, required String description, List<Map<String, String>> history = const []}) =>
      ApiClient.post('/api/v1/support/ticket', body: {'subject': subject, 'description': description, 'conversationHistory': history});
}

// ── Devices (push) ─────────────────────────────────────────────────────────
class DevicesApi {
  static Future<void> register({required String token, required String platform, String? appVersion, String? orgId}) =>
      ApiClient.post('/api/v1/devices/register', body: {'token': token, 'platform': platform, 'appVersion': appVersion, 'orgId': orgId});
  static Future<void> unregister(String token) => ApiClient.post('/api/v1/devices/unregister', body: {'token': token});
}
