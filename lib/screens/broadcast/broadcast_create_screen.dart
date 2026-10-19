import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/team_provider.dart';
import '../../services/crm_api.dart';
import '../leads/lead_action_sheets.dart';
import '../widgets/premium.dart';

/// Campaign builder: template → audience (status / source / owner) →
/// live audience preview → send now or schedule.
class BroadcastCreateScreen extends StatefulWidget {
  const BroadcastCreateScreen({super.key});

  @override
  State<BroadcastCreateScreen> createState() => _BroadcastCreateScreenState();
}

class _BroadcastCreateScreenState extends State<BroadcastCreateScreen> {
  final _name = TextEditingController();
  Map<String, dynamic>? _template;
  List<TextEditingController> _params = [];
  String? _status;
  String? _source;
  String? _owner;
  DateTime? _scheduleAt;
  int? _audience;
  bool _previewing = false;
  bool _sending = false;
  Timer? _debounce;

  String get _orgId => context.read<AuthProvider>().user!.activeOrgId!;

  Map<String, String> get _filters => {
        if (_status != null) 'status': _status!,
        if (_source != null) 'source': _source!,
        if (_owner != null) 'assignedTo': _owner!,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preview());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    for (final c in _params) {
      c.dispose();
    }
    super.dispose();
  }

  void _preview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _previewing = true);
      try {
        final r = await BroadcastApi.preview(orgId: _orgId, filters: _filters.isEmpty ? null : _filters);
        if (mounted) setState(() => _audience = (r['count'] as num?)?.toInt());
      } catch (_) {
        if (mounted) setState(() => _audience = null);
      } finally {
        if (mounted) setState(() => _previewing = false);
      }
    });
  }

  void _pickTemplate(Map<String, dynamic> t) {
    final n = (t['parameterCount'] as num?)?.toInt() ?? 0;
    setState(() {
      _template = t;
      _params = List.generate(n, (_) => TextEditingController());
    });
  }

  Future<void> _send() async {
    if (_template == null) return AppToast.error(context, 'Choose a template');
    final values = _params.map((c) => c.text.trim()).toList();
    if (values.any((v) => v.isEmpty)) return AppToast.error(context, 'Fill every template value');
    if ((_audience ?? 0) == 0) return AppToast.error(context, 'No leads match this audience');
    final ok = await confirmAction(
      context,
      title: _scheduleAt == null ? 'Send now?' : 'Schedule broadcast?',
      message: '"${_template!['name']}" will go to $_audience lead${_audience == 1 ? '' : 's'}${_scheduleAt == null ? ' immediately' : ' on ${DateFormat('d MMM, h:mm a').format(_scheduleAt!)}'}.',
      confirmLabel: _scheduleAt == null ? 'Send' : 'Schedule',
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      final r = await BroadcastApi.create(
        orgId: _orgId,
        templateId: _template!['id'].toString(),
        parameters: values,
        filters: _filters,
        name: _name.text,
        scheduledAt: _scheduleAt,
      );
      if (!mounted) return;
      AppToast.success(context, r['scheduled'] == true ? 'Scheduled for ${r['totalRecipients']} leads' : 'Sending to ${r['totalRecipients']} leads 🚀');
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _filterChip<T>(String label, T? value, List<T> options, String Function(T) text, void Function(T?) onPick) {
    return Pressable(
      onTap: () async {
        final picked = await showPremiumSheet<Object>(
          context,
          title: label,
          builder: (ctx) => Column(children: [
            PremiumTile(icon: Icons.all_inclusive_rounded, title: 'Any', onTap: () => Navigator.pop(ctx, '__any__')),
            ...options.map((o) => PremiumTile(icon: Icons.check_circle_outline_rounded, title: text(o), onTap: () => Navigator.pop(ctx, o))),
          ]),
        );
        if (picked == null) return;
        onPick(picked == '__any__' ? null : picked as T);
        _preview();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value != null ? AppColors.orange50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value != null ? AppColors.primary : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ', style: AppText.body(size: 12.5, color: AppColors.textTertiary)),
          Text(value == null ? 'Any' : text(value), style: AppText.body(size: 12.5, weight: FontWeight.w700, color: value != null ? AppColors.primaryDark : AppColors.textPrimary)),
          const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = context.watch<ChatProvider>().templates.where((t) => (t['status'] ?? 'APPROVED') == 'APPROVED' && t['supported'] != false).toList();
    final statuses = context.watch<SettingsProvider>().statuses;
    final sources = context.watch<LeadsProvider>().leads.map((l) => l.source).whereType<String>().where((s) => s.isNotEmpty).toSet().toList()..sort();
    final team = context.watch<TeamProvider>().activeMembers;

    return Scaffold(
      appBar: const PremiumAppBar(title: 'New broadcast', subtitle: 'Template · audience · schedule'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), physics: const BouncingScrollPhysics(), children: [
        _Step(n: 1, title: 'Choose an approved template'),
        if (templates.isEmpty)
          const PremiumEmpty(icon: Icons.dashboard_customize_rounded, title: 'No approved templates', message: 'Sync templates from Integrations → WhatsApp.')
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = templates[i];
                final sel = _template?['id'] == t['id'];
                return Pressable(
                  onTap: () => _pickTemplate(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 210,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.orange50 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.6 : 1),
                      boxShadow: sel ? AppColors.glow(AppColors.orange500, 0.18) : AppColors.cardShadow,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text((t['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.textPrimary))),
                        if (sel) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                      ]),
                      const SizedBox(height: 6),
                      Expanded(child: Text((t['preview'] ?? '').toString(), maxLines: 4, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11.8, color: AppColors.textTertiary))),
                      Pill(label: '${t['category'] ?? 'UTILITY'} · ${t['language'] ?? ''}', color: AppColors.signal),
                    ]),
                  ),
                );
              },
            ),
          ),
        if (_params.isNotEmpty) ...[
          for (var i = 0; i < _params.length; i++) ...[
            FieldLabel('Value for {{${i + 1}}}'),
            TextField(controller: _params[i], decoration: const InputDecoration(hintText: 'Same value is used for every recipient')),
          ],
        ],
        const SizedBox(height: 22),
        _Step(n: 2, title: 'Pick your audience'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _filterChip<String>('Status', _status, statuses, (s) => s, (v) => setState(() => _status = v)),
          _filterChip<String>('Source', _source, sources, (s) => s, (v) => setState(() => _source = v)),
          _filterChip<String>('Owner', _owner, team.map((m) => m.id).toList(), (id) => team.firstWhere((m) => m.id == id).name, (v) => setState(() => _owner = v)),
        ]),
        const SizedBox(height: 12),
        PremiumCard(
          gradient: const LinearGradient(colors: [AppColors.midnight900, AppColors.midnight700]),
          child: Row(children: [
            const IconBubble(icon: Icons.groups_rounded, color: AppColors.orange400, gradient: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Audience', style: AppText.body(size: 12, color: AppColors.textOnDarkMuted)),
                _previewing
                    ? const Padding(padding: EdgeInsets.only(top: 6), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange400)))
                    : AnimatedCount(value: _audience ?? 0, suffix: ' leads', style: AppText.display(size: 24, color: Colors.white)),
              ]),
            ),
            Text('valid WhatsApp\nnumbers only', textAlign: TextAlign.right, style: AppText.body(size: 11, color: AppColors.textOnDarkMuted)),
          ]),
        ),
        const SizedBox(height: 22),
        _Step(n: 3, title: 'Name & schedule'),
        TextField(controller: _name, decoration: const InputDecoration(hintText: 'Campaign name (optional)')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ChoiceChips<bool>(
              options: const [false, true],
              selected: _scheduleAt != null,
              label: (b) => b ? 'Schedule' : 'Send now',
              onSelected: (b) async {
                if (!b) return setState(() => _scheduleAt = null);
                final dt = await pickFollowUpDateTime(context, initial: DateTime.now().add(const Duration(hours: 1)));
                if (dt != null) setState(() => _scheduleAt = dt);
              },
            ),
          ),
          if (_scheduleAt != null) Text(DateFormat('d MMM · h:mm a').format(_scheduleAt!), style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.primaryDark)),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: GlowButton(
          label: _scheduleAt == null ? 'Send to ${_audience ?? 0} leads' : 'Schedule for ${_audience ?? 0} leads',
          icon: _scheduleAt == null ? Icons.rocket_launch_rounded : Icons.schedule_send_rounded,
          loading: _sending,
          onPressed: _template == null ? null : _send,
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  const _Step({required this.n, required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
            child: Text('$n', style: AppText.body(size: 12.5, weight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Text(title, style: AppText.display(size: 16, weight: FontWeight.w700)),
        ]),
      );
}
