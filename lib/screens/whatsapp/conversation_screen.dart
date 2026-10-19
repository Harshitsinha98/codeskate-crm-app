import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../models/message_model.dart';
import '../../models/note_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/inbox_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/team_provider.dart';
import '../leads/call_options_sheet.dart';
import '../widgets/premium.dart';

/// One WhatsApp thread inside the shared mailbox: session ownership
/// (claim / release / reassign), AI hand-off, 24h-window aware composer,
/// approved templates and team-only internal notes.
class ConversationScreen extends StatefulWidget {
  final String leadId;
  const ConversationScreen({super.key, required this.leadId});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _scroll = ScrollController();
  final _text = TextEditingController();
  bool _noteMode = false;
  bool _sending = false;
  bool _accessDenied = false;
  List<MessageModel> _messages = [];
  List<NoteModel> _notes = [];
  StreamSubscription? _msgSub;
  StreamSubscription? _noteSub;
  String? _subscribedFor;

  String? get _orgId => context.read<AuthProvider>().user?.activeOrgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InboxProvider>().markRead(widget.leadId);
      _subscribe();
      _noteSub = context.read<LeadsProvider>().notesStream(widget.leadId).listen((n) {
        if (mounted) setState(() => _notes = n.where((x) => x.type == 'worknote').toList());
      }, onError: (_) {});
    });
  }

  /// (Re)subscribe to the transcript. Employees gain read access only after
  /// claiming, so this is retried whenever ownership changes.
  void _subscribe() {
    final orgId = _orgId;
    if (orgId == null) return;
    final key = '${context.read<InboxProvider>().byLead(widget.leadId)?.holderUid}';
    if (_subscribedFor == key && !_accessDenied && _msgSub != null) return;
    _subscribedFor = key;
    _msgSub?.cancel();
    _msgSub = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('leads')
        .doc(widget.leadId)
        .collection('messages')
        .orderBy('atMs', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _accessDenied = false;
        _messages = snap.docs.map(MessageModel.fromFirestore).toList().reversed.toList();
      });
      _jumpToEnd();
    }, onError: (e) {
      if (mounted) setState(() => _accessDenied = true);
    });
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: 350.ms, curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _noteSub?.cancel();
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  LeadModel _leadOrFallback(ConversationSummary? c) {
    final l = context.read<LeadsProvider>().getLeadById(widget.leadId);
    if (l != null) return l;
    return LeadModel(
      id: widget.leadId,
      name: c?.leadName ?? 'Customer',
      phone: c?.phone ?? '',
      status: c?.status ?? 'New',
      assignedTo: c?.assignedTo,
      assignedToName: c?.assignedToName,
      aiEnabled: c?.aiEnabled ?? true,
    );
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    if (_noteMode) {
      final err = await context.read<LeadsProvider>().addNote(widget.leadId, text);
      if (!mounted) return;
      setState(() => _sending = false);
      if (err == null) {
        _text.clear();
        AppToast.success(context, 'Internal note added — only your team can see it');
      } else {
        AppToast.error(context, err);
      }
      return;
    }
    final r = await context.read<ChatProvider>().sendMessage(widget.leadId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok) {
      _text.clear();
      _jumpToEnd();
    } else if (r.code == 'template_required') {
      AppToast.info(context, '24-hour window closed — pick an approved template.');
      _openTemplates();
    } else {
      AppToast.error(context, r.error ?? 'Could not send message');
    }
  }

  void _openTemplates() {
    showPremiumSheet(
      context,
      title: 'Send a template',
      subtitle: 'Approved WhatsApp templates work outside the 24-hour window',
      builder: (ctx) => _TemplatePicker(leadId: widget.leadId, onSent: () {
        Navigator.pop(ctx);
        AppToast.success(context, 'Template sent');
        _jumpToEnd();
      }),
    );
  }

  Future<void> _act(Future<String?> Function() fn, String ok) async {
    HapticFeedback.mediumImpact();
    final err = await fn();
    if (!mounted) return;
    if (err == null) {
      AppToast.success(context, ok);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _subscribe();
      });
    } else {
      AppToast.error(context, err);
    }
  }

  Future<void> _reassign() async {
    final members = context.read<TeamProvider>().activeMembers;
    final inbox = context.read<InboxProvider>();
    final picked = await showPremiumSheet<String>(
      context,
      title: 'Hand over chat',
      subtitle: 'The new agent takes the conversation instantly',
      builder: (ctx) => Column(
        children: members
            .map((m) => PremiumTile(
                  icon: Icons.person_rounded,
                  title: m.name,
                  subtitle: m.role,
                  onTap: () => Navigator.pop(ctx, m.id),
                ))
            .toList(),
      ),
    );
    if (picked == null || !mounted) return;
    final m = members.firstWhere((x) => x.id == picked);
    await _act(() => inbox.reassign(widget.leadId, m.id, m.name), 'Handed over to ${m.name}');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final inbox = context.watch<InboxProvider>();
    context.watch<LeadsProvider>();
    final conv = inbox.byLead(widget.leadId);
    final lead = _leadOrFallback(conv);
    final me = user?.uid;
    final isAdmin = user?.isAdmin ?? false;
    final iHold = conv?.holderUid == me && me != null;
    final someoneElse = (conv?.isClaimed ?? false) && !iHold;
    final aiOn = conv?.aiEnabled ?? lead.aiEnabled;
    final canReply = isAdmin || iHold || (lead.assignedTo == me && !aiOn);
    final busy = inbox.isBusy(widget.leadId);

    // Re-try transcript access after ownership changes.
    if ('${conv?.holderUid}' != _subscribedFor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _subscribe();
      });
    }

    final timeline = <_Entry>[
      ..._messages.map((m) => _Entry(m.timestamp ?? DateTime(0), message: m)),
      ..._notes.map((n) => _Entry(n.at ?? DateTime(0), note: n)),
    ]..sort((a, b) => a.at.compareTo(b.at));

    return Scaffold(
      backgroundColor: AppColors.cream100,
      appBar: PremiumAppBar(
        title: lead.name,
        subtitle: [lead.phone, if (lead.isFromMetaAd) 'via Meta ad'].where((s) => s.isNotEmpty).join(' · '),
        actions: [
          IconButton(icon: const Icon(Icons.call_rounded), onPressed: lead.phone.isEmpty ? null : () => showCallOptionsSheet(context, lead)),
          if (context.read<LeadsProvider>().getLeadById(widget.leadId) != null)
            IconButton(icon: const Icon(Icons.person_search_rounded), onPressed: () => context.push('/lead/${widget.leadId}')),
        ],
      ),
      body: Column(children: [
        _SessionBar(
          aiOn: aiOn,
          iHold: iHold,
          holderName: conv?.holderName,
          someoneElse: someoneElse,
          isAdmin: isAdmin,
          busy: busy,
          onClaim: () => _act(() => inbox.claim(widget.leadId), 'You are now handling this chat'),
          onRelease: () => _act(() => inbox.release(widget.leadId), 'Chat released to the team'),
          onReassign: isAdmin ? _reassign : null,
          onResumeAi: () => _act(() => inbox.reEnableAi(widget.leadId), 'AI is replying again'),
        ),
        if (lead.adReferral != null) _AdBanner(lead: lead),
        Expanded(
          child: _accessDenied
              ? PremiumEmpty(
                  icon: Icons.lock_person_rounded,
                  title: 'Claim to view this chat',
                  message: 'Customer messages are private. Claim the conversation to read the history and reply.',
                  action: GlowButton(
                    label: 'Claim conversation',
                    icon: Icons.headset_mic_rounded,
                    expand: false,
                    loading: busy,
                    onPressed: () => _act(() => inbox.claim(widget.leadId), 'You are now handling this chat'),
                  ),
                )
              : timeline.isEmpty
                  ? const PremiumEmpty(icon: Icons.chat_bubble_outline_rounded, title: 'No messages yet', message: 'Messages from this customer will appear here in real time.')
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      physics: const BouncingScrollPhysics(),
                      itemCount: timeline.length,
                      itemBuilder: (context, i) {
                        final e = timeline[i];
                        final prev = i > 0 ? timeline[i - 1].at : null;
                        final showDay = prev == null || prev.day != e.at.day || prev.month != e.at.month;
                        return Column(children: [
                          if (showDay && e.at.year > 2000) _DayChip(e.at),
                          if (e.message != null) _Bubble(m: e.message!) else _NoteBubble(n: e.note!),
                        ]);
                      },
                    ),
        ),
        _Composer(
          controller: _text,
          noteMode: _noteMode,
          sending: _sending,
          canReply: canReply,
          windowOpen: lead.lastWhatsAppInboundAt == null ? true : lead.whatsappWindowOpen,
          onToggleNote: () => setState(() => _noteMode = !_noteMode),
          onTemplates: canReply ? _openTemplates : null,
          onSend: _send,
          onClaim: () => _act(() => inbox.claim(widget.leadId), 'You are now handling this chat'),
          claimBusy: busy,
          someoneElse: someoneElse,
          holderName: conv?.holderName,
        ),
      ]),
    );
  }
}

class _Entry {
  final DateTime at;
  final MessageModel? message;
  final NoteModel? note;
  _Entry(this.at, {this.message, this.note});
}

class _SessionBar extends StatelessWidget {
  final bool aiOn, iHold, someoneElse, isAdmin, busy;
  final String? holderName;
  final VoidCallback onClaim, onRelease, onResumeAi;
  final VoidCallback? onReassign;

  const _SessionBar({
    required this.aiOn,
    required this.iHold,
    required this.someoneElse,
    required this.isAdmin,
    required this.busy,
    required this.holderName,
    required this.onClaim,
    required this.onRelease,
    required this.onResumeAi,
    this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String text;
    final actions = <Widget>[];

    Widget btn(String label, VoidCallback onTap, {bool primary = false}) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Pressable(
            onTap: busy ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: primary ? AppColors.primaryGradient : null,
                color: primary ? null : Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: primary ? null : Border.all(color: AppColors.border),
              ),
              child: Text(label, style: AppText.body(size: 12, weight: FontWeight.w700, color: primary ? Colors.white : AppColors.textPrimary)),
            ),
          ),
        );

    if (iHold) {
      icon = Icons.headset_mic_rounded;
      color = AppColors.success;
      text = 'You\'re handling this chat';
      actions.add(btn('Release', onRelease));
      if (onReassign != null) actions.add(btn('Hand over', onReassign!));
    } else if (someoneElse) {
      icon = Icons.lock_clock_rounded;
      color = AppColors.info;
      text = '${holderName ?? 'A teammate'} is replying';
      if (isAdmin) {
        actions.add(btn('Take over', onClaim, primary: true));
        if (onReassign != null) actions.add(btn('Hand over', onReassign!));
      }
    } else if (aiOn) {
      icon = Icons.auto_awesome_rounded;
      color = AppColors.signal;
      text = 'AI agent is replying';
      actions.add(btn('Claim', onClaim, primary: true));
    } else {
      icon = Icons.inbox_rounded;
      color = AppColors.orange600;
      text = 'Unclaimed — AI paused';
      actions.add(btn('Claim', onClaim, primary: true));
      actions.add(btn('Resume AI', onResumeAi));
    }

    return AnimatedContainer(
      duration: 300.ms,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.18))),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12.8, weight: FontWeight.w700, color: color))),
        if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) else ...actions,
      ]),
    ).animate(key: ValueKey(text)).fadeIn(duration: 250.ms);
  }
}

class _AdBanner extends StatelessWidget {
  final LeadModel lead;
  const _AdBanner({required this.lead});

  @override
  Widget build(BuildContext context) {
    final r = lead.adReferral!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.meta.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.meta.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const IconBubble(icon: Icons.ads_click_rounded, color: AppColors.meta, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Came from a Click-to-WhatsApp ad', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.meta)),
            Text(lead.adLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary)),
            if ((r['body'] ?? '').toString().isNotEmpty)
              Text(r['body'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
          ]),
        ),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime at;
  const _DayChip(this.at);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(at.year, at.month, at.day);
    final label = d == today ? 'Today' : (today.difference(d).inDays == 1 ? 'Yesterday' : DateFormat('EEE, d MMM').format(at));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: AppColors.cream200, borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.textSecondary)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final MessageModel m;
  const _Bubble({required this.m});

  @override
  Widget build(BuildContext context) {
    final out = m.isOutbound;
    final failed = m.status == 'failed';
    final isTemplate = m.type == 'template';
    final isBot = (m.senderName ?? '').toLowerCase().contains('ai') || (m.senderName ?? '').toLowerCase().contains('automation');
    final label = isTemplate
        ? 'Template${m.templateName != null ? ' · ${m.templateName}' : ''}'
        : (m.type == 'interactive' ? 'Menu' : null);
    final text = (m.text == null || m.text!.isEmpty) ? '[${m.type ?? 'media'} message]' : m.text!;

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
        decoration: BoxDecoration(
          gradient: out && !failed ? const LinearGradient(colors: [AppColors.orange400, AppColors.orange600]) : null,
          color: out ? (failed ? AppColors.errorLight : null) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(out ? 18 : 5),
            bottomRight: Radius.circular(out ? 5 : 18),
          ),
          border: out ? null : Border.all(color: AppColors.border),
          boxShadow: out && !failed ? AppColors.glow(AppColors.orange500, 0.18) : AppColors.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (out && (m.senderName != null || label != null))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isBot) const Icon(Icons.auto_awesome_rounded, size: 11, color: Colors.white70),
                if (isBot) const SizedBox(width: 3),
                Flexible(
                  child: Text([if (m.senderName != null) m.senderName!, if (label != null) label].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 10.5, weight: FontWeight.w700, color: failed ? AppColors.error : Colors.white70)),
                ),
              ]),
            ),
          if (!out && label != null)
            Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(label, style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.primaryDark))),
          Text(text, style: AppText.body(size: 14.2, color: out && !failed ? Colors.white : AppColors.textPrimary, height: 1.38)),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (m.timestamp != null)
              Text(DateFormat('h:mm a').format(m.timestamp!), style: AppText.body(size: 10, color: out && !failed ? Colors.white70 : AppColors.textTertiary)),
            if (out) ...[
              const SizedBox(width: 4),
              Icon(
                failed
                    ? Icons.error_outline_rounded
                    : (m.status == 'read' || m.status == 'delivered')
                        ? Icons.done_all_rounded
                        : (m.status == 'processing' ? Icons.schedule_rounded : Icons.done_rounded),
                size: 14,
                color: failed ? AppColors.error : (m.status == 'read' ? const Color(0xFFBFE3FF) : Colors.white70),
              ),
            ],
          ]),
          if (failed && m.error != null)
            Text(m.error!, style: AppText.body(size: 10.5, color: AppColors.error)),
        ]),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.15, duration: 260.ms, curve: Curves.easeOutCubic);
  }
}

class _NoteBubble extends StatelessWidget {
  final NoteModel n;
  const _NoteBubble({required this.n});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7DB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF5D88A)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.sticky_note_2_rounded, size: 13, color: Color(0xFFB7791F)),
              const SizedBox(width: 5),
              Expanded(
                child: Text('Internal note · ${n.authorName ?? 'Team'}',
                    style: AppText.body(size: 10.5, weight: FontWeight.w700, color: const Color(0xFFB7791F))),
              ),
              if (n.at != null) Text(DateFormat('h:mm a').format(n.at!), style: AppText.body(size: 10, color: const Color(0xFFB7791F))),
            ]),
            const SizedBox(height: 4),
            Text(n.text, style: AppText.body(size: 13, color: AppColors.textPrimary)),
          ]),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool noteMode, sending, canReply, windowOpen, claimBusy, someoneElse;
  final String? holderName;
  final VoidCallback onToggleNote, onSend, onClaim;
  final VoidCallback? onTemplates;

  const _Composer({
    required this.controller,
    required this.noteMode,
    required this.sending,
    required this.canReply,
    required this.windowOpen,
    required this.onToggleNote,
    required this.onSend,
    required this.onClaim,
    required this.claimBusy,
    required this.someoneElse,
    this.holderName,
    this.onTemplates,
  });

  @override
  Widget build(BuildContext context) {
    final replyBlocked = !noteMode && !canReply;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            _ModeChip(label: 'Reply', icon: Icons.chat_rounded, active: !noteMode, onTap: noteMode ? onToggleNote : null),
            const SizedBox(width: 6),
            _ModeChip(label: 'Internal note', icon: Icons.sticky_note_2_rounded, active: noteMode, onTap: noteMode ? null : onToggleNote, amber: true),
            const Spacer(),
            if (!noteMode && !windowOpen)
              const Pill(label: '24h window closed', color: AppColors.warning, icon: Icons.schedule_rounded),
          ]),
          const SizedBox(height: 8),
          if (replyBlocked)
            Row(children: [
              Expanded(
                child: Text(
                  someoneElse ? '${holderName ?? 'A teammate'} is handling this chat.' : 'Claim this chat to reply to the customer.',
                  style: AppText.body(size: 13, color: AppColors.textTertiary),
                ),
              ),
              if (!someoneElse)
                GlowButton(label: 'Claim', icon: Icons.headset_mic_rounded, expand: false, height: 42, loading: claimBusy, onPressed: onClaim),
            ])
          else
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (!noteMode)
                Pressable(
                  onTap: onTemplates,
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: !windowOpen ? AppColors.orange100 : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.dashboard_customize_rounded, size: 20, color: !windowOpen ? AppColors.primaryDark : AppColors.textSecondary),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.body(size: 14.5, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: noteMode ? 'Note for your team (customer won\'t see this)…' : (windowOpen ? 'Type a reply…' : 'Window closed — use a template'),
                    filled: true,
                    fillColor: noteMode ? const Color(0xFFFFF7DB) : AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: noteMode ? const Color(0xFFF5D88A) : AppColors.primary)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                onTap: sending ? null : onSend,
                child: AnimatedContainer(
                  duration: 200.ms,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: noteMode ? const LinearGradient(colors: [Color(0xFFF6C453), Color(0xFFD69E2E)]) : AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.glow(noteMode ? const Color(0xFFD69E2E) : AppColors.orange500, 0.3),
                  ),
                  child: sending
                      ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(noteMode ? Icons.note_add_rounded : Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
        ]),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool amber;
  final VoidCallback? onTap;
  const _ModeChip({required this.label, required this.icon, required this.active, this.onTap, this.amber = false});

  @override
  Widget build(BuildContext context) {
    final c = amber ? const Color(0xFFB7791F) : AppColors.primaryDark;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? c : AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(label, style: AppText.body(size: 11.5, weight: FontWeight.w700, color: active ? c : AppColors.textTertiary)),
        ]),
      ),
    );
  }
}

class _TemplatePicker extends StatefulWidget {
  final String leadId;
  final VoidCallback onSent;
  const _TemplatePicker({required this.leadId, required this.onSent});

  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  Map<String, dynamic>? _t;
  List<TextEditingController> _params = [];
  bool _sending = false;

  @override
  void dispose() {
    for (final c in _params) {
      c.dispose();
    }
    super.dispose();
  }

  void _pick(Map<String, dynamic> t) {
    final n = (t['parameterCount'] as num?)?.toInt() ?? 0;
    setState(() {
      _t = t;
      _params = List.generate(n, (_) => TextEditingController());
    });
  }

  Future<void> _send() async {
    final values = _params.map((c) => c.text.trim()).toList();
    if (values.any((v) => v.isEmpty)) {
      AppToast.error(context, 'Fill every template value');
      return;
    }
    setState(() => _sending = true);
    final r = await context.read<ChatProvider>().sendTemplate(widget.leadId, _t!['id'].toString(), values);
    if (!mounted) return;
    setState(() => _sending = false);
    r.ok ? widget.onSent() : AppToast.error(context, r.error ?? 'Could not send template');
  }

  @override
  Widget build(BuildContext context) {
    final templates = context.watch<ChatProvider>().templates.where((t) => (t['status'] ?? 'APPROVED') == 'APPROVED').toList();
    if (_t == null) {
      if (templates.isEmpty) {
        return const PremiumEmpty(icon: Icons.dashboard_customize_rounded, title: 'No approved templates', message: 'Ask an admin to sync templates from Integrations → WhatsApp.');
      }
      return Column(
        children: templates.map((t) {
          final preview = (t['preview'] ?? t['body'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PremiumCard(
              onTap: () => _pick(t),
              padding: const EdgeInsets.all(13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text((t['name'] ?? 'Template').toString(), style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary))),
                  Pill(label: (t['language'] ?? '').toString(), color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Pill(label: (t['category'] ?? 'UTILITY').toString(), color: AppColors.signal),
                ]),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12.5, color: AppColors.textTertiary)),
                ],
              ]),
            ),
          );
        }).toList(),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: () => setState(() => _t = null), icon: const Icon(Icons.arrow_back_rounded, size: 16), label: Text(_t!['name'].toString())),
      ),
      if ((_t!['preview'] ?? '').toString().isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.orange50, borderRadius: BorderRadius.circular(14)),
          child: Text(_t!['preview'].toString(), style: AppText.body(size: 13, color: AppColors.textSecondary)),
        ),
      for (var i = 0; i < _params.length; i++) ...[
        FieldLabel('Value for {{${i + 1}}}'),
        TextField(controller: _params[i], decoration: InputDecoration(hintText: i == 0 ? 'e.g. customer name' : 'Value')),
      ],
      const SizedBox(height: 18),
      GlowButton(label: 'Send template', icon: Icons.send_rounded, variant: GlowVariant.whatsapp, loading: _sending, onPressed: _send),
    ]);
  }
}
