import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_model.dart';
import '../models/followup_model.dart';
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
