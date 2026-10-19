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
  final String? sourceDetail;
  final String? campaign;
  final String? requirement;
  final String? notes;
  final bool blacklisted;
  final bool aiEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastContactAt;
  final DateTime? lastWhatsAppInboundAt;
  final Map<String, dynamic>? metadata;

  /// Click-to-WhatsApp ad referral captured on first contact
  /// ({sourceId, headline, body, sourceUrl, ctwaClid, ...}).
  final Map<String, dynamic>? adReferral;

  /// Most recent ad that brought a returning lead back.
  final Map<String, dynamic>? lastAdReferral;

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
    this.sourceDetail,
    this.campaign,
    this.requirement,
    this.notes,
    this.blacklisted = false,
    this.aiEnabled = true,
    this.createdAt,
    this.updatedAt,
    this.lastContactAt,
    this.lastWhatsAppInboundAt,
    this.metadata,
    this.adReferral,
    this.lastAdReferral,
  });

  factory LeadModel.fromFirestore(DocumentSnapshot doc) =>
      LeadModel.fromMap((doc.data() as Map<String, dynamic>?) ?? {}, doc.id);

  factory LeadModel.fromMap(Map<String, dynamic> data, String id) {
    Map<String, dynamic>? asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
    return LeadModel(
      id: id,
      name: (data['name'] ?? data['leadName'] ?? 'Unknown').toString(),
      phone: (data['phone'] ?? data['leadPhone'] ?? '').toString(),
      email: (data['email']?.toString().isEmpty ?? true) ? null : data['email'].toString(),
      status: (data['status'] ?? 'New').toString(),
      priority: data['priority']?.toString(),
      assignedTo: data['assignedTo']?.toString(),
      assignedToName: data['assignedToName']?.toString(),
      source: data['source']?.toString(),
      sourceDetail: data['sourceDetail']?.toString(),
      campaign: data['campaign']?.toString(),
      requirement: (data['requirement']?.toString().isEmpty ?? true) ? null : data['requirement'].toString(),
      notes: data['notes']?.toString(),
      blacklisted: data['blacklisted'] == true,
      aiEnabled: data['aiEnabled'] != false,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt'] ?? data['lastUpdated']),
      lastContactAt: _parseTimestamp(data['lastContactAt'] ?? data['lastContactedAt']),
      lastWhatsAppInboundAt: _parseTimestamp(data['lastWhatsAppInboundAtMs'] ?? data['lastWhatsAppInboundAt']),
      metadata: asMap(data['metadata']),
      adReferral: asMap(data['adReferral']),
      lastAdReferral: asMap(data['lastAdReferral']),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  bool get isHot => priority == 'Hot' || priority == 'high';
  bool get isClosed => status == 'Closed-Won' || status == 'Lost';
  bool get isWon => status == 'Closed-Won';

  /// True for leads that came from any Meta ad surface (Lead Ads forms or
  /// Click-to-WhatsApp ads).
  bool get isFromMetaAd {
    final s = (source ?? '').toLowerCase();
    return adReferral != null || s.contains('meta') || s.contains('facebook') || s.contains('instagram');
  }

  bool get isCtwa => adReferral != null || (source ?? '').contains('Click-to-WhatsApp');

  /// The ad/campaign label used for attribution reports.
  String get adLabel {
    final h = adReferral?['headline']?.toString();
    if (h != null && h.isNotEmpty) return h;
    if (campaign != null && campaign!.isNotEmpty) return campaign!;
    final id = adReferral?['sourceId']?.toString();
    if (id != null && id.isNotEmpty) return 'Meta ad $id';
    return source ?? 'Unknown';
  }

  /// WhatsApp 24h customer-service window still open?
  bool get whatsappWindowOpen =>
      lastWhatsAppInboundAt != null && DateTime.now().difference(lastWhatsAppInboundAt!).inHours < 24;
}
