import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/team_provider.dart';
import '../../services/crm_api.dart';
import '../leads/leads_screen.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

class EmployeeDetailScreen extends StatelessWidget {
  final String uid;
  const EmployeeDetailScreen({super.key, required this.uid});

  String _orgId(BuildContext c) => c.read<AuthProvider>().user!.activeOrgId!;

  Future<void> _setGoal(BuildContext context, int current) async {
    final ctrl = TextEditingController(text: current > 0 ? '$current' : '');
    final v = await showPremiumSheet<int>(
      context,
      title: 'Monthly closing goal',
      subtitle: 'Number of Closed-Won deals per month',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.display(size: 28),
          decoration: const InputDecoration(hintText: '0'),
        ),
        const SizedBox(height: 16),
        GlowButton(label: 'Save goal', onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text) ?? 0)),
      ]),
    );
    if (v == null || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_orgId(context))
          .collection('goals')
          .doc('config')
          .set({uid: v, 'orgId': _orgId(context)}, SetOptions(merge: true));
      if (context.mounted) AppToast.success(context, 'Goal updated');
    } catch (_) {
      if (context.mounted) AppToast.error(context, 'Could not save goal');
    }
  }

  Future<void> _reassignAll(BuildContext context) async {
    final others = context.read<TeamProvider>().activeMembers.where((m) => m.id != uid).toList();
    final to = await showPremiumSheet<String>(
      context,
      title: 'Move all open leads',
      subtitle: 'Open leads and their follow-ups move to the selected teammate',
      builder: (ctx) => Column(
        children: others.map((m) => PremiumTile(icon: Icons.person_rounded, title: m.name, subtitle: m.role, onTap: () => Navigator.pop(ctx, m.id))).toList(),
      ),
    );
    if (to == null || !context.mounted) return;
    try {
      final n = await TeamApi.reassignAll(orgId: _orgId(context), fromUid: uid, toUid: to);
      if (context.mounted) AppToast.success(context, '$n leads moved');
    } on ApiException catch (e) {
      if (context.mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<TeamProvider>().getMemberById(uid);
    final leads = context.watch<LeadsProvider>().leads.where((l) => l.assignedTo == uid).toList();
    final goals = context.watch<SettingsProvider>().goals;
    final me = context.read<AuthProvider>().user?.uid;

    if (member == null) {
      return const Scaffold(appBar: PremiumAppBar(title: 'Team member'), body: PremiumEmpty(icon: Icons.person_off_rounded, title: 'Member not found', message: 'They may have been deactivated.'));
    }

    final won = leads.where((l) => l.isWon).length;
    final lost = leads.where((l) => l.status == 'Lost').length;
    final open = leads.where((l) => !l.isClosed).length;
    final stale = leads.where((l) => !l.isClosed && l.updatedAt != null && DateTime.now().difference(l.updatedAt!).inDays >= 3).length;
    final conv = (won + lost) == 0 ? 0.0 : won * 100 / (won + lost);
    final goal = (goals[uid] as num?)?.toInt() ?? 0;
    final isOwner = member.role == 'owner';

    return Scaffold(
      appBar: PremiumAppBar(
        title: member.name,
        subtitle: '${member.role} · ${member.phone ?? ''}',
        actions: [
          if (!isOwner && member.id != me)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (v) async {
                try {
                  if (v == 'role') {
                    await TeamApi.setRole(orgId: _orgId(context), uid: uid, role: member.isAdmin ? 'employee' : 'admin');
                    if (context.mounted) AppToast.success(context, 'Role updated');
                  } else if (v == 'deactivate') {
                    final ok = await confirmAction(context,
                        title: 'Deactivate ${member.name}?', message: 'They lose access immediately and their seat is freed. Move their leads first.', confirmLabel: 'Deactivate', destructive: true);
                    if (!ok || !context.mounted) return;
                    await TeamApi.setStatus(orgId: _orgId(context), uid: uid, active: false);
                    if (context.mounted) {
                      AppToast.success(context, '${member.name} deactivated');
                      context.pop();
                    }
                  }
                } on ApiException catch (e) {
                  if (context.mounted) AppToast.error(context, e.message);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'role', child: Text(member.isAdmin ? 'Make employee' : 'Make admin')),
                const PopupMenuItem(value: 'deactivate', child: Text('Deactivate', style: TextStyle(color: AppColors.error))),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        physics: const BouncingScrollPhysics(),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              KpiTile(label: 'Open leads', value: open, icon: Icons.people_alt_rounded),
              KpiTile(label: 'Closed-won', value: won, icon: Icons.emoji_events_rounded, color: AppColors.success),
              KpiTile(label: 'Win rate', value: conv, suffix: '%', icon: Icons.trending_up_rounded, color: AppColors.signal),
              KpiTile(label: 'Idle 3+ days', value: stale, icon: Icons.hourglass_bottom_rounded, color: AppColors.warning),
            ].asMap().entries.map((e) => e.value.stagger(e.key)).toList(),
          ),
          const SizedBox(height: 12),
          TitledCard(
            title: 'Monthly goal',
            margin: EdgeInsets.zero,
            trailing: TextButton(onPressed: () => _setGoal(context, goal), child: Text(goal > 0 ? 'Edit' : 'Set goal')),
            child: goal > 0
                ? MetricBar(label: 'Closed-won vs goal', value: won, max: goal, trailing: '$won / $goal')
                : Text('Set a target to track progress on the dashboard.', style: AppText.body(size: 13, color: AppColors.textTertiary)),
          ),
          const SizedBox(height: 12),
          if (open > 0) GlowButton(label: 'Move all open leads', icon: Icons.swap_horiz_rounded, variant: GlowVariant.dark, onPressed: () => _reassignAll(context)),
          SectionTitle('Leads (${leads.length})', padding: const EdgeInsets.fromLTRB(4, 20, 4, 10)),
          if (leads.isEmpty) Text('No leads assigned.', style: AppText.body(size: 13, color: AppColors.textTertiary)),
          ...leads.take(50).map((l) => LeadCard(lead: l, compact: true)),
          if (leads.length > 50) Text('+${leads.length - 50} more · ${relTime(leads.last.createdAt)}', style: AppText.body(size: 12, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
