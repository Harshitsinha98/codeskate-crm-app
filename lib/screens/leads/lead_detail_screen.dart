import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/followup_model.dart';
import '../../models/lead_model.dart';
import '../../models/note_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inbox_provider.dart';
import '../../providers/leads_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';
import 'call_options_sheet.dart';
import 'lead_action_sheets.dart';

class LeadDetailScreen extends StatelessWidget {
  final String leadId;
  const LeadDetailScreen({super.key, required this.leadId});

  @override
  Widget build(BuildContext context) {
    final leads = context.watch<LeadsProvider>();
    final lead = leads.getLeadById(leadId);
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;

    if (lead == null) {
      return Scaffold(
        appBar: const PremiumAppBar(title: 'Lead'),
        body: const PremiumEmpty(icon: Icons.person_off_rounded, title: 'Lead not available', message: 'It may have been reassigned or deleted.'),
      );
    }

    final followUps = leads.getFollowUpsForLead(leadId);
    final open = leads.openFollowUpForLead(leadId);
    final conv = context.watch<InboxProvider>().byLead(leadId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(lead: lead, isAdmin: isAdmin)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(children: [
                _Action(icon: Icons.call_rounded, label: 'Call', color: AppColors.success, onTap: () => showCallOptionsSheet(context, lead)),
                _Action(icon: Icons.forum_rounded, label: 'Mailbox', color: AppColors.whatsappDark, badge: conv?.unreadCount ?? 0, onTap: () => context.push('/conversation/${lead.id}')),
                _Action(icon: Icons.flag_rounded, label: 'Status', color: AppColors.forStatus(lead.status), onTap: () => showStatusPickerSheet(context, lead)),
                _Action(
                  icon: open != null ? Icons.task_alt_rounded : Icons.event_available_rounded,
                  label: open != null ? 'Complete' : 'Follow-up',
                  color: AppColors.orange600,
                  onTap: lead.isClosed && open == null
                      ? null
                      : () => open != null ? showCompleteFollowUpSheet(context, open) : showScheduleFollowUpSheet(context, lead),
                ),
                if (isAdmin) _Action(icon: Icons.swap_horiz_rounded, label: 'Assign', color: AppColors.info, onTap: () => showReassignSheet(context, lead)),
              ].map((w) => Expanded(child: w)).toList()),
            ).stagger(1),
          ),
          if (lead.isFromMetaAd) SliverToBoxAdapter(child: _AdAttribution(lead: lead).stagger(2)),
          SliverToBoxAdapter(child: _Details(lead: lead).stagger(3)),
          SliverToBoxAdapter(child: _MailboxPreview(lead: lead, conv: conv).stagger(4)),
          if (followUps.isNotEmpty) SliverToBoxAdapter(child: _FollowUps(tasks: followUps).stagger(5)),
          SliverToBoxAdapter(child: _NotesSection(leadId: leadId).stagger(6)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final LeadModel lead;
  final bool isAdmin;
  const _Header({required this.lead, required this.isAdmin});

  Future<void> _setPriority(BuildContext context, String p) async {
    final orgId = context.read<AuthProvider>().user?.activeOrgId;
    if (orgId == null) return;
    try {
      // Priority is the one lead field clients may write directly (rules).
      await FirebaseFirestore.instance.collection('organizations').doc(orgId).collection('leads').doc(lead.id).update({'priority': p});
      if (context.mounted) AppToast.success(context, 'Priority set to $p');
    } catch (_) {
      if (context.mounted) AppToast.error(context, 'Could not update priority');
    }
  }

  Future<void> _menu(BuildContext context, String v) async {
    final orgId = context.read<AuthProvider>().user!.activeOrgId!;
    try {
      if (v == 'copy') {
        await Clipboard.setData(ClipboardData(text: lead.phone));
        if (context.mounted) AppToast.success(context, 'Number copied');
      } else if (v == 'wa') {
        final d = lead.phone.replaceAll(RegExp(r'\D'), '');
        await launchUrl(Uri.parse('https://wa.me/${d.length == 10 ? '91$d' : d}'), mode: LaunchMode.externalApplication);
      } else if (v == 'email' && lead.email != null) {
        await launchUrl(Uri.parse('mailto:${lead.email}'));
      } else if (v == 'blacklist') {
        final ok = await confirmAction(context,
            title: lead.blacklisted ? 'Remove from blacklist?' : 'Blacklist this lead?',
            message: lead.blacklisted ? 'The lead will be active again.' : 'Blacklisted leads stop receiving messages and broadcasts.',
            destructive: !lead.blacklisted);
        if (!ok) return;
        await LeadsApi.setBlacklisted(orgId: orgId, leadId: lead.id, status: lead.status, blacklisted: !lead.blacklisted);
        if (context.mounted) AppToast.success(context, lead.blacklisted ? 'Lead restored' : 'Lead blacklisted');
      } else if (v == 'delete') {
        final ok = await confirmAction(context, title: 'Delete lead?', message: 'This permanently removes ${lead.name} and their history.', confirmLabel: 'Delete', destructive: true);
        if (!ok) return;
        await LeadsApi.delete(orgId: orgId, leadId: lead.id);
        if (context.mounted) {
          AppToast.success(context, 'Lead deleted');
          context.pop();
        }
      }
    } on ApiException catch (e) {
      if (context.mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(lead.status);
    return AuroraBackground(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19), onPressed: () => context.pop()),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                onSelected: (v) => _menu(context, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'copy', child: Text('Copy number')),
                  const PopupMenuItem(value: 'wa', child: Text('Open in WhatsApp app')),
                  if (lead.email != null) const PopupMenuItem(value: 'email', child: Text('Send email')),
                  if (isAdmin) PopupMenuItem(value: 'blacklist', child: Text(lead.blacklisted ? 'Remove from blacklist' : 'Blacklist')),
                  if (isAdmin) const PopupMenuItem(value: 'delete', child: Text('Delete lead', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Hero(tag: 'avatar-${lead.id}', child: GradientAvatar(name: lead.name, size: 64)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lead.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.display(size: 24, color: Colors.white, letterSpacing: -0.6)),
                    const SizedBox(height: 3),
                    Text(lead.phone, style: AppText.mono(size: 13.5, color: AppColors.textOnDarkMuted)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      Pill(label: lead.status, color: color, solid: true),
                      if (lead.blacklisted) const Pill(label: 'Blacklisted', color: AppColors.error, solid: true),
                      if (lead.isFromMetaAd) const Pill(label: 'Meta ad', color: AppColors.meta, solid: true, icon: Icons.ads_click_rounded),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                for (final p in const ['Hot', 'Warm', 'Cold'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pressable(
                        onTap: lead.priority == p ? null : () => _setPriority(context, p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            gradient: lead.priority == p ? AppColors.primaryGradient : null,
                            color: lead.priority == p ? null : Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: lead.priority == p ? Colors.transparent : Colors.white12),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(p == 'Hot' ? Icons.local_fire_department_rounded : (p == 'Warm' ? Icons.wb_sunny_rounded : Icons.ac_unit_rounded),
                                size: 15, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(p, style: AppText.body(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final int badge;
  const _Action({required this.icon, required this.label, required this.color, this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Pressable(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.45 : 1,
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                IconBubble(icon: icon, color: color, size: 48, gradient: true),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 1.5)),
                      child: Text('$badge', style: AppText.body(size: 10, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      );
}

class _AdAttribution extends StatelessWidget {
  final LeadModel lead;
  const _AdAttribution({required this.lead});

  @override
  Widget build(BuildContext context) {
    final r = lead.adReferral ?? {};
    final last = lead.lastAdReferral;
    Widget row(String k, String? v) => (v == null || v.isEmpty)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 92, child: Text(k, style: AppText.body(size: 12, color: AppColors.textTertiary))),
              Expanded(child: Text(v, style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.textPrimary))),
            ]),
          );
    return PremiumCard(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      gradient: LinearGradient(colors: [AppColors.meta.withValues(alpha: 0.07), Colors.white]),
      borderColor: AppColors.meta.withValues(alpha: 0.25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBubble(icon: Icons.ads_click_rounded, color: AppColors.meta, gradient: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lead.isCtwa ? 'Click-to-WhatsApp ad' : 'Meta Lead Ad', style: AppText.body(size: 11.5, weight: FontWeight.w700, color: AppColors.meta)),
              Text(lead.adLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.display(size: 15.5, weight: FontWeight.w700)),
            ]),
          ),
        ]),
        row('Ad copy', r['body']?.toString()),
        row('Ad ID', r['sourceId']?.toString()),
        row('Placement', lead.sourceDetail),
        if (last != null) row('Last re-engaged', '${last['headline'] ?? 'Meta ad'} · ${relTime(DateTime.tryParse('${last['capturedAt']}'))} ago'),
        if ((r['sourceUrl'] ?? '').toString().startsWith('http'))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(r['sourceUrl'].toString()), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('View ad'),
            ),
          ),
      ]),
    );
  }
}

class _Details extends StatelessWidget {
  final LeadModel lead;
  const _Details({required this.lead});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String?)>[
      ('Requirement', lead.requirement),
      ('Source', lead.source),
      if (!lead.isFromMetaAd) ('Campaign', lead.campaign),
      ('Owner', lead.assignedToName),
      ('Email', lead.email),
      ('Created', lead.createdAt == null ? null : DateFormat('d MMM yyyy · h:mm a').format(lead.createdAt!)),
      ('Last update', lead.updatedAt == null ? null : '${relTime(lead.updatedAt)} ago'),
      ('Last contact', lead.lastContactAt == null ? null : DateFormat('d MMM · h:mm a').format(lead.lastContactAt!)),
    ].where((r) => r.$2 != null && r.$2!.isNotEmpty).toList();
    return TitledCard(
      title: 'Details',
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 104, child: Text(r.$1, style: AppText.body(size: 12.5, color: AppColors.textTertiary))),
                    Expanded(child: Text(r.$2!, style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.textPrimary))),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}

class _MailboxPreview extends StatelessWidget {
  final LeadModel lead;
  final ConversationSummary? conv;
  const _MailboxPreview({required this.lead, required this.conv});

  @override
  Widget build(BuildContext context) {
    final c = conv;
    return TitledCard(
      title: 'WhatsApp mailbox',
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      trailing: c == null
          ? null
          : c.isClaimed
              ? Pill(label: c.holderName ?? 'Claimed', color: AppColors.info, icon: Icons.headset_mic_rounded)
              : (c.aiEnabled ? const Pill(label: 'AI replying', color: AppColors.signal, icon: Icons.auto_awesome_rounded) : const Pill(label: 'Unclaimed', color: AppColors.orange600)),
      child: Pressable(
        onTap: () => context.push('/conversation/${lead.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.cream100, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const IconBubble(icon: Icons.chat_rounded, color: AppColors.whatsappDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c?.lastMessage.isNotEmpty == true ? c!.lastMessage : 'No WhatsApp messages yet',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13.2, color: AppColors.textPrimary, weight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(
                  c == null
                      ? 'Start a conversation with an approved template'
                      : '${c.lastDirection == 'outbound' ? 'You' : 'Customer'} · ${relTime(c.lastMessageAt)} ago${lead.whatsappWindowOpen ? ' · window open' : ''}',
                  style: AppText.body(size: 11.5, color: AppColors.textTertiary),
                ),
              ]),
            ),
            if ((c?.unreadCount ?? 0) > 0) Pill(label: '${c!.unreadCount} new', color: AppColors.error, solid: true),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ]),
        ),
      ),
    );
  }
}

class _FollowUps extends StatelessWidget {
  final List<FollowUpModel> tasks;
  const _FollowUps({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return TitledCard(
      title: 'Follow-ups',
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: tasks.map((t) {
          final color = t.isOverdue ? AppColors.error : (t.isOpen ? AppColors.orange600 : AppColors.success);
          return Pressable(
            onTap: t.isOpen ? () => showFollowUpActionsSheet(context, t) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                IconBubble(icon: t.type == 'WhatsApp' ? Icons.chat_rounded : (t.type == 'Meeting' ? Icons.groups_rounded : Icons.call_rounded), color: color, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title ?? '${t.type} follow-up', style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (t.dueAt != null) Text(DateFormat('EEE d MMM · h:mm a').format(t.dueAt!), style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
                  ]),
                ),
                Pill(label: t.isOverdue ? 'Overdue' : (t.isOpen ? 'Open' : (t.outcome ?? 'Done')), color: color),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NotesSection extends StatefulWidget {
  final String leadId;
  const _NotesSection({required this.leadId});

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  final _controller = TextEditingController();
  late final Stream<List<NoteModel>> _stream = context.read<LeadsProvider>().notesStream(widget.leadId);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    final err = await context.read<LeadsProvider>().addNote(widget.leadId, text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      _controller.clear();
      FocusScope.of(context).unfocus();
      AppToast.success(context, 'Note added');
    } else {
      AppToast.error(context, err);
    }
  }

  (IconData, Color) _style(NoteModel n) => switch (n.type) {
        'call' => (Icons.call_rounded, AppColors.success),
        'whatsapp' => (Icons.chat_rounded, AppColors.whatsappDark),
        'system' => (Icons.bolt_rounded, AppColors.signal),
        _ => (Icons.sticky_note_2_rounded, AppColors.orange600),
      };

  @override
  Widget build(BuildContext context) {
    return TitledCard(
      title: 'Timeline',
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(hintText: 'Add a note for the team…', counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: _saving ? null : _save,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(15), boxShadow: AppColors.glow(AppColors.orange500, 0.25)),
              child: _saving
                  ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 19),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        StreamBuilder<List<NoteModel>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) return Text('Could not load the timeline.', style: AppText.body(size: 12.5, color: AppColors.textTertiary));
            if (!snap.hasData) return const SkeletonList(count: 3, height: 44, padding: EdgeInsets.zero);
            final notes = snap.data!;
            if (notes.isEmpty) return Text('No activity yet.', style: AppText.body(size: 12.5, color: AppColors.textTertiary));
            return Column(
              children: notes.asMap().entries.map((e) {
                final n = e.value;
                final (icon, color) = _style(n);
                final last = e.key == notes.length - 1;
                return IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Column(children: [
                      IconBubble(icon: icon, color: color, size: 30),
                      if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: AppColors.divider)),
                    ]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14, top: 2),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.text, style: AppText.body(size: 13.2, color: AppColors.textPrimary)),
                          const SizedBox(height: 3),
                          Text(
                            [
                              n.authorName ?? 'System',
                              if (n.at != null) DateFormat('d MMM · h:mm a').format(n.at!),
                              if (n.isCall && n.duration != null) '${n.duration}s',
                              if (n.isAdminOnly) 'admin only',
                            ].join(' · '),
                            style: AppText.body(size: 11, color: AppColors.textTertiary),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }
}
