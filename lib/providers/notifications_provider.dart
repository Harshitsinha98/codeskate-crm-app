import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/activity_model.dart';
import 'auth_provider.dart';

class NotificationsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthProvider? _auth;
  List<NotificationModel> _notifications = [];
  List<ActivityModel> _activity = [];
  bool _isLoading = false;

  StreamSubscription? _subscription;
  StreamSubscription? _activitySub;

  List<NotificationModel> get notifications => _notifications;
  List<NotificationModel> get unreadNotifications =>
      _notifications.where((n) => !n.read).toList();
  int get unreadCount => _notifications.where((n) => !n.read).length;
  bool get isLoading => _isLoading;
  bool get hasUnread => unreadCount > 0;

  /// Recent org-wide activity (admin/owner only, up to 50 items).
  List<ActivityModel> get activity => _activity;

  void updateAuth(AuthProvider auth) {
    if (_auth?.user?.activeOrgId != auth.user?.activeOrgId ||
        _auth?.user?.uid != auth.user?.uid) {
      _auth = auth;
      _startListening();
    } else {
      _auth = auth;
    }
  }

  void _startListening() {
    _subscription?.cancel();
    _activitySub?.cancel();

    final orgId = _auth?.user?.activeOrgId;
    final uid = _auth?.user?.uid;
    if (orgId == null || uid == null) {
      _notifications = [];
      _activity = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Unread notifications for this user.
    _subscription = _db
        .collection('organizations')
        .doc(orgId)
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        _notifications = snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000)));
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Notifications listener error: $e');
        _isLoading = false;
        notifyListeners();
      },
    );

    // Activity stream (admin/owner only — mirrors web CRM NotificationsContext).
    final role = _auth?.user?.activeOrgRole;
    final isAdmin = role == 'admin' || role == 'owner';
    if (isAdmin) {
      _activitySub = _db
          .collection('organizations')
          .doc(orgId)
          .collection('activity')
          .orderBy('at', descending: true)
          .limit(50)
          .snapshots()
          .listen(
        (snapshot) {
          _activity = snapshot.docs
              .map((doc) => ActivityModel.fromFirestore(doc))
              .toList();
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Activity listener error: $e');
        },
      );
    } else {
      _activity = [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null) return;

    try {
      await _db
          .collection('organizations')
          .doc(orgId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Mark read error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final orgId = _auth?.user?.activeOrgId;
    final uid = _auth?.user?.uid;
    if (orgId == null || uid == null) return;

    try {
      final batch = _db.batch();
      for (final notif in _notifications.where((n) => !n.read)) {
        batch.update(
          _db.collection('organizations').doc(orgId).collection('notifications').doc(notif.id),
          {'read': true},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Mark all read error: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _activitySub?.cancel();
    super.dispose();
  }
}
