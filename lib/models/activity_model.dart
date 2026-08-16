import 'package:cloud_firestore/cloud_firestore.dart';

/// A single entry in the organization's activity stream.
/// Firestore path: organizations/{orgId}/activity/{docId}
/// Server-authored (the app only reads, never writes).
class ActivityModel {
  final String id;
  final String text;
  final DateTime? at;
  final String? type; // e.g. 'lead_created', 'status_changed', 'call_logged'
  final String? userId;
  final String? userName;
  final String? leadId;
  final String? leadName;

  ActivityModel({
    required this.id,
    required this.text,
    this.at,
    this.type,
    this.userId,
    this.userName,
    this.leadId,
    this.leadName,
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ActivityModel(
      id: doc.id,
      text: d['text']?.toString() ?? '',
      at: _parseDate(d['at']),
      type: d['type']?.toString(),
      userId: d['userId']?.toString(),
      userName: d['userName']?.toString(),
      leadId: d['leadId']?.toString(),
      leadName: d['leadName']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
