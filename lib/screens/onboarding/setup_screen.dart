import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/premium.dart';

/// Shown to signed-in users without any workspace: create a free-trial
/// workspace (POST /api/billing/trial/provision) — same as web /setup.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _org = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _org.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 2 || _org.text.trim().length < 2) {
      setState(() => _error = 'Enter your name and your business name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await OnboardingApi.provisionTrial(orgName: _org.text.trim(), fullName: _name.text.trim());
      if (!mounted) return;
      AppToast.success(context, 'Workspace ready — ${r['trialDays'] ?? 14}-day free trial started 🎉');
      await context.read<AuthProvider>().reloadProfile();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    InputDecoration deco(String hint, IconData icon) => InputDecoration(
          hintText: hint,
          hintStyle: AppText.body(size: 15, color: Colors.white38),
          prefixIcon: Icon(icon, color: AppColors.orange300, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.orange400, width: 1.5)),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnight900,
        body: AuroraBackground(
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.all(26), children: [
              Row(children: [
                const BrandMark(size: 42),
                const Spacer(),
                TextButton(
                  onPressed: () => auth.signOut(),
                  child: Text('Use another number', style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.orange300)),
                ),
              ]),
              const SizedBox(height: 46),
              Text('Let\'s set up\nyour workspace', style: AppText.display(size: 34, color: Colors.white, letterSpacing: -1.2))
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.2),
              const SizedBox(height: 12),
              Text(
                'No workspace is linked to ${auth.user?.phone ?? 'this number'} yet. Start a free trial — or ask your admin to invite this number.',
                style: AppText.body(size: 14.5, color: AppColors.textOnDarkMuted, height: 1.5),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 30),
              TextField(controller: _name, style: AppText.body(size: 15, color: Colors.white), textCapitalization: TextCapitalization.words, decoration: deco('Your full name', Icons.person_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _org, style: AppText.body(size: 15, color: Colors.white), textCapitalization: TextCapitalization.words, decoration: deco('Business name', Icons.storefront_rounded)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppText.body(size: 13, color: const Color(0xFFFCA5A5))),
              ],
              const SizedBox(height: 22),
              GlowButton(label: 'Start free trial', icon: Icons.rocket_launch_rounded, loading: _busy, onPressed: _create),
              const SizedBox(height: 14),
              Center(
                child: TextButton.icon(
                  onPressed: _busy ? null : () => auth.reloadProfile(),
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.orange300, size: 18),
                  label: Text('I was invited — check again', style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.orange300)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
