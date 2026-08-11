import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/billing_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../services/razorpay_checkout.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late final RazorpayCheckout _checkout;
  String? _busyAddOnId;

  @override
  void initState() {
    super.initState();
    _checkout = RazorpayCheckout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillingProvider>().loadBillingData();
    });
  }

  @override
  void dispose() {
    _checkout.dispose();
    super.dispose();
  }

  Future<void> _buy(AddOn addOn) async {
    setState(() => _busyAddOnId = addOn.id);
    final outcome = await context
        .read<BillingProvider>()
        .purchaseAddOn(checkout: _checkout, addOn: addOn);
    if (!mounted) return;
    setState(() => _busyAddOnId = null);
    _snack(outcome.message, outcome.ok);
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingProvider>();
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    final org = billing.org;

    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Add-ons')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => billing.loadBillingData(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!isAdmin)
              _InfoBanner(
                icon: Icons.lock_outline_rounded,
                text:
                    'Billing is managed by your organization admin. You can view plan status here.',
              ),
            if (org == null && billing.loadingOrg)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _PlanCard(org: org)
                  .animate()
                  .slideY(begin: 0.08, duration: 280.ms)
                  .fadeIn(),
            const SizedBox(height: 16),

            // Usage: AI replies (from quota-status; includes purchased packs)
            if (billing.quota != null)
              _UsageCard(quota: billing.quota!, org: org)
                  .animate()
                  .fadeIn(delay: 80.ms),
            const SizedBox(height: 20),

            // Add-ons
            Row(
              children: [
                const Icon(Icons.extension_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Add-on packs',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Buy extra AI replies, seats, leads and more — added instantly to your account.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),

            if (billing.loadingQuota && billing.availableAddOns.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!(org?.hasPaid ?? false))
              _InfoBanner(
                icon: Icons.info_outline_rounded,
                text:
                    'Add-on packs unlock once you are on a paid plan. Activate a plan on the web app first.',
              )
            else if (!billing.razorpayEnabled)
              _InfoBanner(
                icon: Icons.info_outline_rounded,
                text: 'Payments are temporarily unavailable. Please try again later.',
              )
            else if (billing.availableAddOns.isEmpty)
              _InfoBanner(
                icon: Icons.check_circle_outline_rounded,
                text: 'No add-on packs are available for your current plan.',
              )
            else
              ...billing.availableAddOns.map((a) => _AddOnTile(
                    addOn: a,
                    busy: _busyAddOnId == a.id,
                    enabled: isAdmin && _busyAddOnId == null,
                    onBuy: () => _buy(a),
                  )),

            const SizedBox(height: 20),

            // Subscription is web-only
            _ManageSubscriptionCard(canManage: isAdmin),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final OrgBilling? org;
  const _PlanCard({this.org});

  @override
  Widget build(BuildContext context) {
    final o = org;
    final statusText = _statusLabel(o?.status ?? 'trialing');
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                o?.planName ?? 'Starter',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusText,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _subLine(o),
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Seats',
                  value: o == null
                      ? '—'
                      : (o.seatsUnlimited
                          ? '${o.seatsUsed} / ∞'
                          : '${o.seatsUsed} / ${o.seatsLimit}'),
                ),
              ),
              Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withOpacity(0.25)),
              Expanded(
                child: _MiniStat(
                  label: 'Leads',
                  value: o == null
                      ? '—'
                      : (o.leadsUnlimited
                          ? '${o.leadsUsed} / ∞'
                          : '${o.leadsUsed} / ${o.leadsLimit}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'Active';
      case 'past_due':
        return 'Past due';
      case 'expired':
        return 'Expired';
      default:
        return 'Trial';
    }
  }

  String _subLine(OrgBilling? o) {
    if (o == null) return 'Loading plan…';
    if (o.isTrialing) {
      return '${o.trialDaysLeft} days left in your free trial';
    }
    if (o.currentPeriodEndMs > 0) {
      final d = DateTime.fromMillisecondsSinceEpoch(o.currentPeriodEndMs);
      final date = '${d.day}/${d.month}/${d.year}';
      return o.autopay ? 'Auto-renews on $date' : 'Renews on $date';
    }
    return o.name;
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.white.withOpacity(0.7))),
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  final QuotaStatus quota;
  final OrgBilling? org;
  const _UsageCard({required this.quota, this.org});

  @override
  Widget build(BuildContext context) {
    final ai = quota.aiMessages;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('AI replies this month',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                ai.unlimited
                    ? 'Unlimited'
                    : '${ai.used} / ${ai.limit}',
                style: TextStyle(
                    fontSize: 12,
                    color: ai.exhausted
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ai.pct,
              minHeight: 7,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(
                  ai.exhausted ? AppColors.error : AppColors.primary),
            ),
          ),
          if (ai.exhausted) ...[
            const SizedBox(height: 8),
            Text(
              'You\'ve used all your AI replies. Buy an "Extra AI Replies" pack below to keep auto-replying.',
              style: TextStyle(fontSize: 11, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddOnTile extends StatelessWidget {
  final AddOn addOn;
  final bool busy;
  final bool enabled;
  final VoidCallback onBuy;

  const _AddOnTile({
    required this.addOn,
    required this.busy,
    required this.enabled,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final maxed = addOn.maxedOut;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_box_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(addOn.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    if (addOn.owned > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('×${addOn.owned}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.success,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  addOn.description.isNotEmpty ? addOn.description : addOn.unit,
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('₹${addOn.monthlyPrice}/mo',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: (enabled && !maxed) ? onBuy : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(maxed ? 'Max' : 'Buy',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageSubscriptionCard extends StatelessWidget {
  final bool canManage;
  const _ManageSubscriptionCard({required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.workspace_premium_rounded,
                  size: 18, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('Plans & subscription',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upgrade, downgrade or set up autopay for your subscription on the Codeskate web dashboard.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse('https://app.codeskate.com/admin/billing');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Manage subscription on web'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    );
