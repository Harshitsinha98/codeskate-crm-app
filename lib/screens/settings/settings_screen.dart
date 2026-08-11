import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            _ProfileCard(user: user)
                .animate()
                .slideY(begin: 0.1, duration: 300.ms)
                .fadeIn(),
            const SizedBox(height: 20),
            // Settings sections
            _SettingsSection(
              title: 'General',
              children: [
                _SettingsTile(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  subtitle: 'Push notification preferences',
                  onTap: () => context.go('/notifications'),
                ),
                _SettingsTile(
                  icon: Icons.group_rounded,
                  title: 'Team',
                  subtitle: '${settings.settings['teamSize'] ?? 'View'} members',
                  onTap: () => context.go('/chat'),
                ),
                _SettingsTile(
                  icon: Icons.tune_rounded,
                  title: 'Lead Statuses',
                  subtitle: settings.statuses.join(', '),
                  onTap: () {},
                ),
              ],
            ).animate().slideY(begin: 0.1, duration: 300.ms, delay: 100.ms).fadeIn(),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Billing & Purchases',
              children: [
                _SettingsTile(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Billing & Add-ons',
                  subtitle: (user?.isAdmin ?? false)
                      ? 'Plan status, buy AI packs, seats & more'
                      : 'View your plan status',
                  onTap: () => context.push('/billing'),
                ),
                _SettingsTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Voice Wallet',
                  subtitle: 'Balance & top-up for calling',
                  onTap: () => context.push('/wallet'),
                ),
              ],
            ).animate().slideY(begin: 0.1, duration: 300.ms, delay: 150.ms).fadeIn(),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.phone_rounded,
                  title: 'Phone Number',
                  subtitle: user?.phone ?? '',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.business_rounded,
                  title: 'Organization',
                  subtitle: user?.activeOrgName ?? '',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Role',
                  subtitle: user?.activeOrgRole ?? '',
                  onTap: () {},
                ),
              ],
            ).animate().slideY(begin: 0.1, duration: 300.ms, delay: 200.ms).fadeIn(),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Support',
              children: [
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get help with Codeskate CRM',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'Version 1.0.0',
                  onTap: () {},
                ),
              ],
            ).animate().slideY(begin: 0.1, duration: 300.ms, delay: 300.ms).fadeIn(),
            const SizedBox(height: 24),
            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context, auth),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out'),
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.signOut();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final dynamic user;
  const _ProfileCard({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.activeOrgName ?? 'Organization',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  user?.activeOrgRole ?? 'Member',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: children
                .map<List<Widget>>((child) => [
                      child,
                      if (child != children.last)
                        const Divider(height: 1, indent: 56),
                    ])
                .expand((e) => e)
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: AppColors.textTertiary.withOpacity(0.5),
      ),
    );
  }
}
