import 'package:cloud_firestore/cloud_firestore.dart';

class LeadModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String status;
  final String? priority;
  final String? assignedTo;
  final String? assignedToName;
  final String? source;
  final String? campaign;
  final String? notes;
  final bool blacklisted;
  final bool aiEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastContactAt;
  final Map<String, dynamic>? metadata;

  LeadModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.status = 'New',
    this.priority,
    this.assignedTo,
    this.assignedToName,
    this.source,
    this.campaign,
    this.notes,
    this.blacklisted = false,
    this.aiEnabled = true,
    this.createdAt,
    this.updatedAt,
    this.lastContactAt,
    this.metadata,
  });

  factory LeadModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeadModel(
      id: doc.id,
      name: data['name'] ?? data['leadName'] ?? 'Unknown',
      phone: data['phone'] ?? data['leadPhone'] ?? '',
      email: data['email'],
      status: data['status'] ?? 'New',
      priority: data['priority'],
      assignedTo: data['assignedTo'],
      assignedToName: data['assignedToName'],
      source: data['source'],
      campaign: data['campaign'],
      notes: data['notes'],
      blacklisted: data['blacklisted'] ?? false,
      aiEnabled: data['aiEnabled'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastContactAt: _parseTimestamp(data['lastContactAt']),
      metadata: data['metadata'],
    );
  }

  factory LeadModel.fromMap(Map<String, dynamic> data, String id) {
    return LeadModel(
      id: id,
      name: data['name'] ?? data['leadName'] ?? 'Unknown',
      phone: data['phone'] ?? data['leadPhone'] ?? '',
      email: data['email'],
      status: data['status'] ?? 'New',
      priority: data['priority'],
      assignedTo: data['assignedTo'],
      assignedToName: data['assignedToName'],
      source: data['source'],
      campaign: data['campaign'],
      notes: data['notes'],
      blacklisted: data['blacklisted'] ?? false,
      aiEnabled: data['aiEnabled'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastContactAt: _parseTimestamp(data['lastContactAt']),
      metadata: data['metadata'],
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  bool get isHot => priority == 'Hot' || priority == 'high';
  bool get isClosed => status == 'Closed-Won' || status == 'Lost';
}
