import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

Color broadcastStatusColor(String s) => switch (s) {
      'completed' => AppColors.success,
      'completed_with_errors' => AppColors.warning,
      'failed' || 'cancelled' => AppColors.error,
      'scheduled' => AppColors.info,
      _ => AppColors.primary,
    };

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;

  String get _orgId => context.read<AuthProvider>().user!.activeOrgId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _list.isEmpty;
      _error = null;
    });
    try {
      final r = await Future.wait([BroadcastApi.analytics(_orgId), BroadcastApi.list(_orgId)]);
      if (!mounted) return;
      setState(() {
        _analytics = r[0] as Map<String, dynamic>;
        _list = r[1] as List<Map<String, dynamic>>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> b) async {
    final ok = await confirmAction(context, title: 'Cancel broadcast?', message: 'Pending messages in "${b['name']}" will not be sent.', confirmLabel: 'Cancel broadcast', destructive: true);
    if (!ok || !mounted) return;
    try {
      await BroadcastApi.cancel(_orgId, b['id'].toString());
      if (mounted) AppToast.success(context, 'Broadcast cancelled');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = Map<String, dynamic>.from(_analytics?['totals'] ?? {});
    final rates = Map<String, dynamic>.from(_analytics?['rates'] ?? {});
    final series = (_analytics?['timeSeries'] as List?)?.whereType<Map>().toList() ?? [];

    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Broadcasts',
        subtitle: 'WhatsApp template campaigns',
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/broadcasts/new');
          if (created == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New campaign'),
      ),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load broadcasts', message: _error, action: GlowButton(label: 'Retry', expand: false, onPressed: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.45,
                        children: [
                          KpiTile(label: 'Messages sent', value: (totals['sent'] as num?) ?? 0, icon: Icons.send_rounded),
                          KpiTile(label: 'Delivery rate', value: (rates['deliveryRate'] as num?) ?? 0, suffix: '%', icon: Icons.done_all_rounded, color: AppColors.success),
                          KpiTile(label: 'Read rate', value: (rates['readRate'] as num?) ?? 0, suffix: '%', icon: Icons.visibility_rounded, color: AppColors.info),
                          KpiTile(label: 'Reply rate', value: (rates['responseRate'] as num?) ?? 0, suffix: '%', icon: Icons.reply_all_rounded, color: AppColors.signal),
                        ].asMap().entries.map((e) => e.value.stagger(e.key)).toList(),
                      ),
                      if (series.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        TitledCard(
                          title: 'Last 30 days',
                          margin: EdgeInsets.zero,
                          child: SizedBox(
                            height: 140,
                            child: BarChart(BarChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              barTouchData: BarTouchData(enabled: false),
                              barGroups: [
                                for (var i = 0; i < series.length; i++)
                                  BarChartGroupData(x: i, barRods: [
                                    BarChartRodData(
                                      toY: ((series[i]['sent'] as num?) ?? 0).toDouble(),
                                      width: 6,
                                      borderRadius: BorderRadius.circular(3),
                                      gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.orange300, AppColors.orange600]),
                                    ),
                                  ]),
                              ],
                            )),
                          ),
                        ).stagger(4),
                      ],
                      const SectionTitle('Campaigns', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
                      if (_list.isEmpty)
                        const PremiumEmpty(icon: Icons.campaign_rounded, title: 'No campaigns yet', message: 'Send an approved template to a filtered audience in a few taps.'),
                      ..._list.asMap().entries.map((e) {
                        final b = e.value;
                        final status = (b['status'] ?? '').toString();
                        final total = (b['totalRecipients'] as num?)?.toInt() ?? 0;
                        final sent = (b['sent'] as num?)?.toInt() ?? 0;
                        final scheduledMs = (b['scheduledAtMs'] as num?)?.toInt();
                        final createdMs = (b['createdAtMs'] as num?)?.toInt();
                        final when = status == 'scheduled' && scheduledMs != null
                            ? 'Scheduled · ${DateTime.fromMillisecondsSinceEpoch(scheduledMs).toLocal().toString().substring(0, 16)}'
                            : createdMs != null
                                ? '${relTime(DateTime.fromMillisecondsSinceEpoch(createdMs))} ago'
                                : '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: PremiumCard(
                            onTap: () => context.push('/broadcasts/${b['id']}'),
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                IconBubble(icon: Icons.campaign_rounded, color: broadcastStatusColor(status), size: 38),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text((b['name'] ?? 'Broadcast').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary)),
                                    Text('${b['templateName'] ?? ''} · $when', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
                                  ]),
                                ),
                                Pill(label: status.replaceAll('_', ' '), color: broadcastStatusColor(status)),
                              ]),
                              const SizedBox(height: 10),
                              MetricBar(label: '$total recipients', value: sent, max: total == 0 ? 1 : total, trailing: '$sent sent', color: broadcastStatusColor(status)),
                              if (['scheduled', 'queued', 'processing'].contains(status))
                                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _cancel(b), child: const Text('Cancel', style: TextStyle(color: AppColors.error)))),
                            ]),
                          ),
                        ).stagger(e.key + 5);
                      }),
                    ],
                  ),
                ),
    );
  }
}
