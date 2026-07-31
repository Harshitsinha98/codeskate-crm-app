import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String text;
  final bool read;
  final String? orgId;
  final DateTime? createdAt;
  final String? type;
  final String? leadId;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.text,
    this.read = false,
    this.orgId,
    this.createdAt,
    this.type,
    this.leadId,
    this.data,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      read: map['read'] ?? false,
      orgId: map['orgId'],
      createdAt: _parseTimestamp(map['at'] ?? map['createdAt']),
      type: map['type'],
      leadId: map['leadId'],
      data: map['data'],
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      read: map['read'] ?? false,
      orgId: map['orgId'],
      createdAt: _parseTimestamp(map['at'] ?? map['createdAt']),
      type: map['type'],
      leadId: map['leadId'],
      data: map['data'],
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  NotificationModel copyWith({bool? read}) {
    return NotificationModel(
      id: id,
      userId: userId,
      text: text,
      read: read ?? this.read,
      orgId: orgId,
      createdAt: createdAt,
      type: type,
      leadId: leadId,
      data: data,
    );
  }
}
