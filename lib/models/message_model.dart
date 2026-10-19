import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String? text;
  final String direction; // 'inbound' or 'outbound'
  final String? type; // text, image, document, template
  final DateTime? timestamp;
  final String? from;
  final String? to;
  final String? status; // sent, delivered, read, failed
  final String? templateName;
  final String? senderName;
  final String? error;
  final Map<String, dynamic>? media;
  final Map<String, dynamic>? metadata;

  MessageModel({
    required this.id,
    this.text,
    required this.direction,
    this.type = 'text',
    this.timestamp,
    this.from,
    this.to,
    this.status,
    this.templateName,
    this.senderName,
    this.error,
    this.media,
    this.metadata,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel.fromMap(data, doc.id);
  }

  factory MessageModel.fromMap(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      text: data['text'] ?? data['body'],
      direction: data['direction'] ?? 'inbound',
      type: data['type'] ?? 'text',
      timestamp: _parseTimestamp(data['atMs'] ?? data['at'] ?? data['timestamp']),
      from: data['from'],
      to: data['to'],
      status: data['status'],
      templateName: data['templateName'],
      senderName: data['senderName'],
      error: data['error']?.toString(),
      media: data['media'],
      metadata: data['metadata'],
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      final v = value.toInt();
      // Epoch ms (backend `atMs`) vs. legacy epoch seconds.
      return DateTime.fromMillisecondsSinceEpoch(v > 100000000000 ? v : v * 1000);
    }
    return null;
  }

  bool get isInbound => direction == 'inbound';
  bool get isOutbound => direction == 'outbound';
  bool get hasMedia => media != null && media!.isNotEmpty;
}
