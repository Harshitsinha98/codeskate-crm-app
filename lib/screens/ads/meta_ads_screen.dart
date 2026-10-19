import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../providers/leads_provider.dart';
import '../leads/leads_screen.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

/// Meta ads ROI: Click-to-WhatsApp + Lead Ads attribution computed from
/// the `adReferral` / `source` / `campaign` captured on every lead.
class MetaAdsScreen extends StatefulWidget {
  const MetaAdsScreen({super.key});

  @override
  State<MetaAdsScreen> createState() => _MetaAdsScreenState();
}

class _MetaAdsScreenState extends State<MetaAdsScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<LeadsProvider>().leads;
    final since = DateTime.now().subtract(Duration(days: _days));
    final meta = all.where((l) => l.isFromMetaAd && (l.createdAt == null || l.createdAt!.isAfter(since))).toList();
    final ctwa = meta.where((l) => l.isCtwa).length;
    final won = meta.where((l) => l.isWon).length;
    final closed = meta.where((l) => l.isClosed).length;
    final conv = closed == 0 ? 0.0 : won * 100 / closed;
    final share = all.isEmpty ? 0.0 : meta.length * 100 / all.where((l) => l.createdAt == null || l.createdAt!.isAfter(since)).length.clamp(1, 1 << 30);

    final byAd = <String, List<LeadModel>>{};
    for (final l in meta) {
      byAd.putIfAbsent(l.adLabel, () => []).add(l);
    }
    final ads = byAd.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));

    final days = List.generate(math.min(_days, 30), (i) {
      final d = DateTime.now().subtract(Duration(days: math.min(_days, 30) - 1 - i));
      return DateTime(d.year, d.month, d.day);
    });
    final perDay = days
        .map((d) => meta.where((l) => l.createdAt != null && l.createdAt!.year == d.year && l.createdAt!.month == d.month && l.createdAt!.day == d.day).length.toDouble())
        .toList();

    return Scaffold(
      appBar: const PremiumAppBar(title: 'Meta ads', subtitle: 'Click-to-WhatsApp & Lead Ads performance'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), physics: const BouncingScrollPhysics(), children: [
        SegmentTabs<int>(values: const [7, 30, 90, 365], selected: _days, label: (d) => d == 365 ? '1 year' : '$d days', onChanged: (d) => setState(() => _days = d)),
        const SizedBox(height: 14),
        PremiumCard(
          gradient: const LinearGradient(colors: [Color(0xFF0B1E4A), AppColors.midnight900]),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LEADS FROM META ADS', style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.textOnDarkMuted).copyWith(letterSpacing: 1)),
                AnimatedCount(value: meta.length, style: AppText.display(size: 38, color: Colors.white, letterSpacing: -1.4)),
                Text('${share.toStringAsFixed(0)}% of all new leads', style: AppText.body(size: 12, color: const Color(0xFF9DB8FF))),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _HeroStat(label: 'Click-to-WhatsApp', value: ctwa),
              const SizedBox(height: 8),
              _HeroStat(label: 'Lead Ads forms', value: meta.length - ctwa),
            ]),
          ]),
        ).stagger(0),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: KpiTile(label: 'Closed-won', value: won, icon: Icons.emoji_events_rounded, color: AppColors.success)),
          const SizedBox(width: 10),
          Expanded(child: KpiTile(label: 'Win rate', value: conv, suffix: '%', icon: Icons.trending_up_rounded, color: AppColors.signal)),
          const SizedBox(width: 10),
          Expanded(child: KpiTile(label: 'Open', value: meta.length - closed, icon: Icons.hourglass_top_rounded, color: AppColors.meta)),
        ]).stagger(1),
        const SizedBox(height: 12),
        TitledCard(
          title: 'Daily ad leads',
          margin: EdgeInsets.zero,
          child: SizedBox(
            height: 130,
            child: BarChart(BarChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              barGroups: [
                for (var i = 0; i < perDay.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: perDay[i],
                      width: math.max(3, 180 / perDay.length),
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF6EA0FF), AppColors.meta]),
                    ),
                  ]),
              ],
            )),
          ),
        ).stagger(2),
        const SectionTitle('Performance by ad', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
        if (ads.isEmpty)
          PremiumEmpty(
            icon: Icons.ads_click_rounded,
            title: 'No ad leads yet',
            message: 'Run a Click-to-WhatsApp ad on Facebook or Instagram with your connected WhatsApp number — every chat becomes a tracked lead automatically.',
            action: GlowButton(label: 'Check integrations', expand: false, onPressed: () => context.push('/integrations')),
          ),
        ...ads.asMap().entries.map((e) {
          final list = e.value.value;
          final w = list.where((l) => l.isWon).length;
          final c = list.where((l) => l.isClosed).length;
          final ctw = list.any((l) => l.isCtwa);
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: PremiumCard(
              padding: const EdgeInsets.all(13),
              onTap: () => showPremiumSheet(
                context,
                title: e.value.key,
                subtitle: '${list.length} leads · $w won',
                builder: (_) => Column(children: list.map((l) => LeadCard(lead: l, compact: true)).toList()),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconBubble(icon: ctw ? Icons.chat_rounded : Icons.dynamic_form_rounded, color: AppColors.meta, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.value.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(ctw ? 'Click-to-WhatsApp' : 'Lead Ads form', style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${list.length}', style: AppText.display(size: 20, color: AppColors.meta)),
                    Text('leads', style: AppText.body(size: 10.5, color: AppColors.textTertiary)),
                  ]),
                ]),
                const SizedBox(height: 8),
                MetricBar(label: '$w won · ${c == 0 ? 0 : (w * 100 / c).toStringAsFixed(0)}% win rate', value: list.length, max: ads.first.value.length, color: AppColors.meta, trailing: '${list.length - c} open'),
              ]),
            ),
          ).stagger(e.key + 3);
        }),
        const SizedBox(height: 10),
        PremiumCard(
          color: AppColors.cream200,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How tracking works', style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              '• Click-to-WhatsApp: the first message carries the ad ID & headline — Codeskate creates the lead with source "Meta Ads (Click-to-WhatsApp)" and the ad as campaign.\n'
              '• Returning customers who tap another ad get a timeline note and "last ad" on their profile.\n'
              '• Lead Ads instant forms arrive through the connected Facebook page.',
              style: AppText.body(size: 12.5, color: AppColors.textSecondary, height: 1.55),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Text('Updated ${relTime(DateTime.now())}', style: AppText.body(size: 10.5, color: AppColors.textTertiary)),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final int value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        AnimatedCount(value: value, style: AppText.display(size: 19, color: const Color(0xFF9DB8FF))),
        Text(label, style: AppText.body(size: 10.5, color: AppColors.textOnDarkMuted)),
      ]);
}
