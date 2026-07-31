import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_member_model.dart';
import 'auth_provider.dart';

class TeamProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthProvider? _auth;
  List<TeamMemberModel> _members = [];
  bool _isLoading = false;

  StreamSubscription? _subscription;

  List<TeamMemberModel> get members => _members;
  List<TeamMemberModel> get activeMembers =>
      _members.where((m) => m.active).toList();
  bool get isLoading => _isLoading;

  void updateAuth(AuthProvider auth) {
    if (_auth?.user?.activeOrgId != auth.user?.activeOrgId) {
      _auth = auth;
      _startListening();
    } else {
      _auth = auth;
    }
  }

  void _startListening() {
    _subscription?.cancel();

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
        }).toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Team listener error: $e');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  TeamMemberModel? getMemberById(String id) {
    try {
      return _members.firstWhere((m) => m.id == id || m.uid == id);
    } catch (_) {
      return null;
    }
  }

  String getMemberName(String? uid) {
    if (uid == null) return 'Unassigned';
    final member = getMemberById(uid);
    return member?.name ?? 'Unknown';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
