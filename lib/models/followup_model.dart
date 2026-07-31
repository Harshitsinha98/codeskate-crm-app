import 'package:cloud_firestore/cloud_firestore.dart';

class FollowUpModel {
  final String id;
  final String leadId;
  final String? leadName;
  final String? leadPhone;
  final String assignedTo;
  final String? assignedToName;
  final String type; // Call, WhatsApp, Email, Meeting, Visit
  final String status; // open, completed, overdue
  final String? title;
  final String? note;
  final String? outcome;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  FollowUpModel({
    required this.id,
    required this.leadId,
    this.leadName,
    this.leadPhone,
    required this.assignedTo,
    this.assignedToName,
    this.type = 'Call',
    this.status = 'open',
    this.title,
    this.note,
    this.outcome,
    this.dueAt,
    this.completedAt,
    this.createdAt,
  });

  factory FollowUpModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FollowUpModel.fromMap(data, doc.id);
  }

  factory FollowUpModel.fromMap(Map<String, dynamic> data, String id) {
    return FollowUpModel(
      id: id,
      leadId: data['leadId'] ?? '',
      leadName: data['leadName'],
      leadPhone: data['leadPhone'],
      assignedTo: data['assignedTo'] ?? '',
      assignedToName: data['assignedToName'],
      type: data['type'] ?? 'Call',
      status: data['status'] ?? 'open',
      title: data['title'],
      note: data['note'],
      outcome: data['outcome'],
      dueAt: _parseTimestamp(data['dueAt']),
      completedAt: _parseTimestamp(data['completedAt']),
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  bool get isOverdue =>
      status == 'open' && dueAt != null && dueAt!.isBefore(DateTime.now());
  
  bool get isDueToday {
    if (dueAt == null) return false;
    final now = DateTime.now();
    return dueAt!.year == now.year &&
        dueAt!.month == now.month &&
        dueAt!.day == now.day;
  }

  bool get isOpen => status == 'open';
  bool get isCompleted => status == 'completed';
}
