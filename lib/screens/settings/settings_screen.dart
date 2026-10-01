import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
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
                  onTap: (user?.isAdmin ?? false)
                      ? () => _showStatusEditor(context, settings)
                      : null,
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
                if (user?.isAdmin ?? false)
                  _SettingsTile(
                    icon: Icons.call_rounded,
                    title: 'Call History & Recordings',
                    subtitle: 'Bridge calls, durations & recordings',
                    onTap: () => context.push('/call-history'),
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
                ),
                _SettingsTile(
                  icon: Icons.business_rounded,
                  title: 'Organization',
                  subtitle: (user?.memberships.length ?? 0) > 1
                      ? '${user?.activeOrgName ?? ''} • tap to switch'
                      : user?.activeOrgName ?? '',
                  onTap: (user?.memberships.length ?? 0) > 1
                      ? () => _showOrgSwitcher(context, auth)
                      : null,
                ),
                _SettingsTile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Role',
                  subtitle: user?.activeOrgRole ?? '',
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
                  onTap: () => _showHelp(context),
                ),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'Version ${AppConstants.appVersion}',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: AppConstants.appVersion,
                    applicationLegalese: '© Codeskate',
                    children: const [
                      SizedBox(height: 12),
                      Text(AppConstants.appTagline),
                    ],
                  ),
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

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Help & Support',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: AppColors.whatsapp),
              title: const Text('Chat with us on WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _open(context, AppConstants.supportWhatsApp);
              },
            ),
            ListTile(
              leading: const Icon(Icons.email_rounded, color: AppColors.info),
              title: const Text('Email support'),
              subtitle: const Text(AppConstants.supportEmail),
              onTap: () {
                Navigator.pop(ctx);
                _open(context, 'mailto:${AppConstants.supportEmail}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser_rounded, color: AppColors.primary),
              title: const Text('Open web dashboard'),
              subtitle: const Text('Raise a support ticket & manage your workspace'),
              onTap: () {
                Navigator.pop(ctx);
                _open(context, AppConstants.webAppUrl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showOrgSwitcher(BuildContext context, AuthProvider auth) {
    final user = auth.user;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Switch organization',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ...user.memberships.map((m) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('organizations').doc(m.orgId).get(),
                  builder: (_, snap) {
                    final name = snap.data?.data()?['name']?.toString() ?? m.orgId;
                    final active = m.orgId == user.activeOrgId;
                    return ListTile(
                      leading: Icon(
                        active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: active ? AppColors.primary : AppColors.textTertiary,
                      ),
                      title: Text(name),
                      subtitle: Text(m.role),
                      onTap: active
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final ok = await auth.switchOrg(m.orgId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(ok ? 'Switched to $name' : 'Could not switch organization'),
                                ));
                              }
                            },
                    );
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showStatusEditor(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (_) => _StatusEditorDialog(
        initial: settings.statuses,
        onSave: (list) => settings.updateSettings({'statuses': list}),
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
      trailing: onTap == null ? null : Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: AppColors.textTertiary.withOpacity(0.5),
      ),
    );
  }
}

/// Admin editor for the org's lead pipeline statuses (settings/config).
/// Closed-Won and Lost are required by the backend follow-up workflow, so
/// they can be reordered but not removed.
class _StatusEditorDialog extends StatefulWidget {
  final List<String> initial;
  final Future<void> Function(List<String>) onSave;

  const _StatusEditorDialog({required this.initial, required this.onSave});

  @override
  State<_StatusEditorDialog> createState() => _StatusEditorDialogState();
}

class _StatusEditorDialogState extends State<_StatusEditorDialog> {
  static const _locked = {'Closed-Won', 'Lost'};
  late List<String> _statuses;
  final _input = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statuses = [...widget.initial];
    for (final s in _locked) {
      if (!_statuses.contains(s)) _statuses.add(s);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final v = _input.text.trim();
    if (v.isEmpty) return;
    if (v.length > 80) {
      setState(() => _error = 'Keep status names under 80 characters');
      return;
    }
    if (_statuses.any((s) => s.toLowerCase() == v.toLowerCase())) {
      setState(() => _error = 'That status already exists');
      return;
    }
    setState(() {
      _error = null;
      // Insert new statuses before the terminal ones.
      final idx = _statuses.indexWhere(_locked.contains);
      _statuses.insert(idx < 0 ? _statuses.length : idx, v);
      _input.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_statuses);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Only admins can change statuses.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lead statuses'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            Expanded(
              child: ReorderableListView(
                shrinkWrap: true,
                buildDefaultDragHandles: true,
                onReorder: (from, to) => setState(() {
                  if (to > from) to -= 1;
                  final item = _statuses.removeAt(from);
                  _statuses.insert(to, item);
                }),
                children: [
                  for (final s in _statuses)
                    ListTile(
                      key: ValueKey(s),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s),
                      trailing: _locked.contains(s)
                          ? const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textTertiary)
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() => _statuses.remove(s)),
                            ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(hintText: 'New status', isDense: true),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                IconButton(onPressed: _add, icon: const Icon(Icons.add_rounded)),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
