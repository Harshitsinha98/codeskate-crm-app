import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/team_member_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../services/team_chat_service.dart';

/// Firestore-backed team chat: an org-wide "General" channel plus 1:1 DMs.
///
/// Admins can start a DM with any active member (they can list memberships).
/// Employees can use General and reply to any DM started with them —
/// Firestore rules don't let employees enumerate the org's memberships.
class EmployeeChatScreen extends StatefulWidget {
  const EmployeeChatScreen({super.key});

  @override
  State<EmployeeChatScreen> createState() => _EmployeeChatScreenState();
}

class _ChatTarget {
  final String chatId;
  final String title;
  final String subtitle;
  final List<String>? participants;
  final Map<String, String>? participantNames;

  _ChatTarget({
    required this.chatId,
    required this.title,
    this.subtitle = '',
    this.participants,
    this.participantNames,
  });
}

class _EmployeeChatScreenState extends State<EmployeeChatScreen> {
  final _service = TeamChatService();
  _ChatTarget? _selected;
  Stream<List<TeamChatThread>>? _threads;
  String? _threadsKey;

  void _ensureThreadStream(String orgId, String uid) {
    final key = '$orgId/$uid';
    if (_threadsKey == key) return;
    _threadsKey = key;
    _threads = _service.dmThreads(orgId, uid);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final team = context.watch<TeamProvider>();
    final user = auth.user;
    final orgId = user?.activeOrgId;
    if (user == null || orgId == null) {
      return const Scaffold(body: Center(child: Text('Sign in to use team chat')));
    }
    _ensureThreadStream(orgId, user.uid);
    final wide = MediaQuery.of(context).size.width > 600;

    final list = _ThreadList(
      threads: _threads!,
      me: user.uid,
      myName: user.name,
      isAdmin: user.isAdmin,
      members: team.activeMembers.where((m) => (m.uid ?? m.id) != user.uid).toList(),
      selectedId: _selected?.chatId,
      onSelect: (t) => setState(() => _selected = t),
    );

    final chat = _selected == null
        ? const _SelectPrompt()
        : _ChatArea(
            key: ValueKey(_selected!.chatId),
            service: _service,
            orgId: orgId,
            me: user.uid,
            myName: user.name,
            target: _selected!,
          );

    return Scaffold(
      appBar: AppBar(
        leading: !wide && _selected != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selected = null),
              )
            : null,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _selected == null || _selected!.chatId == TeamChatService.generalId
                    ? Icons.group_rounded
                    : Icons.person_rounded,
                size: 18,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                !wide && _selected != null ? _selected!.title : 'Team Chat',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: wide
          ? Row(
              children: [
                SizedBox(width: 280, child: list),
                const VerticalDivider(width: 1),
                Expanded(child: chat),
              ],
            )
          : (_selected == null ? list : chat),
    );
  }
}

class _ThreadList extends StatelessWidget {
  final Stream<List<TeamChatThread>> threads;
  final String me;
  final String myName;
  final bool isAdmin;
  final List<TeamMemberModel> members;
  final String? selectedId;
  final ValueChanged<_ChatTarget> onSelect;

  const _ThreadList({
    required this.threads,
    required this.me,
    required this.myName,
    required this.isAdmin,
    required this.members,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TeamChatThread>>(
      stream: threads,
      builder: (context, snap) {
        final dms = snap.data ?? const <TeamChatThread>[];
        final withThread = dms.map((t) => t.otherUid(me)).toSet();
        final startable = isAdmin
            ? members.where((m) => !withThread.contains(m.uid ?? m.id)).toList()
            : const <TeamMemberModel>[];

        return ListView(
          children: [
            _tile(
              icon: Icons.campaign_rounded,
              color: AppColors.primary,
              title: 'General',
              subtitle: 'Everyone in your organization',
              selected: selectedId == TeamChatService.generalId,
              onTap: () => onSelect(_ChatTarget(
                chatId: TeamChatService.generalId,
                title: 'General',
                subtitle: 'Everyone in your organization',
              )),
            ),
            const Divider(height: 1),
            if (dms.isNotEmpty) _header('Direct messages'),
            ...dms.map((t) {
              final other = t.otherUid(me);
              return _tile(
                icon: Icons.person_rounded,
                color: AppColors.info,
                title: t.titleFor(me),
                subtitle: t.lastMessage == null
                    ? ''
                    : '${t.lastSenderId == me ? 'You: ' : ''}${t.lastMessage}',
                trailing: t.lastMessageAt == null
                    ? null
                    : DateFormat(_sameDay(t.lastMessageAt!) ? 'hh:mm a' : 'MMM dd')
                        .format(t.lastMessageAt!),
                selected: selectedId == t.id,
                onTap: () => onSelect(_ChatTarget(
                  chatId: t.id,
                  title: t.titleFor(me),
                  participants: [me, other],
                  participantNames: {
                    ...t.participantNames,
                    me: myName,
                  },
                )),
              );
            }),
            if (startable.isNotEmpty) _header('Start a conversation'),
            ...startable.map((m) {
              final uid = m.uid ?? m.id;
              return _tile(
                icon: Icons.person_add_alt_1_rounded,
                color: AppColors.textTertiary,
                title: m.name,
                subtitle: m.role,
                selected: false,
                onTap: () => onSelect(_ChatTarget(
                  chatId: TeamChatService.dmId(me, uid),
                  title: m.name,
                  subtitle: m.role,
                  participants: [me, uid],
                  participantNames: {me: myName, uid: m.name},
                )),
              );
            }),
            if (!isAdmin && dms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Direct messages from your admins will show up here.',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ).animate().fadeIn(duration: 250.ms);
      },
    );
  }

  static bool _sameDay(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.textTertiary,
          ),
        ),
      );

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    String? trailing,
  }) {
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.primary.withOpacity(0.06),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      trailing: trailing == null
          ? null
          : Text(trailing, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      onTap: onTap,
    );
  }
}

class _SelectPrompt extends StatelessWidget {
  const _SelectPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.forum_rounded, size: 40, color: AppColors.info),
          ),
          const SizedBox(height: 16),
          const Text('Select a conversation',
              style: TextStyle(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _ChatArea extends StatefulWidget {
  final TeamChatService service;
  final String orgId;
  final String me;
  final String myName;
  final _ChatTarget target;

  const _ChatArea({
    super.key,
    required this.service,
    required this.orgId,
    required this.me,
    required this.myName,
    required this.target,
  });

  @override
  State<_ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<_ChatArea> {
  final _controller = TextEditingController();
  late final Stream<List<TeamChatMessage>> _messages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages = widget.service.messages(widget.orgId, widget.target.chatId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.service.send(
        orgId: widget.orgId,
        chatId: widget.target.chatId,
        senderId: widget.me,
        senderName: widget.myName,
        text: text,
        participants: widget.target.participants,
        participantNames: widget.target.participantNames,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message not sent. Check your connection and try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGeneral = widget.target.chatId == TeamChatService.generalId;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<TeamChatMessage>>(
            stream: _messages,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(
                  child: Text('Could not load messages.',
                      style: TextStyle(color: AppColors.textTertiary)),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              final msgs = snap.data!;
              if (msgs.isEmpty) {
                return Center(
                  child: Text(
                    'Start a conversation with ${widget.target.title}',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final m = msgs[i];
                  final isMe = m.senderId == widget.me;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primary.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isMe ? AppColors.primary.withOpacity(0.2) : AppColors.divider,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (isGeneral && !isMe)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                m.senderName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          Text(m.text, style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            m.at == null ? 'sending…' : DateFormat('hh:mm a').format(m.at!),
                            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _sending ? AppColors.textTertiary : AppColors.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
