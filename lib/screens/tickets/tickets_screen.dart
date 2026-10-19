import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

Color _statusColor(String s) => switch (s) { 'resolved' => AppColors.success, 'in_progress' => AppColors.info, _ => AppColors.orange600 };
Color _prioColor(String p) => switch (p) { 'high' => AppColors.error, 'low' => AppColors.textTertiary, _ => AppColors.warning };

/// Org-internal tickets (employees raise → admins resolve).
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _error;
  String _tab = 'open';

  String get _orgId => context.read<AuthProvider>().user!.activeOrgId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await TicketsApi.list(_orgId);
      if (mounted) setState(() {
        _tickets = t;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final subject = TextEditingController();
    final desc = TextEditingController();
    String prio = 'medium';
    bool busy = false;
    await showPremiumSheet(
      context,
      title: 'Raise a ticket',
      subtitle: 'Your admin is notified instantly',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Subject'),
          TextField(controller: subject, decoration: const InputDecoration(hintText: 'e.g. Lead list not loading')),
          const FieldLabel('Details'),
          TextField(controller: desc, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: 'What happened? Steps, lead name…')),
          const FieldLabel('Priority'),
          ChoiceChips<String>(options: const ['low', 'medium', 'high'], selected: prio, label: (p) => p[0].toUpperCase() + p.substring(1), colorOf: _prioColor, onSelected: (p) => setS(() => prio = p)),
          const SizedBox(height: 20),
          GlowButton(
            label: 'Submit ticket',
            loading: busy,
            onPressed: () async {
              if (subject.text.trim().isEmpty) return AppToast.error(context, 'Add a subject');
              setS(() => busy = true);
              try {
                await TicketsApi.create(orgId: _orgId, subject: subject.text.trim(), description: desc.text.trim(), priority: prio);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) AppToast.success(context, 'Ticket raised');
                _load();
              } on ApiException catch (e) {
                setS(() => busy = false);
                AppToast.error(context, e.message);
              }
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _open(Map<String, dynamic> t) async {
    final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    final reply = TextEditingController();
    await showPremiumSheet(
      context,
      title: '${t['ticketNumber'] ?? ''} · ${t['subject']}',
      subtitle: '${t['raisedByName'] ?? ''} · ${(t['priority'] ?? 'medium')} priority',
      builder: (ctx) {
        var ticket = t;
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setS) {
          final replies = ((ticket['replies'] as List?) ?? []).whereType<Map>().toList();
          final status = (ticket['status'] ?? 'open').toString();
          final support = '${ticket['subject']}'.startsWith('[Support]');
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Pill(label: status.replaceAll('_', ' '), color: _statusColor(status), solid: true)]),
            if ('${ticket['description'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.cream200, borderRadius: BorderRadius.circular(14)),
                child: Text('${ticket['description']}', style: AppText.body(size: 13.5, color: AppColors.textPrimary)),
              ),
            ],
            const FieldLabel('Conversation'),
            if (replies.isEmpty) Text('No replies yet.', style: AppText.body(size: 13, color: AppColors.textTertiary)),
            ...replies.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GradientAvatar(name: '${r['fromName'] ?? '?'}', size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['fromName'] ?? ''} · ${relTime(DateTime.tryParse('${r['at']}'))}', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary)),
                          const SizedBox(height: 3),
                          Text('${r['text']}', style: AppText.body(size: 13, color: AppColors.textPrimary)),
                        ]),
                      ),
                    ),
                  ]),
                )),
            if (status != 'resolved') ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: reply, decoration: const InputDecoration(hintText: 'Write a reply…'))),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: busy
                      ? null
                      : () async {
                          if (reply.text.trim().isEmpty) return;
                          setS(() => busy = true);
                          try {
                            final r = await TicketsApi.reply(_orgId, '${ticket['id']}', reply.text.trim());
                            reply.clear();
                            setS(() {
                              ticket = Map<String, dynamic>.from(r['ticket'] ?? ticket);
                              busy = false;
                            });
                            _load();
                          } on ApiException catch (e) {
                            setS(() => busy = false);
                            AppToast.error(context, e.message);
                          }
                        },
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ]),
            ],
            if (isAdmin && !support && status != 'resolved') ...[
              const SizedBox(height: 16),
              Row(children: [
                if (status == 'open')
                  Expanded(
                    child: GlowButton(
                      label: 'In progress',
                      variant: GlowVariant.ghost,
                      onPressed: () async {
                        await TicketsApi.setStatus(_orgId, '${ticket['id']}', 'in_progress');
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                    ),
                  ),
                if (status == 'open') const SizedBox(width: 10),
                Expanded(
                  child: GlowButton(
                    label: 'Resolve',
                    icon: Icons.check_rounded,
                    onPressed: () async {
                      await TicketsApi.setStatus(_orgId, '${ticket['id']}', 'resolved');
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) AppToast.success(context, 'Ticket resolved');
                      _load();
                    },
                  ),
                ),
              ]),
            ],
            if (support) Padding(padding: const EdgeInsets.only(top: 12), child: Text('This ticket is handled by Codeskate support.', style: AppText.body(size: 12, color: AppColors.textTertiary))),
          ]);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _tickets.where((t) => _tab == 'all' || (_tab == 'open' ? t['status'] != 'resolved' : t['status'] == 'resolved')).toList();
    return Scaffold(
      appBar: PremiumAppBar(title: 'Internal tickets', subtitle: '${_tickets.where((t) => t['status'] != 'resolved').length} open'),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('New ticket')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: SegmentTabs<String>(values: const ['open', 'resolved', 'all'], selected: _tab, label: (s) => s[0].toUpperCase() + s.substring(1), onChanged: (s) => setState(() => _tab = s)),
        ),
        Expanded(
          child: _loading
              ? const SkeletonList()
              : _error != null
                  ? PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load tickets', message: _error)
                  : list.isEmpty
                      ? const PremiumEmpty(icon: Icons.confirmation_number_rounded, title: 'No tickets', message: 'Raise a ticket whenever something blocks your work.')
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final t = list[i];
                              final st = '${t['status'] ?? 'open'}';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: PremiumCard(
                                  onTap: () => _open(t),
                                  padding: const EdgeInsets.all(14),
                                  child: Row(children: [
                                    IconBubble(icon: Icons.confirmation_number_rounded, color: _statusColor(st)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('${t['subject']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary)),
                                        Text('${t['ticketNumber'] ?? ''} · ${t['raisedByName'] ?? ''} · ${relTime(DateTime.tryParse('${t['createdAt']}'))}',
                                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
                                      ]),
                                    ),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Pill(label: st.replaceAll('_', ' '), color: _statusColor(st)),
                                      const SizedBox(height: 4),
                                      Text('${(t['replies'] as List?)?.length ?? 0} replies', style: AppText.body(size: 10.5, color: AppColors.textTertiary)),
                                    ]),
                                  ]),
                                ),
                              ).stagger(i);
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}
