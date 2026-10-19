import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/premium.dart';

/// Codeskate Voice — business number status (provisioning & KYC on web).
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  Map<String, dynamic>? _s;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await VoiceApi.status(context.read<AuthProvider>().user!.activeOrgId!);
      if (mounted) setState(() => _s = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    final numbers = ((_s?['numbers'] as List?) ?? []).whereType<Map>().toList();
    final active = _s?['activeNumber'];
    return Scaffold(
      appBar: const PremiumAppBar(title: 'Codeskate Voice', subtitle: 'Business calling numbers'),
      body: _error != null
          ? PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load voice status', message: _error)
          : _s == null
              ? const SkeletonList(count: 3)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    PremiumCard(
                      gradient: const LinearGradient(colors: [AppColors.midnight900, AppColors.midnight700]),
                      child: Row(children: [
                        const IconBubble(icon: Icons.dialer_sip_rounded, color: AppColors.orange400, gradient: true, size: 48),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_s!['hasNumber'] == true ? 'Your business number' : 'No business number yet', style: AppText.body(size: 12.5, color: AppColors.textOnDarkMuted)),
                            Text(
                              active is Map ? '${active['number'] ?? active['phoneNumber'] ?? ''}' : (active?.toString() ?? 'Bridge calls use your mobile'),
                              style: AppText.display(size: 20, color: Colors.white),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    ...numbers.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PremiumCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              const IconBubble(icon: Icons.sim_card_rounded, color: AppColors.info),
                              const SizedBox(width: 12),
                              Expanded(child: Text('${n['number'] ?? n['phoneNumber'] ?? n['id']}', style: AppText.mono(size: 14))),
                              Pill(label: '${n['status'] ?? n['complianceStatus'] ?? 'pending'}', color: '${n['status']}' == 'active' ? AppColors.success : AppColors.warning),
                            ]),
                          ),
                        )),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: KpiTileButton(icon: Icons.history_rounded, label: 'Call history', onTap: isAdmin ? () => context.push('/call-history') : null)),
                      const SizedBox(width: 10),
                      Expanded(child: KpiTileButton(icon: Icons.account_balance_wallet_rounded, label: 'Voice wallet', onTap: () => context.push('/wallet'))),
                    ]),
                    const SizedBox(height: 14),
                    PremiumCard(
                      color: AppColors.cream200,
                      child: Row(children: [
                        const IconBubble(icon: Icons.auto_awesome_rounded, color: AppColors.signal),
                        const SizedBox(width: 12),
                        Expanded(child: Text('AI voice calls are coming soon. Buying a number and KYC upload happen on the web dashboard.', style: AppText.body(size: 12.8, color: AppColors.textSecondary))),
                      ]),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 14),
                      GlowButton(
                        label: _s!['hasNumber'] == true ? 'Manage numbers on web' : 'Get a business number',
                        icon: Icons.open_in_new_rounded,
                        variant: GlowVariant.dark,
                        onPressed: () => launchUrl(Uri.parse('${AppConstants.webAppUrl}/admin/voice'), mode: LaunchMode.externalApplication),
                      ),
                    ],
                  ]),
                ),
    );
  }
}

class KpiTileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const KpiTileButton({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => PremiumCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Row(children: [
            IconBubble(icon: icon, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.textPrimary))),
          ]),
        ),
      );
}
