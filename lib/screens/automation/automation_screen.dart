import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

/// Follow-up automation + lead routing (web: /admin/automation & /admin/settings).
class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  bool? _enabled;
  double _reminder = 15;
  double _escalation = 60;
  String? _assign;
  bool _saving = false;
  bool _running = false;
  bool _syncing = false;

  String get _orgId => context.read<AuthProvider>().user!.activeOrgId!;

  void _hydrate(Map<String, dynamic> s) {
    if (_enabled != null) return;
    final f = Map<String, dynamic>.from(s['followUpAutomation'] ?? {});
    _enabled = f['enabled'] == true;
    _reminder = ((f['reminderMinutesBefore'] as num?) ?? 15).toDouble().clamp(5, 1440);
    _escalation = ((f['overdueEscalationMinutes'] as num?) ?? 60).toDouble().clamp(0, 1440);
    _assign = '${s['autoAssign'] ?? 'round-robin'}';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<SettingsProvider>().updateSettings({
        'autoAssign': _assign,
        'followUpAutomation': {
          'enabled': _enabled,
          'reminderMinutesBefore': _reminder.round(),
          'overdueEscalationMinutes': _escalation.round(),
        },
      });
      if (mounted) AppToast.success(context, 'Automation saved');
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not save settings');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(double m) => m >= 60 ? '${(m / 60).toStringAsFixed(m % 60 == 0 ? 0 : 1)} h' : '${m.round()} min';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    _hydrate(settings);
    final tasks = context.watch<LeadsProvider>().followUps.where((f) => f.isOpen).toList();
    final soon = tasks.where((t) => t.dueAt != null && !t.isOverdue && t.dueAt!.difference(DateTime.now()).inMinutes <= 60).length;
    final templates = context.watch<ChatProvider>().templates.length;

    return Scaffold(
      appBar: const PremiumAppBar(title: 'Automation', subtitle: 'Lead routing · reminders · escalations'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        Row(children: [
          Expanded(child: KpiTile(label: 'Open tasks', value: tasks.length, icon: Icons.event_note_rounded)),
          const SizedBox(width: 10),
          Expanded(child: KpiTile(label: 'Due in 1h', value: soon, icon: Icons.timer_rounded, color: AppColors.warning)),
          const SizedBox(width: 10),
          Expanded(child: KpiTile(label: 'Overdue', value: tasks.where((t) => t.isOverdue).length, icon: Icons.alarm_rounded, color: AppColors.error)),
        ]),
        const SizedBox(height: 14),
        TitledCard(
          title: 'New lead routing',
          margin: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How WhatsApp, Meta ad and website leads are assigned automatically', style: AppText.body(size: 12.5, color: AppColors.textTertiary)),
            const SizedBox(height: 10),
            ChoiceChips<String>(
              options: const ['round-robin', 'workload'],
              selected: _assign,
              label: (s) => s == 'workload' ? '⚖️ Least workload' : '🔁 Round robin',
              onSelected: (s) => setState(() => _assign = s),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        TitledCard(
          title: 'Follow-up reminders',
          margin: EdgeInsets.zero,
          trailing: Switch.adaptive(value: _enabled ?? false, onChanged: (v) => setState(() => _enabled = v)),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: (_enabled ?? false) ? 1 : 0.45,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Remind the owner ${_fmt(_reminder)} before a follow-up is due', style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary)),
              Slider(value: _reminder, min: 5, max: 1440, divisions: 95, activeColor: AppColors.primary, label: _fmt(_reminder), onChanged: (_enabled ?? false) ? (v) => setState(() => _reminder = v) : null),
              Text(_escalation == 0 ? 'Never escalate overdue tasks' : 'Alert admins when a task is ${_fmt(_escalation)} overdue',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary)),
              Slider(value: _escalation, min: 0, max: 1440, divisions: 96, activeColor: AppColors.error, label: _fmt(_escalation), onChanged: (_enabled ?? false) ? (v) => setState(() => _escalation = v) : null),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        GlowButton(label: 'Save automation', icon: Icons.save_rounded, loading: _saving, onPressed: _save),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: GlowButton(
              label: 'Run now',
              icon: Icons.play_arrow_rounded,
              variant: GlowVariant.dark,
              loading: _running,
              onPressed: () async {
                setState(() => _running = true);
                try {
                  final r = await AutomationApi.runNow(_orgId);
                  if (mounted) AppToast.success(context, 'Done · ${r['reminders'] ?? 0} reminders, ${r['escalations'] ?? 0} escalations');
                } on ApiException catch (e) {
                  if (mounted) AppToast.error(context, e.message);
                } finally {
                  if (mounted) setState(() => _running = false);
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlowButton(
              label: 'Sync templates ($templates)',
              icon: Icons.sync_rounded,
              variant: GlowVariant.ghost,
              loading: _syncing,
              onPressed: () async {
                setState(() => _syncing = true);
                try {
                  final r = await IntegrationsApi.templatesSync(_orgId);
                  if (mounted) AppToast.success(context, '${r['available'] ?? 0} of ${r['total'] ?? 0} templates available');
                } on ApiException catch (e) {
                  if (mounted) AppToast.error(context, e.message);
                } finally {
                  if (mounted) setState(() => _syncing = false);
                }
              },
            ),
          ),
        ]),
        const SizedBox(height: 18),
        PremiumCard(
          gradient: const LinearGradient(colors: [AppColors.orange50, AppColors.cream200]),
          child: Row(children: [
            const IconBubble(icon: Icons.account_tree_rounded, gradient: true),
            const SizedBox(width: 12),
            Expanded(child: Text('Need more? Build if-this-then-that rules in Workflows — e.g. auto-send a welcome template to every Meta ad lead.', style: AppText.body(size: 13, color: AppColors.textSecondary))),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text('Last saved ${relTime(DateTime.tryParse('${settings['updatedAt'] ?? ''}'))}', style: AppText.body(size: 11, color: AppColors.textTertiary))),
      ]),
    );
  }
}
