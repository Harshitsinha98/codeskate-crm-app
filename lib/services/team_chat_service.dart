import 'package:cloud_firestore/cloud_firestore.dart';

/// A team chat thread under `organizations/{orgId}/teamChats/{chatId}`.
///
/// * `general` — one org-wide channel every active member can use.
/// * `dm_{uidA}__{uidB}` — a 1:1 thread (uids sorted) between two members.
///
/// Access is enforced by the `teamChats` block in SNS-ADS-ERP/firestore.rules.
class TeamChatThread {
  final String id;
  final String kind; // general | dm
  final List<String> participants;
  final Map<String, String> participantNames;
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageAt;

  TeamChatThread({
    required this.id,
    required this.kind,
    this.participants = const [],
    this.participantNames = const {},
    this.lastMessage,
    this.lastSenderId,
    this.lastMessageAt,
  });

  bool get isGeneral => kind == 'general';

  String otherUid(String me) =>
      participants.firstWhere((p) => p != me, orElse: () => '');

  String titleFor(String me) {
    if (isGeneral) return 'General';
    final other = otherUid(me);
    return participantNames[other] ?? 'Team member';
  }

  factory TeamChatThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final at = d['lastMessageAt'];
    return TeamChatThread(
      id: doc.id,
      kind: d['kind']?.toString() ?? (doc.id == 'general' ? 'general' : 'dm'),
      participants: List<String>.from(d['participants'] ?? const []),
      participantNames: Map<String, String>.from(
        (d['participantNames'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
      ),
      lastMessage: d['lastMessage']?.toString(),
      lastSenderId: d['lastSenderId']?.toString(),
      lastMessageAt: at is Timestamp ? at.toDate() : null,
    );
  }
}

class TeamChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? at;

  TeamChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.at,
  });

  factory TeamChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final at = d['at'];
    return TeamChatMessage(
      id: doc.id,
      senderId: d['senderId']?.toString() ?? '',
      senderName: d['senderName']?.toString() ?? 'Team member',
      text: d['text']?.toString() ?? '',
      at: at is Timestamp ? at.toDate() : null,
    );
  }
}

class TeamChatService {
  final FirebaseFirestore _db;
  TeamChatService([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  static const generalId = 'general';

  static String dmId(String a, String b) {
    final ids = [a, b]..sort();
    return 'dm_${ids[0]}__${ids[1]}';
  }

  CollectionReference<Map<String, dynamic>> _threads(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('teamChats');

  /// DM threads the user participates in (newest activity first).
  Stream<List<TeamChatThread>> dmThreads(String orgId, String uid) {
    return _threads(orgId)
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(TeamChatThread.fromDoc).toList();
      list.sort((a, b) =>
          (b.lastMessageAt ?? DateTime(0)).compareTo(a.lastMessageAt ?? DateTime(0)));
      return list;
    });
  }

  Stream<List<TeamChatMessage>> messages(String orgId, String chatId, {int limit = 200}) {
    return _threads(orgId)
        .doc(chatId)
        .collection('messages')
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(TeamChatMessage.fromDoc).toList());
  }

  /// Sends a message and bumps the thread's `last*` summary atomically.
  /// For a new DM, [participants]/[participantNames] create the thread.
  Future<void> send({
    required String orgId,
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    List<String>? participants,
    Map<String, String>? participantNames,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final body = trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed;
    final threadRef = _threads(orgId).doc(chatId);
    final msgRef = threadRef.collection('messages').doc();
    final isGeneral = chatId == generalId;
    final sorted = isGeneral ? <String>[] : ([...?participants]..sort());

    final batch = _db.batch();
    batch.set(
      threadRef,
      {
        'kind': isGeneral ? 'general' : 'dm',
        'participants': sorted,
        if (participantNames != null) 'participantNames': participantNames,
        'lastMessage': body.length > 140 ? '${body.substring(0, 140)}…' : body,
        'lastSenderId': senderId,
        'lastSenderName': senderName,
        'lastMessageAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(msgRef, {
      'senderId': senderId,
      'senderName': senderName,
      'text': body,
      'at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
