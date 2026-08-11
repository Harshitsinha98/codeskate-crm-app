import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/billing_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../services/razorpay_checkout.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const List<int> _presets = [500, 1000, 2000, 5000];
  static const int _minTopUp = 100;

  late final RazorpayCheckout _checkout;
  int _amount = 1000;
  bool _busy = false;
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkout = RazorpayCheckout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final b = context.read<BillingProvider>();
      if (b.config.razorpayKeyId == null) b.loadBillingData();
      b.refreshWallet();
    });
  }

  @override
  void dispose() {
    _checkout.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    final amt = _amount;
    if (amt < _minTopUp) {
      _snack('Minimum top-up is ₹$_minTopUp.', false);
      return;
    }
    setState(() => _busy = true);
    final outcome =
        await context.read<BillingProvider>().topUpWallet(checkout: _checkout, amountInr: amt);
    if (!mounted) return;
    setState(() => _busy = false);
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
    final locked = !billing.walletUnlocked;
    final money = NumberFormat.decimalPattern('en_IN');

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Wallet')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => billing.refreshWallet(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (locked)
              _LockBanner()
                  .animate()
                  .fadeIn(),

            // Balance hero
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.account_balance_wallet_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Wallet Balance',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ]),
                        const SizedBox(height: 10),
                        billing.loadingWallet
                            ? const SizedBox(
                                height: 34,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white)),
                                ),
                              )
                            : Text(
                                '₹${money.format(billing.wallet.balanceInr.round())}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700),
                              ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Spent (lifetime)',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${money.format(billing.wallet.totalSpentInr.round())}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.08, duration: 280.ms).fadeIn(),

            const SizedBox(height: 20),

            // Top-up section (admins only, unlocked plans only)
            if (!locked && isAdmin) ...[
              Text('Add money',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map((p) {
                  final selected = _amount == p;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _amount = p);
                      _customCtrl.clear();
                      FocusScope.of(context).unfocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.divider),
                      ),
                      child: Text('₹$p',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Custom amount (₹)',
                  hintText: 'Min ₹$_minTopUp',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null && n > 0) setState(() => _amount = n);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _topUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded, size: 20),
                  label: Text(_busy ? 'Processing…' : 'Add ₹$_amount to wallet',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Bridge calls ₹2.20/min · AI voice ₹5/min',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ),
            ] else if (!locked && !isAdmin)
              _InfoBanner(
                icon: Icons.lock_outline_rounded,
                text:
                    'Only an organization admin can top up the Voice Wallet.',
              ),

            const SizedBox(height: 24),

            // Transactions
            Text('Recent transactions',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (billing.transactions.isEmpty)
              _InfoBanner(
                icon: Icons.receipt_long_rounded,
                text: 'No wallet transactions yet.',
              )
            else
              ...billing.transactions
                  .take(30)
                  .map((t) => _TxnTile(txn: t, money: money)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final WalletTransaction txn;
  final NumberFormat money;
  const _TxnTile({required this.txn, required this.money});

  @override
  Widget build(BuildContext context) {
    final credit = txn.isCredit;
    final dateStr = txn.createdAt == null
        ? ''
        : DateFormat('dd MMM, hh:mm a').format(txn.createdAt!);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (credit ? AppColors.success : AppColors.error)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              credit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 18,
              color: credit ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description.isNotEmpty
                      ? txn.description
                      : (credit ? 'Wallet top-up' : 'Usage'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : '-'}₹${money.format(txn.amountInr.abs().round())}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: credit ? AppColors.success : AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _LockBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Voice Wallet is a Growth+ feature',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(
                  'Upgrade to Growth or above (on the web app) to top up and use bridge/AI calling.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
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
