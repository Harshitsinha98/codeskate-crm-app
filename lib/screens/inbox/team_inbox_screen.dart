import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inbox_provider.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

/// Shared WhatsApp mailbox for the whole team (web: /admin/inbox, /app/inbox).
class TeamInboxScreen extends StatefulWidget {
  const TeamInboxScreen({super.key});

  @override
  State<TeamInboxScreen> createState() => _TeamInboxScreenState();
}

class _TeamInboxScreenState extends State<TeamInboxScreen> {
  InboxFilter _filter = InboxFilter.unclaimed;
  String _q = '';
  bool _filterChosen = false;

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<InboxProvider>();
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;
    final counts = inbox.counts();

    // Default to "Mine" when the user already holds chats.
    if (!_filterChosen && (counts[InboxFilter.mine] ?? 0) > 0 && _filter == InboxFilter.unclaimed && (counts[InboxFilter.unclaimed] ?? 0) == 0) {
      _filter = InboxFilter.mine;
    }
    final items = inbox.filtered(_filter, _q);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Column(children: [
        AuroraBackground(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Shared inbox', style: AppText.display(size: 26, color: Colors.white, letterSpacing: -0.8)),
                      Text(
                        inbox.totalUnread > 0 ? '${inbox.totalUnread} unread · ${inbox.items.length} conversations' : '${inbox.items.length} WhatsApp conversations',
                        style: AppText.body(size: 12.5, color: AppColors.textOnDarkMuted),
                      ),
                    ]),
                  ),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                      onSelected: (v) async {
                        if (v == 'rebuild') {
                          final err = await inbox.rebuild();
                          if (!context.mounted) return;
                          err == null ? AppToast.success(context, 'Inbox index rebuilt') : AppToast.error(context, err);
                        } else if (v == 'whatsapp') {
                          context.push('/integrations');
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rebuild', child: Text('Rebuild inbox index')),
                        PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp connection')),
                      ],
                    ),
                ]),
                const SizedBox(height: 14),
                SearchField(hint: 'Search name, number or message', dark: true, onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 12),
                SegmentTabs<InboxFilter>(
                  dark: true,
                  values: InboxFilter.values,
                  selected: _filter,
                  counts: counts,
                  label: (f) => f.label,
                  onChanged: (f) => setState(() {
                    _filter = f;
                    _filterChosen = true;
                  }),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: inbox.loading
              ? const SkeletonList(count: 7, height: 72)
              : inbox.error != null
                  ? PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Inbox unavailable', message: inbox.error)
                  : items.isEmpty
                      ? PremiumEmpty(
                          icon: Icons.mark_chat_read_rounded,
                          title: _q.isNotEmpty ? 'No matches' : 'Inbox zero ✨',
                          message: _q.isNotEmpty
                              ? 'Try another name or number.'
                              : switch (_filter) {
                                  InboxFilter.unclaimed => 'Every conversation has an owner.',
                                  InboxFilter.mine => 'Claim a chat to start replying.',
                                  InboxFilter.unread => 'You have read everything.',
                                  InboxFilter.ai => 'No chats are with the AI right now.',
                                  InboxFilter.all => 'WhatsApp conversations appear here as customers message you.',
                                },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _ConversationRow(c: items[i], me: user?.uid).stagger(i, stepMs: 30),
                        ),
        ),
      ]),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final ConversationSummary c;
  final String? me;
  const _ConversationRow({required this.c, required this.me});

  @override
  Widget build(BuildContext context) {
    final unread = c.unreadCount > 0;
    final mine = c.holderUid == me;
    final Widget ownerPill = c.isClaimed
        ? Pill(label: mine ? 'You' : (c.holderName ?? 'Agent'), color: mine ? AppColors.success : AppColors.info, icon: Icons.headset_mic_rounded)
        : c.aiEnabled
            ? const Pill(label: 'AI', color: AppColors.signal, icon: Icons.auto_awesome_rounded)
            : const Pill(label: 'Unclaimed', color: AppColors.orange600);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumCard(
        padding: const EdgeInsets.all(12),
        borderColor: unread ? AppColors.orange200 : null,
        onTap: () {
          context.read<InboxProvider>().markRead(c.leadId);
          context.push('/conversation/${c.leadId}');
        },
        child: Row(children: [
          GradientAvatar(
            name: c.leadName,
            size: 48,
            badge: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: AppColors.whatsapp, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.chat_rounded, size: 9, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(c.leadName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 14.5, weight: unread ? FontWeight.w800 : FontWeight.w600, color: AppColors.textPrimary)),
                ),
                Text(relTime(c.lastMessageAt), style: AppText.body(size: 11, weight: unread ? FontWeight.w700 : FontWeight.w500, color: unread ? AppColors.primaryDark : AppColors.textTertiary)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                if (c.lastDirection == 'outbound') const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.reply_rounded, size: 14, color: AppColors.textTertiary)),
                Expanded(
                  child: Text(c.lastMessage.isEmpty ? c.phone : c.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 12.8, color: unread ? AppColors.textPrimary : AppColors.textTertiary, weight: unread ? FontWeight.w600 : FontWeight.w400)),
                ),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(99)),
                    child: Text(c.unreadCount > 99 ? '99+' : '${c.unreadCount}', style: AppText.body(size: 10.5, weight: FontWeight.w800, color: Colors.white)),
                  ),
              ]),
              const SizedBox(height: 7),
              Row(children: [
                ownerPill,
                if (c.assignedToName != null && !c.isClaimed) ...[
                  const SizedBox(width: 6),
                  Flexible(child: Text('Owner: ${c.assignedToName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, color: AppColors.textTertiary))),
                ],
                if (c.status != null) ...[const Spacer(), Pill(label: c.status!, color: AppColors.forStatus(c.status!))],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
