import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/followup_model.dart';
import '../../models/lead_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/inbox_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/team_provider.dart';
import '../leads/lead_action_sheets.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final leadsP = context.watch<LeadsProvider>();
    final user = auth.user;
    final isAdmin = user?.isAdmin ?? false;
    final leads = leadsP.leads.where((l) => !l.blacklisted).toList();
    final tasks = leadsP.followUps.where((f) => f.isOpen).toList();
    final stats = _Stats(leads, tasks);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await context.read<BillingProvider>().refreshQuota();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _Hero(stats: stats, isAdmin: isAdmin)),
            SliverToBoxAdapter(child: _QuickActions(isAdmin: isAdmin)),
            const SliverToBoxAdapter(child: _TrialBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.32,
                  children: [
                    KpiTile(label: 'New today', value: stats.newToday, icon: Icons.fiber_new_rounded, color: AppColors.info, onTap: () => context.go('/leads')),
                    KpiTile(label: 'Due today', value: stats.dueToday, icon: Icons.today_rounded, color: AppColors.orange600, onTap: () => context.go('/followups')),
                    KpiTile(
                        label: 'Overdue',
                        value: stats.overdue,
                        icon: Icons.alarm_rounded,
                        color: AppColors.error,
                        hint: stats.overdue > 0 ? 'Needs attention' : 'All clear',
                        onTap: () => context.go('/followups')),
                    KpiTile(label: 'Hot leads', value: stats.hot, icon: Icons.local_fire_department_rounded, color: AppColors.ember500),
                  ].asMap().entries.map((e) => e.value.stagger(e.key)).toList(),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _TrendCard(leads: leads).stagger(4)),
            SliverToBoxAdapter(child: _StatusCard(leads: leads).stagger(5)),
            if (isAdmin) SliverToBoxAdapter(child: _SourcesCard(leads: leads).stagger(6)),
            if (isAdmin) SliverToBoxAdapter(child: _TeamCard(leads: leads).stagger(7)),
            SliverToBoxAdapter(child: _TodayTasks(tasks: tasks)),
            SliverToBoxAdapter(child: _RecentLeads(leads: leads)),
            if (isAdmin) const SliverToBoxAdapter(child: _ActivityFeed()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _Stats {
  final List<LeadModel> leads;
  final List<FollowUpModel> tasks;
  _Stats(this.leads, this.tasks);

  static bool _sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  int get total => leads.length;
  int get active => leads.where((l) => !l.isClosed).length;
  int get won => leads.where((l) => l.isWon).length;
  int get lost => leads.where((l) => l.status == 'Lost').length;
  int get newToday => leads.where((l) => _sameDay(l.createdAt, DateTime.now())).length;
  int get hot => leads.where((l) => l.isHot && !l.isClosed).length;
  int get dueToday => tasks.where((t) => t.isDueToday && !t.isOverdue).length;
  int get overdue => tasks.where((t) => t.isOverdue).length;
  int get wonThisMonth {
    final n = DateTime.now();
    return leads.where((l) => l.isWon && l.updatedAt != null && l.updatedAt!.year == n.year && l.updatedAt!.month == n.month).length;
  }

  double get conversion => (won + lost) == 0 ? 0 : won * 100 / (won + lost);
  int get untouched => leads.where((l) => !l.isClosed && l.updatedAt != null && DateTime.now().difference(l.updatedAt!).inDays >= 3).length;
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class _Hero extends StatelessWidget {
  final _Stats stats;
  final bool isAdmin;
  const _Hero({required this.stats, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final unread = context.watch<NotificationsProvider>().unreadCount;
    final firstName = (user?.name ?? '').split(' ').first;
    final multiOrg = (user?.memberships.length ?? 0) > 1;

    return AuroraBackground(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pressable(
                onTap: multiOrg ? () => showOrgSwitcher(context) : null,
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  radius: 14,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.apartment_rounded, size: 15, color: AppColors.orange300),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: Text(user?.activeOrgName ?? 'Workspace',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12.5, weight: FontWeight.w600, color: Colors.white)),
                    ),
                    if (multiOrg) const Icon(Icons.unfold_more_rounded, size: 15, color: AppColors.textOnDarkMuted),
                  ]),
                ),
              ),
              const Spacer(),
              _HeroIcon(icon: Icons.support_agent_rounded, onTap: () => context.push('/support')),
              const SizedBox(width: 8),
              _HeroIcon(icon: Icons.notifications_none_rounded, badge: unread, onTap: () => context.push('/notifications')),
            ]),
            const SizedBox(height: 22),
            Text('${_greeting()},', style: AppText.body(size: 15, color: AppColors.textOnDarkMuted)).animate().fadeIn(duration: 400.ms),
            Text(firstName.isEmpty ? 'there' : firstName, style: AppText.display(size: 30, color: Colors.white, letterSpacing: -1))
                .animate()
                .fadeIn(delay: 80.ms, duration: 500.ms)
                .slideX(begin: -0.05),
            const SizedBox(height: 18),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              radius: 24,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isAdmin ? 'ACTIVE PIPELINE' : 'MY PIPELINE',
                        style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.textOnDarkMuted).copyWith(letterSpacing: 1.1)),
                    const SizedBox(height: 4),
                    AnimatedCount(value: stats.active, style: AppText.display(size: 38, color: Colors.white, letterSpacing: -1.5)),
                    Text('of ${stats.total} leads', style: AppText.body(size: 12, color: AppColors.textOnDarkMuted)),
                  ]),
                ),
                Container(width: 1, height: 64, color: Colors.white12),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _MiniStat(label: 'Won this month', value: stats.wonThisMonth.toDouble()),
                  const SizedBox(height: 10),
                  _MiniStat(label: 'Win rate', value: stats.conversion, suffix: '%'),
                ]),
              ]),
            ).animate().fadeIn(delay: 160.ms, duration: 500.ms).slideY(begin: 0.1),
          ]),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final String suffix;
  const _MiniStat({required this.label, required this.value, this.suffix = ''});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedCount(value: value, suffix: suffix, style: AppText.display(size: 20, color: AppColors.orange300)),
        Text(label, style: AppText.body(size: 11, color: AppColors.textOnDarkMuted)),
      ]);
}

class _HeroIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  const _HeroIcon({required this.icon, this.badge = 0, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          GlassPanel(padding: const EdgeInsets.all(9), radius: 14, child: Icon(icon, size: 20, color: Colors.white)),
          if (badge > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: AppColors.orange500, borderRadius: BorderRadius.circular(9)),
                child: Text(badge > 9 ? '9+' : '$badge', style: AppText.body(size: 10, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
        ]),
      );
}

class _QuickActions extends StatelessWidget {
  final bool isAdmin;
  const _QuickActions({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<InboxProvider>().totalUnread;
    final items = <(IconData, String, Color, VoidCallback)>[
      if (isAdmin) (Icons.person_add_alt_1_rounded, 'New lead', AppColors.primary, () => showAddLeadSheet(context)),
      (Icons.forum_rounded, unread > 0 ? 'Inbox · $unread' : 'Inbox', AppColors.whatsappDark, () => context.go('/inbox')),
      if (isAdmin) (Icons.campaign_rounded, 'Broadcast', AppColors.signal, () => context.push('/broadcasts')),
      if (isAdmin) (Icons.ads_click_rounded, 'Meta ads', AppColors.meta, () => context.push('/meta-ads')),
      if (!isAdmin) (Icons.event_available_rounded, 'My tasks', AppColors.orange600, () => context.go('/followups')),
      if (!isAdmin) (Icons.confirmation_number_rounded, 'Tickets', AppColors.ember500, () => context.push('/tickets')),
      if (!isAdmin) (Icons.forum_outlined, 'Team chat', AppColors.info, () => context.push('/chat')),
    ];
    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (icon, label, color, onTap) = items[i];
          return Pressable(
            onTap: onTap,
            child: Container(
              width: 92,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconBubble(icon: icon, color: color, size: 36, gradient: true),
                const SizedBox(height: 8),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11.5, weight: FontWeight.w600, color: AppColors.textPrimary)),
              ]),
            ),
          ).stagger(i, stepMs: 35);
        },
      ),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner();

  @override
  Widget build(BuildContext context) {
    final org = context.watch<BillingProvider>().org;
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    if (org == null || !isAdmin) return const SizedBox.shrink();
    final show = org.isTrialing || org.isExpired || org.isPastDue;
    if (!show) return const SizedBox.shrink();
    final expired = org.isExpired;
    final text = expired
        ? 'Your plan has expired — upgrade to keep receiving leads.'
        : org.isPastDue
            ? 'Payment is past due — update billing to avoid interruption.'
            : '${org.trialDaysLeft} day${org.trialDaysLeft == 1 ? '' : 's'} left in your free trial.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: PremiumCard(
        onTap: () => context.push('/billing'),
        gradient: expired ? null : const LinearGradient(colors: [AppColors.orange50, AppColors.cream200]),
        color: expired ? AppColors.errorLight : null,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconBubble(icon: expired ? Icons.lock_clock_rounded : Icons.workspace_premium_rounded, color: expired ? AppColors.error : AppColors.primary, gradient: true),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary))),
          Text('Upgrade', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.primaryDark)),
        ]),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<LeadModel> leads;
  const _TrendCard({required this.leads});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(14, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 13 - i)));
    int countOn(DateTime d, bool Function(LeadModel) f, DateTime? Function(LeadModel) at) =>
        leads.where((l) => f(l) && at(l) != null && at(l)!.year == d.year && at(l)!.month == d.month && at(l)!.day == d.day).length;
    final created = days.map((d) => countOn(d, (_) => true, (l) => l.createdAt).toDouble()).toList();
    final won = days.map((d) => countOn(d, (l) => l.isWon, (l) => l.updatedAt).toDouble()).toList();
    final maxY = math.max(4.0, [...created, ...won].fold<double>(0, math.max) * 1.25);
    final total = created.fold<double>(0, (a, b) => a + b).toInt();

    LineChartBarData line(List<double> v, Color c, {bool fill = false}) => LineChartBarData(
          spots: [for (var i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])],
          isCurved: true,
          curveSmoothness: 0.32,
          color: c,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: fill,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0)]),
          ),
        );

    return TitledCard(
      title: 'Lead flow · 14 days',
      trailing: Pill(label: '$total new', color: AppColors.primaryDark),
      child: Column(children: [
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1, dashArray: [4, 4]),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 3,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${days[i].day}/${days[i].month}', style: AppText.body(size: 10, color: AppColors.textTertiary)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.midnight900,
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem('${s.y.toInt()} ${s.barIndex == 0 ? 'new' : 'won'}',
                          AppText.body(size: 12, weight: FontWeight.w700, color: Colors.white)))
                      .toList(),
                ),
              ),
              lineBarsData: [line(created, AppColors.primary, fill: true), line(won, AppColors.success)],
            ),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: const [
          _Legend(color: AppColors.primary, label: 'New leads'),
          SizedBox(width: 16),
          _Legend(color: AppColors.success, label: 'Closed-won'),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: AppText.body(size: 12, color: AppColors.textSecondary, weight: FontWeight.w500)),
      ]);
}

class _StatusCard extends StatefulWidget {
  final List<LeadModel> leads;
  const _StatusCard({required this.leads});

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final statuses = context.watch<SettingsProvider>().statuses;
    final counts = <String, int>{for (final s in statuses) s: 0};
    for (final l in widget.leads) {
      counts[l.status] = (counts[l.status] ?? 0) + 1;
    }
    final entries = counts.entries.where((e) => e.value > 0).toList();
    final total = widget.leads.length;
    if (total == 0) {
      return const TitledCard(
        title: 'Pipeline by status',
        child: Padding(padding: EdgeInsets.all(12), child: Text('No leads yet — your pipeline will appear here.')),
      );
    }
    return TitledCard(
      title: 'Pipeline by status',
      child: Row(children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(
              PieChartData(
                sectionsSpace: 2.5,
                centerSpaceRadius: 38,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(touchCallback: (e, r) {
                  setState(() => _touched = (e.isInterestedForInteractions && r?.touchedSection != null) ? r!.touchedSection!.touchedSectionIndex : -1);
                }),
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      color: AppColors.forStatus(entries[i].key),
                      radius: i == _touched ? 24 : 18,
                      showTitle: false,
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 500),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedCount(value: _touched >= 0 && _touched < entries.length ? entries[_touched].value : total, style: AppText.display(size: 20)),
              Text(_touched >= 0 && _touched < entries.length ? entries[_touched].key : 'total',
                  style: AppText.body(size: 10, color: AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: entries
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.5),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.forStatus(e.key), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12.5, color: AppColors.textSecondary))),
                        Text('${e.value}', style: AppText.mono(size: 12.5)),
                      ]),
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  final List<LeadModel> leads;
  const _SourcesCard({required this.leads});

  @override
  Widget build(BuildContext context) {
    final map = <String, int>{};
    for (final l in leads) {
      final s = (l.source == null || l.source!.isEmpty) ? 'Manual' : l.source!;
      map[s] = (map[s] ?? 0) + 1;
    }
    final top = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final metaCount = leads.where((l) => l.isFromMetaAd).length;
    if (top.isEmpty) return const SizedBox.shrink();
    final max = top.first.value;
    return TitledCard(
      title: 'Lead sources',
      trailing: metaCount > 0
          ? Pressable(onTap: () => context.push('/meta-ads'), child: Pill(label: '$metaCount from Meta ads', color: AppColors.meta, icon: Icons.ads_click_rounded))
          : null,
      child: Column(
        children: top.take(5).map((e) {
          final meta = e.key.toLowerCase().contains('meta') || e.key.toLowerCase().contains('facebook');
          final wa = e.key.toLowerCase().contains('whatsapp') && !meta;
          return MetricBar(
            label: e.key,
            value: e.value,
            max: max,
            color: meta ? AppColors.meta : (wa ? AppColors.whatsappDark : AppColors.primary),
          );
        }).toList(),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final List<LeadModel> leads;
  const _TeamCard({required this.leads});

  @override
  Widget build(BuildContext context) {
    final team = context.watch<TeamProvider>().members;
    if (team.isEmpty) return const SizedBox.shrink();
    final rows = team.map((m) {
      final mine = leads.where((l) => l.assignedTo == m.id).toList();
      final won = mine.where((l) => l.isWon).length;
      final lost = mine.where((l) => l.status == 'Lost').length;
      final open = mine.where((l) => !l.isClosed).length;
      final conv = (won + lost) == 0 ? 0.0 : won * 100 / (won + lost);
      return (m, mine.length, won, open, conv);
    }).toList()
      ..sort((a, b) => b.$3.compareTo(a.$3));

    return TitledCard(
      title: 'Team leaderboard',
      trailing: TextButton(onPressed: () => context.push('/team'), child: const Text('Manage')),
      child: Column(
        children: rows.take(5).toList().asMap().entries.map((e) {
          final (m, total, won, open, conv) = e.value;
          return Pressable(
            onTap: () => context.push('/team/${m.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                SizedBox(
                  width: 22,
                  child: Text('${e.key + 1}',
                      style: AppText.mono(size: 13, color: e.key == 0 ? AppColors.primary : AppColors.textTertiary)),
                ),
                GradientAvatar(name: m.name, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text('$open open · $total total', style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$won won', style: AppText.body(size: 12.5, weight: FontWeight.w700, color: AppColors.success)),
                  Text('${conv.toStringAsFixed(0)}% win', style: AppText.body(size: 11, color: AppColors.textTertiary)),
                ]),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TodayTasks extends StatelessWidget {
  final List<FollowUpModel> tasks;
  const _TodayTasks({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final list = tasks.where((t) => t.isOverdue || t.isDueToday).toList()
      ..sort((a, b) => (a.dueAt ?? DateTime.now()).compareTo(b.dueAt ?? DateTime.now()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Today\'s follow-ups', action: 'All tasks', onAction: () => context.go('/followups'), padding: const EdgeInsets.fromLTRB(20, 8, 20, 10)),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PremiumCard(
            child: Row(children: [
              const IconBubble(icon: Icons.celebration_rounded, color: AppColors.success),
              const SizedBox(width: 12),
              Expanded(child: Text('You\'re all caught up for today 🎉', style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.textPrimary))),
            ]),
          ),
        )
      else
        ...list.take(4).toList().asMap().entries.map((e) {
          final t = e.value;
          final color = t.isOverdue ? AppColors.error : AppColors.orange600;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: PremiumCard(
              padding: const EdgeInsets.all(12),
              onTap: () => showFollowUpActionsSheet(context, t, onOpenLead: () => context.push('/lead/${t.leadId}')),
              child: Row(children: [
                IconBubble(
                    icon: t.type == 'WhatsApp' ? Icons.chat_rounded : (t.type == 'Meeting' ? Icons.groups_rounded : Icons.call_rounded), color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.leadName ?? 'Lead', style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(t.title ?? '${t.type} follow-up', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: AppColors.textTertiary)),
                  ]),
                ),
                Pill(
                  label: t.isOverdue
                      ? 'Overdue'
                      : '${(t.dueAt!.hour % 12 == 0 ? 12 : t.dueAt!.hour % 12)}:${t.dueAt!.minute.toString().padLeft(2, '0')} ${t.dueAt!.hour < 12 ? 'AM' : 'PM'}',
                  color: color,
                ),
              ]),
            ),
          ).stagger(e.key);
        }),
    ]);
  }
}

class _RecentLeads extends StatelessWidget {
  final List<LeadModel> leads;
  const _RecentLeads({required this.leads});

  @override
  Widget build(BuildContext context) {
    final recent = [...leads]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Fresh leads', action: 'See all', onAction: () => context.go('/leads'), padding: const EdgeInsets.fromLTRB(20, 12, 20, 10)),
      SizedBox(
        height: 128,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: math.min(8, recent.length),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final l = recent[i];
            return PremiumCard(
              onTap: () => context.push('/lead/${l.id}'),
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 150,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    GradientAvatar(name: l.name, size: 34),
                    const Spacer(),
                    if (l.isFromMetaAd) const Icon(Icons.ads_click_rounded, size: 16, color: AppColors.meta),
                    if (l.isHot) const Icon(Icons.local_fire_department_rounded, size: 16, color: AppColors.ember500),
                  ]),
                  const Spacer(),
                  Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Flexible(child: Pill(label: l.status, color: AppColors.forStatus(l.status))),
                    const SizedBox(width: 6),
                    Text(relTime(l.createdAt), style: AppText.body(size: 11, color: AppColors.textTertiary)),
                  ]),
                ]),
              ),
            ).stagger(i, stepMs: 40);
          },
        ),
      ),
    ]);
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context) {
    final items = context.watch<NotificationsProvider>().activity.take(6).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Live activity', padding: EdgeInsets.fromLTRB(20, 16, 20, 10)),
      PremiumCard(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          children: items.asMap().entries.map((e) {
            final a = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: e.key == 0 ? AppColors.success : AppColors.border,
                    shape: BoxShape.circle,
                    boxShadow: e.key == 0 ? AppColors.glow(AppColors.success, 0.6) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(a.text, style: AppText.body(size: 13, color: AppColors.textSecondary))),
                const SizedBox(width: 8),
                Text(relTime(a.at), style: AppText.body(size: 11, color: AppColors.textTertiary)),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}
