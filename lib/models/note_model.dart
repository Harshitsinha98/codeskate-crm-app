import 'package:cloud_firestore/cloud_firestore.dart';

/// A lead note from `organizations/{orgId}/leads/{leadId}/notes`.
/// Written by the app (worknotes), the backend (status/follow-up audit), and
/// the native call tracker (`type: call`).
class NoteModel {
  final String id;
  final String type; // worknote, call, note, ...
  final String text;
  final String? authorId;
  final String? authorName;
  final String? authorRole;
  final String visibility; // team, admin_only
  final DateTime? at;
  final int? duration;

  NoteModel({
    required this.id,
    required this.type,
    required this.text,
    this.authorId,
    this.authorName,
    this.authorRole,
    this.visibility = 'team',
    this.at,
    this.duration,
  });

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawAt = data['at'];
    DateTime? at;
    if (rawAt is Timestamp) at = rawAt.toDate();
    if (rawAt is String) at = DateTime.tryParse(rawAt);
    return NoteModel(
      id: doc.id,
      type: data['type']?.toString() ?? 'note',
      text: data['text']?.toString() ?? '',
      authorId: data['authorId']?.toString(),
      authorName: data['authorName']?.toString(),
      authorRole: data['authorRole']?.toString(),
      visibility: data['visibility']?.toString() ?? 'team',
      at: at?.toLocal(),
      duration: (data['duration'] as num?)?.toInt(),
    );
  }

  bool get isCall => type == 'call';
  bool get isAdminOnly => visibility == 'admin_only';
}
