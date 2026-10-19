import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../services/crm_api.dart';
import 'auth_provider.dart';

/// One row of the shared WhatsApp inbox (organizations/{org}/conversations).
class ConversationSummary {
  final String leadId;
  final String leadName;
  final String phone;
  final String lastMessage;
  final String? lastMessageType;
  final String? lastDirection;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? assignedTo;
  final String? assignedToName;
  final String? status;
  final bool aiEnabled;
  final String? holderUid;
  final String? holderName;
  final String? lastSenderName;

  ConversationSummary({
    required this.leadId,
    required this.leadName,
    required this.phone,
    required this.lastMessage,
    this.lastMessageType,
    this.lastDirection,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.assignedTo,
    this.assignedToName,
    this.status,
    this.aiEnabled = true,
    this.holderUid,
    this.holderName,
    this.lastSenderName,
  });

  factory ConversationSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final ms = (m['lastMessageAtMs'] as num?)?.toInt();
    return ConversationSummary(
      leadId: (m['leadId'] ?? d.id).toString(),
      leadName: (m['leadName'] ?? m['phone'] ?? 'Customer').toString(),
      phone: (m['phone'] ?? '').toString(),
      lastMessage: (m['lastMessage'] ?? '').toString(),
      lastMessageType: m['lastMessageType']?.toString(),
      lastDirection: m['lastDirection']?.toString(),
      lastMessageAt: ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : DateTime.tryParse('${m['lastMessageAt'] ?? ''}'),
      unreadCount: (m['unreadCount'] as num?)?.toInt() ?? 0,
      assignedTo: m['assignedTo']?.toString(),
      assignedToName: m['assignedToName']?.toString(),
      status: m['status']?.toString(),
      aiEnabled: m['aiEnabled'] != false,
      holderUid: m['activeChatSessionEmployee']?.toString(),
      holderName: m['activeChatSessionEmployeeName']?.toString(),
      lastSenderName: m['lastSenderName']?.toString(),
    );
  }

  bool get isClaimed => holderUid != null && holderUid!.isNotEmpty;
}

enum InboxFilter { unclaimed, mine, unread, ai, all }

extension InboxFilterX on InboxFilter {
  String get label => switch (this) {
        InboxFilter.unclaimed => 'Unclaimed',
        InboxFilter.mine => 'Mine',
        InboxFilter.unread => 'Unread',
        InboxFilter.ai => 'AI handling',
        InboxFilter.all => 'All',
      };
}

/// Shared WhatsApp mailbox — mirrors the web Team Inbox: live conversation
/// index + claim / release / reassign so only one agent replies at a time.
class InboxProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  AuthProvider? _auth;
  StreamSubscription? _sub;

  List<ConversationSummary> _items = [];
  bool _loading = false;
  String? _error;
  final Set<String> _busy = {};

  List<ConversationSummary> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  bool isBusy(String leadId) => _busy.contains(leadId);

  String? get _uid => _auth?.user?.uid;
  String? get _orgId => _auth?.user?.activeOrgId;

  int get totalUnread => _items.fold(0, (s, c) => s + c.unreadCount);

  void updateAuth(AuthProvider auth) {
    final changed = _auth?.user?.activeOrgId != auth.user?.activeOrgId;
    _auth = auth;
    if (changed) _listen();
  }

  void _listen() {
    _sub?.cancel();
    _items = [];
    final orgId = _orgId;
    if (orgId == null) {
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    _sub = _db
        .collection('organizations')
        .doc(orgId)
        .collection('conversations')
        .orderBy('lastMessageAtMs', descending: true)
        .limit(300)
        .snapshots()
        .listen((snap) {
      _items = snap.docs.map(ConversationSummary.fromDoc).toList();
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Inbox listener error: $e');
      _loading = false;
      _error = 'Could not load the shared inbox.';
      notifyListeners();
    });
  }

  bool isMine(ConversationSummary c) => c.holderUid == _uid || (c.assignedTo == _uid && !c.isClaimed);

  List<ConversationSummary> filtered(InboxFilter f, String query) {
    final q = query.trim().toLowerCase();
    return _items.where((c) {
      final ok = switch (f) {
        InboxFilter.unclaimed => !c.isClaimed,
        InboxFilter.mine => isMine(c),
        InboxFilter.unread => c.unreadCount > 0,
        InboxFilter.ai => c.aiEnabled && !c.isClaimed,
        InboxFilter.all => true,
      };
      if (!ok) return false;
      if (q.isEmpty) return true;
      return c.leadName.toLowerCase().contains(q) || c.phone.contains(q) || c.lastMessage.toLowerCase().contains(q);
    }).toList();
  }

  Map<InboxFilter, int> counts() => {
        InboxFilter.unclaimed: _items.where((c) => !c.isClaimed).length,
        InboxFilter.mine: _items.where(isMine).length,
        InboxFilter.unread: _items.where((c) => c.unreadCount > 0).length,
        InboxFilter.ai: _items.where((c) => c.aiEnabled && !c.isClaimed).length,
      };

  ConversationSummary? byLead(String leadId) {
    for (final c in _items) {
      if (c.leadId == leadId) return c;
    }
    return null;
  }

  Future<String?> _run(String leadId, Future<void> Function(String orgId) fn) async {
    final orgId = _orgId;
    if (orgId == null) return 'Not signed in';
    _busy.add(leadId);
    notifyListeners();
    try {
      await fn(orgId);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _busy.remove(leadId);
      notifyListeners();
    }
  }

  Future<String?> claim(String leadId) => _run(leadId, (o) => InboxApi.claim(o, leadId));
  Future<String?> release(String leadId, {String? summary}) => _run(leadId, (o) => InboxApi.release(o, leadId, summary: summary));
  Future<String?> reassign(String leadId, String uid, String name) => _run(leadId, (o) => InboxApi.reassign(o, leadId, uid, name));
  Future<String?> reEnableAi(String leadId) => _run(leadId, (o) => InboxApi.reEnableAi(o, leadId));
  Future<String?> rebuild() => _run('_index', (o) => InboxApi.rebuildIndex(o));

  Future<void> markRead(String leadId) async {
    final orgId = _orgId;
    final c = byLead(leadId);
    if (orgId == null || c == null || c.unreadCount == 0) return;
    try {
      await InboxApi.markRead(orgId, leadId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
