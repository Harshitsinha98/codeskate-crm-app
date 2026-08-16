import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/notifications_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/lead_mini_card.dart';
import '../widgets/ui_kit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return 'U';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final leads = context.watch<LeadsProvider>();
    final notifs = context.watch<NotificationsProvider>();
    final user = auth.user;

    final total = leads.totalLeads;
    final won = leads.closedWon;
    final conversion = total > 0 ? won / total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Clean top bar (no heavy gradient banner) ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(user?.displayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            user?.displayName?.split(' ').first ?? 'there',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _IconBtn(
                      icon: Icons.notifications_none_rounded,
                      showDot: notifs.hasUnread,
                      onTap: () => context.go('/notifications'),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),

          // ── Hero: pipeline snapshot ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: AppCard(
                onTap: () => context.go('/leads'),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const StatLabel('Active pipeline'),
                        const Spacer(),
                        StatusPill(
                          label: user?.activeOrgName ?? 'Workspace',
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 38,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 5),
                          child: Text(
                            'leads',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${(conversion * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const StatLabel('Conversion'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MiniProgress(value: conversion, color: AppColors.success),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _HeroChip(
                          color: AppColors.statusNew,
                          label: '${leads.newLeads} new',
                        ),
                        const SizedBox(width: 8),
                        _HeroChip(
                          color: AppColors.success,
                          label: '$won won',
                        ),
                        const SizedBox(width: 8),
                        _HeroChip(
                          color: AppColors.warning,
                          label: '${leads.activeFollowUps} follow-ups',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().slideY(begin: 0.08, duration: 350.ms).fadeIn(delay: 80.ms),
          ),

          // ── KPI grid ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Overview'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: [
                      StatCard(
                        title: 'Total leads',
                        value: '$total',
                        icon: Icons.people_alt_rounded,
                        color: AppColors.info,
                        onTap: () => context.go('/leads'),
                      ),
                      StatCard(
                        title: 'New leads',
                        value: '${leads.newLeads}',
                        icon: Icons.auto_awesome_rounded,
                        color: AppColors.statusNew,
                        onTap: () => context.go('/leads'),
                      ),
                      StatCard(
                        title: 'Closed won',
                        value: '$won',
                        icon: Icons.verified_rounded,
                        color: AppColors.success,
                        onTap: () => context.go('/leads'),
                      ),
                      StatCard(
                        title: 'Follow-ups',
                        value: '${leads.activeFollowUps}',
                        icon: Icons.event_note_rounded,
                        color: AppColors.warning,
                        subtitle: leads.overdueFollowUps > 0
                            ? '${leads.overdueFollowUps} overdue'
                            : null,
                        onTap: () => context.go('/followups'),
                      ),
                    ]
                        .animate(interval: 70.ms)
                        .slideY(begin: 0.12, duration: 300.ms)
                        .fadeIn(),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick actions ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SectionHeader(title: 'Shortcuts'),
                  ),
                  SizedBox(
                    height: 92,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        QuickActionCard(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          color: AppColors.whatsapp,
                          onTap: () => context.go('/whatsapp'),
                        ),
                        QuickActionCard(
                          icon: Icons.groups_rounded,
                          label: 'Team chat',
                          color: AppColors.secondary,
                          onTap: () => context.go('/chat'),
                        ),
                        QuickActionCard(
                          icon: Icons.notifications_active_rounded,
                          label: 'Alerts',
                          color: AppColors.warning,
                          onTap: () => context.go('/notifications'),
                        ),
                        QuickActionCard(
                          icon: Icons.phone_callback_rounded,
                          label: 'Due today',
                          color: AppColors.error,
                          onTap: () => context.go('/followups'),
                        ),
                      ]
                          .animate(interval: 60.ms)
                          .slideX(begin: 0.2, duration: 300.ms)
                          .fadeIn(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Recent leads ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Recent leads',
                actionLabel: 'See all',
                onAction: () => context.go('/leads'),
              ),
            ),
          ),

          if (leads.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            )
          else if (leads.leads.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.inbox_rounded,
                title: 'No leads yet',
                hint: 'New leads will show up here automatically.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final lead = leads.leads[index];
                    return LeadMiniCard(
                      lead: lead,
                      onTap: () => context.push('/lead/${lead.id}'),
                    )
                        .animate()
                        .slideY(begin: 0.08, duration: 260.ms)
                        .fadeIn(delay: Duration(milliseconds: 40 * index));
                  },
                  childCount: leads.leads.take(5).length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

/// Neutral icon button used in the top bar.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool showDot;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            if (showDot)
              Positioned(
                right: 9,
                top: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tiny dot+label chip used in the hero card footer.
class _HeroChip extends StatelessWidget {
  final Color color;
  final String label;

  const _HeroChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
