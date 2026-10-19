/// Workflow vocabulary — mirrors whatsapp-backend/src/validators/workflow.schema.js
/// and lead-erp/src/data/workflowVocabulary.js.
class WfVocab {
  static const triggers = {
    'lead_created': 'New lead is created',
    'lead_updated': 'Lead is updated',
    'reminder_missed': 'Follow-up is missed',
    'whatsapp_message_received': 'WhatsApp message received',
    'ticket_closed': 'Ticket is closed',
  };

  static const conditionTypes = {
    'lead_source': 'Lead source',
    'status': 'Status',
    'employee': 'Assigned employee',
    'city': 'City',
    'product': 'Product',
    'organization': 'Branch',
    'tags': 'Tags',
  };

  static const scalarOps = {
    'equals': 'is',
    'not_equals': 'is not',
    'in': 'is any of',
    'not_in': 'is none of',
    'contains': 'contains',
    'not_contains': 'does not contain',
    'changed_to': 'changed to',
    'changed_from': 'changed from',
    'is_empty': 'is empty',
    'is_not_empty': 'is not empty',
  };

  static const arrayOps = {
    'contains': 'contains',
    'not_contains': 'does not contain',
    'contains_any': 'contains any of',
    'contains_all': 'contains all of',
    'is_empty': 'is empty',
    'is_not_empty': 'is not empty',
  };

  static Map<String, String> opsFor(String type) => type == 'tags' ? arrayOps : scalarOps;
  static bool needsValue(String op) => op != 'is_empty' && op != 'is_not_empty';
  static bool listValue(String op) => const {'in', 'not_in', 'contains_any', 'contains_all'}.contains(op);

  static const actions = {
    'assign': 'Assign lead',
    'reassign': 'Reassign lead',
    'reminder': 'Create follow-up',
    'whatsapp_template': 'Send WhatsApp template',
    'update_status': 'Change status',
    'email': 'Send email',
    'activity': 'Log activity',
    'escalation': 'Escalate / notify',
  };

  static const taskTypes = ['Call', 'WhatsApp', 'Meeting', 'Email', 'Other'];

  static Map<String, dynamic> defaultParams(String type) => switch (type) {
        'assign' => {'strategy': 'round_robin'},
        'reassign' => {'strategy': 'round_robin', 'reason': ''},
        'reminder' => {'afterMinutes': 60, 'taskType': 'Call', 'title': ''},
        'whatsapp_template' => {'templateId': '', 'parameters': <String>[]},
        'update_status' => {'status': 'Follow-up'},
        'email' => {'to': 'assignee', 'subject': '', 'body': ''},
        'activity' => {'text': ''},
        'escalation' => {'escalateTo': 'admins', 'message': ''},
        _ => {},
      };

  static String describeAction(Map<String, dynamic> a) {
    final p = Map<String, dynamic>.from(a['params'] ?? {});
    return switch (a['type']) {
      'assign' || 'reassign' => '${actions[a['type']]} · ${'${p['strategy']}'.replaceAll('_', ' ')}',
      'reminder' => 'Follow-up (${p['taskType']}) after ${p['afterMinutes']} min',
      'whatsapp_template' => 'Send template',
      'update_status' => 'Set status → ${p['status']}',
      'email' => 'Email ${p['to']}: ${p['subject']}',
      'activity' => 'Log: ${p['text']}',
      'escalation' => 'Notify ${p['escalateTo']}: ${p['message']}',
      _ => '${a['type']}',
    };
  }
}
