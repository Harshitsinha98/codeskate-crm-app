import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_member_model.dart';
import 'auth_provider.dart';

/// Live team roster (memberships) plus pending invites for admins —
/// same queries as the web CRM's TeamContext.
class TeamProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthProvider? _auth;
  List<TeamMemberModel> _members = [];
  List<TeamMemberModel> _invites = [];
  bool _isLoading = false;

  StreamSubscription? _subscription;
  StreamSubscription? _invitesSub;

  List<TeamMemberModel> get members => _members;
  List<TeamMemberModel> get activeMembers => _members.where((m) => m.active).toList();
  List<TeamMemberModel> get employees => _members.where((m) => !m.isAdmin).toList();

  /// Invites whose phone isn't already a member.
  List<TeamMemberModel> get pendingInvites {
    final phones = _members.map((m) => _last10(m.phone)).toSet();
    return _invites.where((i) => !phones.contains(_last10(i.phone))).toList();
  }

  bool get isLoading => _isLoading;

  static String _last10(String? p) {
    final d = (p ?? '').replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  void updateAuth(AuthProvider auth) {
    final changed = _auth?.user?.activeOrgId != auth.user?.activeOrgId ||
        _auth?.user?.activeOrgRole != auth.user?.activeOrgRole;
    _auth = auth;
    if (changed) _startListening();
  }

  void _startListening() {
    _subscription?.cancel();
    _invitesSub?.cancel();
    _invites = [];

    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null) {
      _members = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _db
        .collection('memberships')
        .where('orgId', isEqualTo: orgId)
        .where('active', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        _members = snapshot.docs.map((doc) {
          final data = doc.data();
          return TeamMemberModel(
            id: data['uid'] ?? doc.id,
            uid: data['uid'],
            phone: data['phone'],
            name: data['displayName'] ?? data['name'] ?? 'Team Member',
            email: data['email'],
            role: data['role'] ?? 'employee',
            active: data['active'] ?? true,
            pending: false,
          );
        }).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Team listener error: $e');
        _isLoading = false;
        notifyListeners();
      },
    );

    if (_auth?.user?.isAdmin ?? false) {
      _invitesSub = _db
          .collection('invites')
          .where('orgId', isEqualTo: orgId)
          .where('active', isEqualTo: true)
          .snapshots()
          .listen((snap) {
        _invites = snap.docs.map((d) {
          final data = d.data();
          return TeamMemberModel(
            id: d.id,
            phone: data['phone'],
            name: data['displayName'] ?? data['name'] ?? 'Invited member',
            email: data['email'],
            role: data['role'] ?? 'employee',
            active: true,
            pending: true,
          );
        }).toList();
        notifyListeners();
      }, onError: (e) => debugPrint('Invites listener error: $e'));
    }
  }

  TeamMemberModel? getMemberById(String id) {
    for (final m in _members) {
      if (m.id == id || m.uid == id) return m;
    }
    return null;
  }

  String getMemberName(String? uid) {
    if (uid == null) return 'Unassigned';
    return getMemberById(uid)?.name ?? 'Unknown';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _invitesSub?.cancel();
    super.dispose();
  }
}
