import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';
import 'broadcast_screen.dart';

class BroadcastDetailScreen extends StatefulWidget {
  final String broadcastId;
  const BroadcastDetailScreen({super.key, required this.broadcastId});

  @override
  State<BroadcastDetailScreen> createState() => _BroadcastDetailScreenState();
}

class _BroadcastDetailScreenState extends State<BroadcastDetailScreen> {
  Map<String, dynamic>? _b;
  List<Map<String, dynamic>> _recipients = [];
  Map<String, dynamic> _failures = {};
  String? _filter;
  String _q = '';
  bool _loading = true;
  String? _error;
  Timer? _poll;

  String get _orgId => context.read<AuthProvider>().user!.activeOrgId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([BroadcastApi.status(widget.broadcastId), BroadcastApi.recipients(widget.broadcastId, status: _filter)]);
      if (!mounted) return;
      final rec = r[1];
      setState(() {
        _b = r[0];
        _recipients = ((rec['recipients'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _failures = Map<String, dynamic>.from(rec['failureBreakdown'] ?? {});
        _error = null;
      });
      _poll?.cancel();
      if (['processing', 'queued'].contains(_b?['status'])) {
        _poll = Timer(const Duration(seconds: 5), _load);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry() async {
    try {
      final r = await BroadcastApi.retry(_orgId, widget.broadcastId);
      if (mounted) AppToast.success(context, 'Retrying ${r['retrying']} failed messages');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmAction(context, title: 'Cancel broadcast?', message: 'Remaining messages will not be sent.', destructive: true, confirmLabel: 'Cancel broadcast');
    if (!ok) return;
    try {
      await BroadcastApi.cancel(_orgId, widget.broadcastId);
      if (mounted) AppToast.success(context, 'Broadcast cancelled');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    final status = (b?['status'] ?? '').toString();
    final rates = Map<String, dynamic>.from(b?['rates'] ?? {});
    num n(String k) => (b?[k] as num?) ?? 0;
    final list = _recipients.where((r) {
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return '${r['name']}'.toLowerCase().contains(q) || '${r['phone']}'.contains(q);
    }).toList();

    return Scaffold(
      appBar: PremiumAppBar(
        title: (b?['name'] ?? 'Broadcast').toString(),
        subtitle: b == null ? null : '${b['templateName']} · ${status.replaceAll('_', ' ')}',
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? PremiumEmpty(icon: Icons.error_outline_rounded, title: 'Could not load', message: _error)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
                    PremiumCard(
                      gradient: const LinearGradient(colors: [AppColors.midnight900, AppColors.midnight700]),
                      child: Column(children: [
                        Row(children: [
                          Pill(label: status.replaceAll('_', ' '), color: broadcastStatusColor(status), solid: true),
                          const Spacer(),
                          if (b?['estimatedCostInr'] != null) Text('Est. ${inr((b!['estimatedCostInr'] as num))}', style: AppText.mono(size: 12.5, color: AppColors.orange300)),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          _Funnel(label: 'Recipients', value: n('totalRecipients')),
                          _Funnel(label: 'Sent', value: n('sent')),
                          _Funnel(label: 'Delivered', value: n('delivered')),
                          _Funnel(label: 'Read', value: n('read')),
                          _Funnel(label: 'Replied', value: n('replied')),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: KpiTile(label: 'Delivery', value: (rates['deliveryRate'] as num?) ?? 0, suffix: '%', icon: Icons.done_all_rounded, color: AppColors.success)),
                      const SizedBox(width: 10),
                      Expanded(child: KpiTile(label: 'Read', value: (rates['readRate'] as num?) ?? 0, suffix: '%', icon: Icons.visibility_rounded, color: AppColors.info)),
                      const SizedBox(width: 10),
                      Expanded(child: KpiTile(label: 'Failed', value: n('failed'), icon: Icons.error_outline_rounded, color: AppColors.error)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      if (['processing', 'queued', 'scheduled'].contains(status))
                        Expanded(child: GlowButton(label: 'Cancel', icon: Icons.stop_circle_rounded, variant: GlowVariant.ghost, onPressed: _cancel)),
                      if (n('failed') > 0 && ['completed', 'completed_with_errors', 'failed'].contains(status))
                        Expanded(child: GlowButton(label: 'Retry ${n('failed')} failed', icon: Icons.replay_rounded, onPressed: _retry)),
                    ]),
                    if (_failures.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TitledCard(
                        title: 'Why messages failed',
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: _failures.entries
                              .map((e) => MetricBar(label: e.key, value: e.value as num, max: n('failed') == 0 ? 1 : n('failed'), color: AppColors.error))
                              .toList(),
                        ),
                      ),
                    ],
                    const SectionTitle('Recipients', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
                    SearchField(hint: 'Search name or phone', onChanged: (v) => setState(() => _q = v)),
                    const SizedBox(height: 10),
                    SegmentTabs<String?>(
                      values: const [null, 'sent', 'delivered', 'read', 'failed', 'pending'],
                      selected: _filter,
                      label: (s) => s == null ? 'All' : s[0].toUpperCase() + s.substring(1),
                      onChanged: (s) {
                        setState(() => _filter = s);
                        _load();
                      },
                    ),
                    const SizedBox(height: 10),
                    ...list.map((r) {
                      final st = (r['status'] ?? '').toString();
                      final c = st == 'failed' ? AppColors.error : (st == 'read' ? AppColors.info : (st == 'pending' ? AppColors.textTertiary : AppColors.success));
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PremiumCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            GradientAvatar(name: '${r['name'] ?? '?'}', size: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${r['name'] ?? r['phone']}', style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.textPrimary)),
                                Text(st == 'failed' && r['error'] != null ? '${r['error']}' : '${r['phone'] ?? ''}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11.5, color: st == 'failed' ? AppColors.error : AppColors.textTertiary)),
                              ]),
                            ),
                            if (r['replied'] == true) const Padding(padding: EdgeInsets.only(right: 6), child: Pill(label: 'Replied', color: AppColors.signal)),
                            Pill(label: st, color: c),
                          ]),
                        ),
                      );
                    }),
                  ]),
                ),
    );
  }
}

class _Funnel extends StatelessWidget {
  final String label;
  final num value;
  const _Funnel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          AnimatedCount(value: value, style: AppText.display(size: 18, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 10, color: AppColors.textOnDarkMuted)),
        ]),
      );
}
