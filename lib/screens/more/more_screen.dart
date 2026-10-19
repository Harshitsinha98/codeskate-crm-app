import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

/// Feature hub — every web CRM module, grouped like the web sidebar.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;
    final org = context.watch<BillingProvider>().org;

    final groups = <(String, List<_Item>)>[
      (
        'Sales',
        [
          if (isAdmin) const _Item('/team', 'Team', 'Invite, roles, goals', Icons.groups_2_rounded, AppColors.primary),
          if (isAdmin) const _Item('/meta-ads', 'Meta Ads', 'Click-to-WhatsApp & Lead Ads ROI', Icons.ads_click_rounded, AppColors.meta),
          if (isAdmin) const _Item('/broadcasts', 'Broadcasts', 'WhatsApp template campaigns', Icons.campaign_rounded, AppColors.signal),
          const _Item('/chat', 'Team chat', 'General channel & DMs', Icons.forum_outlined, AppColors.info),
          const _Item('/tickets', 'Internal tickets', 'Raise & track team issues', Icons.confirmation_number_rounded, AppColors.ember500),
          if (isAdmin) const _Item('/call-history', 'Calls & recordings', 'Bridge call history', Icons.graphic_eq_rounded, AppColors.success),
        ]
      ),
      if (isAdmin)
        (
          'Automation & AI',
          const [
            _Item('/ai-care', 'AI customer care', 'WhatsApp AI agent, knowledge base', Icons.auto_awesome_rounded, AppColors.orange600),
            _Item('/workflows', 'Workflows', 'If-this-then-that automation', Icons.account_tree_rounded, AppColors.ember500),
            _Item('/automation', 'Follow-up automation', 'Reminders & escalations', Icons.alarm_on_rounded, AppColors.statusMeetingFixed),
            _Item('/products', 'Product catalogue', 'Products the AI can recommend', Icons.inventory_2_rounded, AppColors.signal),
          ]
        ),
      if (isAdmin)
        (
          'Channels',
          const [
            _Item('/integrations', 'Integrations', 'WhatsApp, website forms, Google & Meta', Icons.hub_rounded, AppColors.whatsappDark),
            _Item('/voice', 'Codeskate Voice', 'Business numbers & AI calls', Icons.dialer_sip_rounded, AppColors.info),
          ]
        ),
      (
        'Account',
        [
          const _Item('/billing', 'Plan & billing', 'Subscription, add-ons', Icons.workspace_premium_rounded, AppColors.orange600),
          const _Item('/wallet', 'Voice wallet', 'Calling balance', Icons.account_balance_wallet_rounded, AppColors.ember500),
          const _Item('/notifications', 'Notifications', 'Alerts & reminders', Icons.notifications_rounded, AppColors.info),
          const _Item('/support', 'Help & support', 'AI assistant · raise a ticket', Icons.support_agent_rounded, AppColors.success),
          const _Item('/settings', 'Settings', 'Pipeline, profile, app', Icons.settings_rounded, AppColors.midnight500),
        ]
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AuroraBackground(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Row(children: [
                    GradientAvatar(name: user?.name ?? 'U', size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user?.name ?? '', style: AppText.display(size: 21, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(user?.phone ?? '', style: AppText.mono(size: 12.5, color: AppColors.textOnDarkMuted)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          Pill(label: (user?.activeOrgRole ?? 'member').toUpperCase(), color: AppColors.orange300),
                          if (org != null) Pill(label: org.planName, color: AppColors.textOnDark, icon: Icons.workspace_premium_rounded),
                        ]),
                      ]),
                    ),
                    if ((user?.memberships.length ?? 0) > 1)
                      Pressable(
                        onTap: () => showOrgSwitcher(context),
                        child: const GlassPanel(padding: EdgeInsets.all(10), radius: 14, child: Icon(Icons.swap_horiz_rounded, color: Colors.white)),
                      ),
                  ]),
                ),
              ),
            ),
          ),
          for (final (title, items) in groups)
            if (items.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(title)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _HubCard(item: items[i]).stagger(i, stepMs: 35),
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
              child: GlowButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                variant: GlowVariant.ghost,
                onPressed: () async {
                  final ok = await confirmAction(context, title: 'Sign out?', message: 'You will stop receiving lead alerts on this device.', confirmLabel: 'Sign out', destructive: true);
                  if (ok && context.mounted) await context.read<AuthProvider>().signOut();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final String route;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Item(this.route, this.title, this.subtitle, this.icon, this.color);
}

class _HubCard extends StatelessWidget {
  final _Item item;
  const _HubCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () => context.push(item.route),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBubble(icon: item.icon, color: item.color, size: 38, gradient: true),
        const Spacer(),
        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11.5, color: AppColors.textTertiary, height: 1.25)),
      ]),
    );
  }
}
