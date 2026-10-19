import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/team_member_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/team_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/premium.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  Future<void> _invite(BuildContext context) async {
    final org = context.read<BillingProvider>().org;
    if (org != null && org.seatsAvailable <= 0) {
      final go = await confirmAction(context, title: 'All seats are used', message: 'Your plan has ${org.seatsLimit} seats. Add seats or upgrade to invite more teammates.', confirmLabel: 'View plans');
      if (go && context.mounted) context.push('/billing');
      return;
    }
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    String role = 'employee';
    bool busy = false;
    await showPremiumSheet(
      context,
      title: 'Invite teammate',
      subtitle: 'They sign in with this mobile number — no password needed',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Full name'),
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Rahul Verma')),
          const FieldLabel('Mobile number'),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: '10-digit mobile', prefixText: '+91  ', counterText: ''),
          ),
          const FieldLabel('Email (optional)'),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'name@company.com')),
          const FieldLabel('Role'),
          ChoiceChips<String>(
            options: const ['employee', 'admin'],
            selected: role,
            label: (r) => r == 'admin' ? 'Admin — full access' : 'Employee — own leads',
            onSelected: (r) => setS(() => role = r),
          ),
          const SizedBox(height: 22),
          GlowButton(
            label: 'Send invite',
            icon: Icons.send_rounded,
            loading: busy,
            onPressed: () async {
              if (name.text.trim().isEmpty || phone.text.length != 10) {
                AppToast.error(context, 'Enter a name and a valid 10-digit number');
                return;
              }
              setS(() => busy = true);
              try {
                await TeamApi.invite(
                  orgId: context.read<AuthProvider>().user!.activeOrgId!,
                  name: name.text.trim(),
                  phone: phone.text.trim(),
                  email: email.text.trim(),
                  role: role,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) AppToast.success(context, 'Invite sent — ${name.text.trim()} can now sign in with +91 ${phone.text}');
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

  @override
  Widget build(BuildContext context) {
    final team = context.watch<TeamProvider>();
    final org = context.watch<BillingProvider>().org;
    final leads = context.watch<LeadsProvider>().leads;
    final goals = context.watch<SettingsProvider>().goals;

    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Team',
        subtitle: org == null ? '${team.members.length} members' : '${org.seatsUsed}/${org.seatsLimit} seats used',
        actions: [IconButton(icon: const Icon(Icons.person_add_alt_1_rounded), onPressed: () => _invite(context))],
      ),
      body: team.isLoading
          ? const SkeletonList()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              physics: const BouncingScrollPhysics(),
              children: [
                if (org != null)
                  PremiumCard(
                    gradient: const LinearGradient(colors: [AppColors.orange50, AppColors.cream200]),
                    child: Row(children: [
                      const IconBubble(icon: Icons.event_seat_rounded, gradient: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${org.seatsAvailable} seat${org.seatsAvailable == 1 ? '' : 's'} available', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          MetricBar(label: '${org.planName} plan', value: org.seatsUsed, max: org.seatsLimit, trailing: '${org.seatsUsed}/${org.seatsLimit}'),
                        ]),
                      ),
                    ]),
                  ).stagger(0),
                const SizedBox(height: 6),
                const SectionTitle('Members', padding: EdgeInsets.fromLTRB(4, 14, 4, 10)),
                ...team.members.asMap().entries.map((e) {
                  final m = e.value;
                  final mine = leads.where((l) => l.assignedTo == m.id).toList();
                  final won = mine.where((l) => l.isWon).length;
                  final goal = (goals[m.id] as num?)?.toInt() ?? 0;
                  return _MemberCard(member: m, open: mine.where((l) => !l.isClosed).length, won: won, goal: goal).stagger(e.key + 1);
                }),
                if (team.pendingInvites.isNotEmpty) ...[
                  const SectionTitle('Pending invites', padding: EdgeInsets.fromLTRB(4, 18, 4, 10)),
                  ...team.pendingInvites.map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PremiumCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            GradientAvatar(name: i.name, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(i.name, style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.textPrimary)),
                                Text(i.phone ?? '', style: AppText.mono(size: 12, color: AppColors.textTertiary, weight: FontWeight.w500)),
                              ]),
                            ),
                            Pill(label: 'Invited · ${i.role}', color: AppColors.warning, icon: Icons.schedule_send_rounded),
                          ]),
                        ),
                      )),
                ],
                const SizedBox(height: 18),
                GlowButton(label: 'Invite teammate', icon: Icons.person_add_alt_1_rounded, onPressed: () => _invite(context)),
              ],
            ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TeamMemberModel member;
  final int open;
  final int won;
  final int goal;
  const _MemberCard({required this.member, required this.open, required this.won, required this.goal});

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthProvider>().user?.uid == member.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: PremiumCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/team/${member.id}'),
        child: Column(children: [
          Row(children: [
            GradientAvatar(name: member.name, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14.5, weight: FontWeight.w700, color: AppColors.textPrimary))),
                  if (me) ...[const SizedBox(width: 6), const Pill(label: 'You', color: AppColors.success)],
                ]),
                Text(member.phone ?? '', style: AppText.mono(size: 12, color: AppColors.textTertiary, weight: FontWeight.w500)),
              ]),
            ),
            Pill(label: member.role, color: member.isAdmin ? AppColors.signal : AppColors.info),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _Stat(label: 'Open', value: open),
            _Stat(label: 'Won', value: won, color: AppColors.success),
            Expanded(
              flex: 2,
              child: goal > 0
                  ? MetricBar(label: 'Monthly goal', value: won, max: goal, color: AppColors.primary, trailing: '$won/$goal')
                  : Text('No goal set', style: AppText.body(size: 12, color: AppColors.textTertiary)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedCount(value: value, style: AppText.display(size: 18, color: color)),
          Text(label, style: AppText.body(size: 11, color: AppColors.textTertiary)),
        ]),
      );
}
