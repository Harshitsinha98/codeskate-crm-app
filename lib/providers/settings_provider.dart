import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

class SettingsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthProvider? _auth;
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _goals = {};
  bool _isLoading = false;

  StreamSubscription? _settingsSubscription;
  StreamSubscription? _goalsSubscription;

  Map<String, dynamic> get settings => _settings;
  Map<String, dynamic> get goals => _goals;
  bool get isLoading => _isLoading;

  List<String> get statuses => List<String>.from(
      _settings['statuses'] ?? ['New', 'Ringing', 'Meeting Fixed', 'Negotiation', 'Follow-up', 'Closed-Won', 'Lost']);

  String get autoAssignMode => _settings['autoAssign'] ?? 'round-robin';

  void updateAuth(AuthProvider auth) {
    if (_auth?.user?.activeOrgId != auth.user?.activeOrgId) {
      _auth = auth;
      _startListening();
    } else {
      _auth = auth;
    }
  }

  void _startListening() {
    _settingsSubscription?.cancel();
    _goalsSubscription?.cancel();

    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null) {
      _settings = {};
      _goals = {};
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _settingsSubscription = _db
        .collection('organizations')
        .doc(orgId)
        .collection('settings')
        .doc('config')
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          _settings = snapshot.data() ?? {};
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Settings listener error: $e');
        _isLoading = false;
        notifyListeners();
      },
    );

    if (_auth?.user?.isAdmin ?? false) {
      _goalsSubscription = _db
          .collection('organizations')
          .doc(orgId)
          .collection('goals')
          .doc('config')
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists) {
            _goals = snapshot.data() ?? {};
          }
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Goals listener error: $e');
        },
      );
    }
  }

  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null) return;

    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('settings')
        .doc('config')
        .set(newSettings, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _goalsSubscription?.cancel();
    super.dispose();
  }
}
