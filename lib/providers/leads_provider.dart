import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_model.dart';
import '../models/followup_model.dart';
import '../models/note_model.dart';
import '../services/crm_service.dart';
import 'auth_provider.dart';

class LeadsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthProvider? _auth;
  List<LeadModel> _leads = [];
  List<FollowUpModel> _followUps = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _leadsSubscription;
  StreamSubscription? _followUpsSubscription;

  List<LeadModel> get leads => _leads;
  List<FollowUpModel> get followUps => _followUps;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Dashboard stats
  int get totalLeads => _leads.length;
  int get newLeads => _leads.where((l) => l.status == 'New').length;
  int get hotLeads => _leads.where((l) => l.isHot).length;
  int get closedWon => _leads.where((l) => l.status == 'Closed-Won').length;
  int get lostLeads => _leads.where((l) => l.status == 'Lost').length;
  int get activeFollowUps => _followUps.where((f) => f.isOpen).length;
  int get overdueFollowUps => _followUps.where((f) => f.isOverdue).length;
  int get todayFollowUps => _followUps.where((f) => f.isDueToday && f.isOpen).length;

  Map<String, int> get statusDistribution {
    final map = <String, int>{};
    for (final lead in _leads) {
      map[lead.status] = (map[lead.status] ?? 0) + 1;
    }
    return map;
  }

  void updateAuth(AuthProvider auth) {
    if (_auth?.user?.activeOrgId != auth.user?.activeOrgId) {
      _auth = auth;
      _startListening();
    } else {
      _auth = auth;
    }
  }

  void _startListening() {
    _leadsSubscription?.cancel();
    _followUpsSubscription?.cancel();

    final orgId = _auth?.user?.activeOrgId;
    final uid = _auth?.user?.uid;
    if (orgId == null || uid == null) {
      _leads = [];
      _followUps = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final isAdmin = _auth?.user?.isAdmin ?? false;
    final leadsRef = _db.collection('organizations').doc(orgId).collection('leads');

    // Leads query
    final leadsQuery = isAdmin
        ? leadsRef.orderBy('createdAt', descending: true).limit(200)
        : leadsRef.where('assignedTo', isEqualTo: uid);

    _leadsSubscription = leadsQuery.snapshots().listen(
      (snapshot) {
        _leads = snapshot.docs.map((doc) => LeadModel.fromFirestore(doc)).toList();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Leads listener error: $e');
        _error = 'Failed to load leads';
        _isLoading = false;
        notifyListeners();
      },
    );

    // Follow-ups query
    final tasksRef = _db.collection('organizations').doc(orgId).collection('followUpTasks');
    final tasksQuery = isAdmin
        ? tasksRef.where('status', isEqualTo: 'open')
        : tasksRef.where('assignedTo', isEqualTo: uid);

    _followUpsSubscription = tasksQuery.snapshots().listen(
      (snapshot) {
        _followUps = snapshot.docs
            .map((doc) => FollowUpModel.fromFirestore(doc))
            .toList();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Follow-ups listener error: $e');
      },
    );
  }

  LeadModel? getLeadById(String leadId) {
    try {
      return _leads.firstWhere((l) => l.id == leadId);
    } catch (_) {
      return null;
    }
  }

  List<LeadModel> getLeadsByStatus(String status) {
    return _leads.where((l) => l.status == status).toList();
  }

  List<LeadModel> searchLeads(String query) {
    final q = query.toLowerCase();
    return _leads.where((l) =>
        l.name.toLowerCase().contains(q) ||
        l.phone.contains(q) ||
        (l.email?.toLowerCase().contains(q) ?? false)).toList();
  }

  List<FollowUpModel> getFollowUpsForLead(String leadId) {
    return _followUps.where((f) => f.leadId == leadId).toList();
  }

  FollowUpModel? openFollowUpForLead(String leadId) {
    for (final f in _followUps) {
      if (f.leadId == leadId && f.isOpen) return f;
    }
    return null;
  }

  // ── Notes ────────────────────────────────────────────────────────────────

  /// Live notes for a lead, newest first. Employees may only read team
  /// worknotes (Firestore rules), so their query is constrained to match.
  Stream<List<NoteModel>> notesStream(String leadId) {
    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null) return const Stream.empty();
    Query<Map<String, dynamic>> q = _db
        .collection('organizations')
        .doc(orgId)
        .collection('leads')
        .doc(leadId)
        .collection('notes');
    if (!(_auth?.user?.isAdmin ?? false)) {
      q = q.where('visibility', isEqualTo: 'team').where('type', isEqualTo: 'worknote');
    }
    return q.snapshots().map((snap) {
      final notes = snap.docs.map(NoteModel.fromFirestore).toList();
      notes.sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
      return notes;
    });
  }

  /// Adds a team-visible worknote (allowed client-side by Firestore rules
  /// for admins and for the lead's assignee).
  Future<String?> addNote(String leadId, String text) async {
    final user = _auth?.user;
    final orgId = user?.activeOrgId;
    final trimmed = text.trim();
    if (user == null || orgId == null) return 'Not signed in';
    if (trimmed.isEmpty) return 'Note cannot be empty';
    try {
      await _db
          .collection('organizations')
          .doc(orgId)
          .collection('leads')
          .doc(leadId)
          .collection('notes')
          .add({
        'type': 'worknote',
        'text': trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed,
        'authorId': user.uid,
        'authorName': user.name,
        'authorRole': user.activeOrgRole ?? 'employee',
        'visibility': 'team',
        'at': DateTime.now().toUtc().toIso8601String(),
      });
      return null;
    } catch (e) {
      debugPrint('addNote error: $e');
      return 'Could not save note';
    }
  }

  // ── Secured backend workflows ────────────────────────────────────────────

  CrmService? get _crm => _auth == null ? null : CrmService(_auth!.getIdToken);

  /// Returns null on success, or an error message.
  Future<String?> updateLeadStatus(String leadId, String status) async {
    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null || _crm == null) return 'Not signed in';
    final r = await _crm!.updateLeadStatus(orgId: orgId, leadId: leadId, status: status);
    return r.ok ? null : r.error;
  }

  Future<String?> reassignLead(String leadId, String assignedTo) async {
    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null || _crm == null) return 'Not signed in';
    final r = await _crm!.reassignLead(orgId: orgId, leadId: leadId, assignedTo: assignedTo);
    return r.ok ? null : r.error;
  }

  Future<String?> scheduleFollowUp({
    required String leadId,
    required DateTime dueAt,
    required String type,
    String? title,
  }) async {
    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null || _crm == null) return 'Not signed in';
    final r = await _crm!.scheduleFollowUp(
        orgId: orgId, leadId: leadId, dueAt: dueAt, type: type, title: title);
    return r.ok ? null : r.error;
  }

  Future<String?> completeFollowUp({
    required FollowUpModel task,
    required String outcome,
    String? note,
    String? leadStatus,
    DateTime? nextDueAt,
  }) async {
    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null || _crm == null) return 'Not signed in';
    final r = await _crm!.completeFollowUp(
      orgId: orgId,
      taskId: task.id,
      expectedRevision: task.revision,
      outcome: outcome,
      note: note,
      leadStatus: leadStatus,
      nextDueAt: nextDueAt,
    );
    return r.ok ? null : r.error;
  }

  /// Admin-only: create a lead through the quota-enforcing backend.
  Future<String?> createLead({
    required String name,
    required String phone,
    String? email,
    String? requirement,
    String priority = 'Warm',
  }) async {
    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null || _crm == null) return 'Not signed in';
    final r = await _crm!.createManualLead(
      orgId: orgId,
      name: name,
      phone: phone,
      email: email,
      requirement: requirement,
      priority: priority,
    );
    if (!r.ok) return r.error;
    if (r.data['duplicate'] == true) return 'A lead with this phone already exists';
    return null;
  }

  List<FollowUpModel> get overdueFollowUpsList =>
      _followUps.where((f) => f.isOverdue).toList()
        ..sort((a, b) => (a.dueAt ?? DateTime.now()).compareTo(b.dueAt ?? DateTime.now()));

  List<FollowUpModel> get todayFollowUpsList =>
      _followUps.where((f) => f.isDueToday && f.isOpen).toList()
        ..sort((a, b) => (a.dueAt ?? DateTime.now()).compareTo(b.dueAt ?? DateTime.now()));

  @override
  void dispose() {
    _leadsSubscription?.cancel();
    _followUpsSubscription?.cancel();
    super.dispose();
  }
}
