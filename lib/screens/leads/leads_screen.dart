import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leads_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';
import 'call_options_sheet.dart';
import 'lead_action_sheets.dart';

enum _Source { all, meta, whatsapp, website, google, manual }

extension on _Source {
  String get label => switch (this) {
        _Source.all => 'All sources',
        _Source.meta => 'Meta ads',
        _Source.whatsapp => 'WhatsApp',
        _Source.website => 'Website',
        _Source.google => 'Google',
        _Source.manual => 'Manual / import',
      };

  bool matches(LeadModel l) {
    final s = (l.source ?? '').toLowerCase();
    return switch (this) {
      _Source.all => true,
      _Source.meta => l.isFromMetaAd,
      _Source.whatsapp => s.contains('whatsapp') && !l.isFromMetaAd,
      _Source.website => s.contains('website') || s.contains('web'),
      _Source.google => s.contains('google'),
      _Source.manual => s.isEmpty || s.contains('manual') || s.contains('import') || s.contains('csv'),
    };
  }
}

enum _Sort { newest, recentActivity, name }

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  String _status = 'All';
  String _q = '';
  _Source _source = _Source.all;
  _Sort _sort = _Sort.newest;
  bool _hotOnly = false;

  List<LeadModel> _apply(List<LeadModel> all) {
    final q = _q.toLowerCase();
    final out = all.where((l) {
      if (_status != 'All' && l.status != _status) return false;
      if (!_source.matches(l)) return false;
      if (_hotOnly && !l.isHot) return false;
      if (q.isEmpty) return true;
      return l.name.toLowerCase().contains(q) || l.phone.contains(q) || (l.email?.toLowerCase().contains(q) ?? false) || l.adLabel.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case _Sort.newest:
        out.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      case _Sort.recentActivity:
        out.sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      case _Sort.name:
        out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return out;
  }

  void _openFilters() {
    showPremiumSheet(
      context,
      title: 'Filter & sort',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('Source'),
          ChoiceChips<_Source>(
            options: _Source.values,
            selected: _source,
            label: (s) => s.label,
            onSelected: (s) {
              setS(() {});
              setState(() => _source = s);
            },
          ),
          const FieldLabel('Sort by'),
          ChoiceChips<_Sort>(
            options: _Sort.values,
            selected: _sort,
            label: (s) => switch (s) { _Sort.newest => 'Newest', _Sort.recentActivity => 'Recent activity', _Sort.name => 'Name A–Z' },
            onSelected: (s) {
              setS(() {});
              setState(() => _sort = s);
            },
          ),
          const FieldLabel('Priority'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _hotOnly,
            title: const Text('Hot leads only'),
            onChanged: (v) {
              setS(() {});
              setState(() => _hotOnly = v);
            },
          ),
          const SizedBox(height: 12),
          GlowButton(label: 'Show results', onPressed: () => Navigator.pop(ctx)),
        ]),
      ),
    );
  }

  void _openAddMenu() {
    showPremiumSheet(
      context,
      title: 'Add leads',
      builder: (ctx) => Column(children: [
        PremiumTile(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Add a single lead',
          subtitle: 'Name, phone, requirement',
          gradientIcon: true,
          onTap: () {
            Navigator.pop(ctx);
            showAddLeadSheet(context);
          },
        ),
        PremiumTile(
          icon: Icons.table_rows_rounded,
          title: 'Bulk import',
          subtitle: 'Paste rows from Excel / Sheets (name, phone, email)',
          color: AppColors.ember500,
          gradientIcon: true,
          onTap: () {
            Navigator.pop(ctx);
            _bulkImport();
          },
        ),
      ]),
    );
  }

  Future<void> _bulkImport() async {
    final ctrl = TextEditingController();
    await showPremiumSheet(
      context,
      title: 'Bulk import leads',
      subtitle: 'One lead per line: name, phone, email (optional), requirement (optional)',
      builder: (ctx) {
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: ctrl,
              minLines: 6,
              maxLines: 12,
              style: AppText.mono(size: 12.5, weight: FontWeight.w500),
              decoration: const InputDecoration(hintText: 'Rahul Sharma, 9876543210, rahul@mail.com, 2BHK\nPriya, 9123456780'),
            ),
            const SizedBox(height: 16),
            GlowButton(
              label: 'Import & auto-assign',
              icon: Icons.cloud_upload_rounded,
              loading: busy,
              onPressed: () async {
                final rows = <Map<String, dynamic>>[];
                for (final raw in ctrl.text.split('\n')) {
                  final parts = raw.split(RegExp(r'[,\t;]')).map((p) => p.trim()).toList();
                  if (parts.length < 2) continue;
                  final digits = parts[1].replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) continue;
                  rows.add({
                    'name': parts[0].isEmpty ? 'Lead' : parts[0],
                    'phone': digits.substring(digits.length - 10),
                    if (parts.length > 2 && parts[2].contains('@')) 'email': parts[2],
                    if (parts.length > 3) 'requirement': parts.sublist(3).join(', '),
                    'source': 'Bulk Import',
                  });
                }
                if (rows.isEmpty) {
                  AppToast.error(context, 'No valid rows — each line needs a name and 10-digit phone');
                  return;
                }
                setS(() => busy = true);
                try {
                  final n = await LeadsApi.bulkImport(orgId: context.read<AuthProvider>().user!.activeOrgId!, rows: rows);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) AppToast.success(context, '$n leads imported and assigned');
                } on ApiException catch (e) {
                  setS(() => busy = false);
                  AppToast.error(context, e.message);
                }
              },
            ),
          ]);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsP = context.watch<LeadsProvider>();
    final statuses = ['All', ...context.watch<SettingsProvider>().statuses];
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    final list = _apply(leadsP.leads);
    final counts = <String, int>{'All': leadsP.leads.length};
    for (final l in leadsP.leads) {
      counts[l.status] = (counts[l.status] ?? 0) + 1;
    }
    final filtersOn = _source != _Source.all || _hotOnly || _sort != _Sort.newest;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(children: [
        Column(children: [
          AuroraBackground(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isAdmin ? 'Leads' : 'My leads', style: AppText.display(size: 26, color: Colors.white, letterSpacing: -0.8)),
                        Text('${list.length} of ${leadsP.leads.length} shown', style: AppText.body(size: 12.5, color: AppColors.textOnDarkMuted)),
                      ]),
                    ),
                    Pressable(
                      onTap: _openFilters,
                      child: GlassPanel(
                        padding: const EdgeInsets.all(10),
                        radius: 14,
                        child: Stack(clipBehavior: Clip.none, children: [
                          const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                          if (filtersOn)
                            Positioned(right: -3, top: -3, child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.orange500, shape: BoxShape.circle))),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  SearchField(hint: 'Search name, phone, email or ad', dark: true, onChanged: (v) => setState(() => _q = v)),
                  const SizedBox(height: 12),
                  SegmentTabs<String>(
                    dark: true,
                    values: statuses,
                    selected: _status,
                    counts: counts,
                    label: (s) => s,
                    onChanged: (s) => setState(() => _status = s),
                  ),
                ]),
              ),
            ),
          ),
          if (_source != _Source.all)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                Pill(label: _source.label, color: _source == _Source.meta ? AppColors.meta : AppColors.primaryDark, icon: Icons.filter_alt_rounded),
                const SizedBox(width: 6),
                Pressable(onTap: () => setState(() => _source = _Source.all), child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary)),
              ]),
            ),
          Expanded(
            child: leadsP.isLoading
                ? const SkeletonList(count: 7, height: 86)
                : list.isEmpty
                    ? PremiumEmpty(
                        icon: _q.isNotEmpty ? Icons.search_off_rounded : Icons.people_outline_rounded,
                        title: _q.isNotEmpty ? 'No matching leads' : 'No leads here yet',
                        message: _q.isNotEmpty ? 'Try a different name, number or ad.' : 'New leads from WhatsApp, Meta ads and your website land here instantly.',
                        action: isAdmin ? GlowButton(label: 'Add lead', icon: Icons.add_rounded, expand: false, onPressed: _openAddMenu) : null,
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => HapticFeedback.mediumImpact(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: list.length,
                          itemBuilder: (context, i) => LeadCard(lead: list[i]).stagger(i, stepMs: 28),
                        ),
                      ),
          ),
        ]),
        if (isAdmin)
          Positioned(
            right: 18,
            bottom: 18,
            child: Pressable(
              onTap: _openAddMenu,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.glow()),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Add leads', style: AppText.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Premium lead row with quick call / WhatsApp actions.
class LeadCard extends StatelessWidget {
  final LeadModel lead;
  final bool compact;
  const LeadCard({super.key, required this.lead, this.compact = false});

  IconData get _sourceIcon {
    if (lead.isFromMetaAd) return Icons.ads_click_rounded;
    final s = (lead.source ?? '').toLowerCase();
    if (s.contains('whatsapp')) return Icons.chat_rounded;
    if (s.contains('website') || s.contains('web')) return Icons.language_rounded;
    if (s.contains('google')) return Icons.travel_explore_rounded;
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(lead.status);
    final stale = !lead.isClosed && lead.updatedAt != null && DateTime.now().difference(lead.updatedAt!).inDays >= 3;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        onTap: () => context.push('/lead/${lead.id}'),
        child: Row(children: [
          GradientAvatar(
            name: lead.name,
            size: 46,
            badge: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: lead.isFromMetaAd ? AppColors.meta : AppColors.midnight800,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(_sourceIcon, size: 9, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(lead.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14.5, weight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                if (lead.isHot) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.local_fire_department_rounded, size: 15, color: AppColors.ember500)),
                if (lead.blacklisted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.block_rounded, size: 14, color: AppColors.error)),
              ]),
              const SizedBox(height: 2),
              Text(
                lead.isFromMetaAd ? lead.adLabel : (lead.requirement ?? lead.phone),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 12.3, color: lead.isFromMetaAd ? AppColors.meta : AppColors.textTertiary, weight: lead.isFromMetaAd ? FontWeight.w600 : FontWeight.w400),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Pill(label: lead.status, color: color),
                const SizedBox(width: 6),
                if (lead.assignedToName != null)
                  Flexible(
                    child: Text(lead.assignedToName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, color: AppColors.textTertiary, weight: FontWeight.w500)),
                  ),
                if (stale) ...[const SizedBox(width: 6), const Pill(label: 'Idle 3d+', color: AppColors.warning)],
                const Spacer(),
                Text(relTime(lead.createdAt), style: AppText.body(size: 10.5, color: AppColors.textTertiary)),
              ]),
            ]),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            Column(children: [
              _RoundAction(icon: Icons.call_rounded, color: AppColors.success, onTap: () => showCallOptionsSheet(context, lead)),
              const SizedBox(height: 6),
              _RoundAction(
                icon: Icons.chat_rounded,
                color: AppColors.whatsappDark,
                onTap: () => context.push('/conversation/${lead.id}'),
                onLongPress: () {
                  final digits = lead.phone.replaceAll(RegExp(r'\D'), '');
                  launchUrl(Uri.parse('https://wa.me/${digits.length == 10 ? '91$digits' : digits}'), mode: LaunchMode.externalApplication);
                },
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _RoundAction({required this.icon, required this.color, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 17, color: color),
        ),
      );
}
