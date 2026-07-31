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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final leads = context.watch<LeadsProvider>();
    final notifs = context.watch<NotificationsProvider>();
    final user = auth.user;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, ${user?.displayName?.split(' ').first ?? 'there'}! 👋',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.activeOrgName ?? 'Codeskate CRM',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/notifications'),
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                if (notifs.hasUnread)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().slideY(begin: -0.1, duration: 400.ms).fadeIn(),
          ),

          // Stats Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      StatCard(
                        title: 'Total Leads',
                        value: '${leads.totalLeads}',
                        icon: Icons.people_alt_rounded,
                        color: AppColors.info,
                        onTap: () => context.go('/leads'),
                      ),
                      StatCard(
                        title: 'New Leads',
                        value: '${leads.newLeads}',
                        icon: Icons.fiber_new_rounded,
                        color: AppColors.statusNew,
                        onTap: () => context.go('/leads'),
                      ),
                      StatCard(
                        title: 'Closed Won',
                        value: '${leads.closedWon}',
                        icon: Icons.celebration_rounded,
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
                    ].animate(interval: 100.ms).slideY(begin: 0.2, duration: 350.ms).fadeIn(),
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
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
                          icon: Icons.group_rounded,
                          label: 'Team Chat',
                          color: AppColors.info,
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
                          label: 'Due Today',
                          color: AppColors.error,
                          onTap: () => context.go('/followups'),
                        ),
                      ].animate(interval: 80.ms).slideX(begin: 0.3, duration: 350.ms).fadeIn(delay: 500.ms),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recent Leads
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Leads',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => context.go('/leads'),
                    child: const Text('View All'),
                  ),
                ],
              ).animate().fadeIn(delay: 600.ms),
            ),
          ),

          // Leads list
          if (leads.isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            )
          else if (leads.leads.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded, size: 64, color: AppColors.textTertiary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No leads yet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final lead = leads.leads[index];
                    return LeadMiniCard(
                      lead: lead,
                      onTap: () => context.push('/lead/${lead.id}'),
                    ).animate().slideX(begin: 0.1, duration: 300.ms, delay: Duration(milliseconds: 100 * index)).fadeIn();
                  },
                  childCount: leads.leads.take(5).length,
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
