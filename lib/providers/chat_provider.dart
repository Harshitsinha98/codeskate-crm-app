import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import 'auth_provider.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthProvider? _auth;
  Map<String, List<MessageModel>> _conversations = {};
  List<Map<String, dynamic>> _conversationList = [];
  bool _isLoading = false;
  String? _activeLeadId;

  StreamSubscription? _messagesSubscription;

  Map<String, List<MessageModel>> get conversations => _conversations;
  List<Map<String, dynamic>> get conversationList => _conversationList;
  bool get isLoading => _isLoading;
  String? get activeLeadId => _activeLeadId;

  List<MessageModel> getMessages(String leadId) => _conversations[leadId] ?? [];

  void updateAuth(AuthProvider auth) {
    if (_auth?.user?.activeOrgId != auth.user?.activeOrgId) {
      _auth = auth;
      _conversations = {};
      _conversationList = [];
      notifyListeners();
    } else {
      _auth = auth;
    }
  }

  /// Load conversations list (leads with WhatsApp messages)
  Future<void> loadConversations() async {
    final orgId = _auth?.user?.activeOrgId;
    final uid = _auth?.user?.uid;
    if (orgId == null || uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final isAdmin = _auth?.user?.isAdmin ?? false;
      final leadsRef = _db.collection('organizations').doc(orgId).collection('leads');

      final query = isAdmin
          ? leadsRef.orderBy('lastContactAt', descending: true).limit(50)
          : leadsRef.where('assignedTo', isEqualTo: uid);

      final snapshot = await query.get();

      _conversationList = snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['lastContactAt'] != null || data['phone'] != null;
          })
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Load conversations error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Open a conversation and listen to messages
  void openConversation(String leadId) {
    _messagesSubscription?.cancel();
    _activeLeadId = leadId;

    final orgId = _auth?.user?.activeOrgId;
    if (orgId == null) return;

    _messagesSubscription = _db
        .collection('organizations')
        .doc(orgId)
        .collection('leads')
        .doc(leadId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        _conversations[leadId] = snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Messages listener error: $e');
      },
    );
  }

  void closeConversation() {
    _messagesSubscription?.cancel();
    _activeLeadId = null;
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
