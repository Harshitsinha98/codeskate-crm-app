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
import 'workflow_vocab.dart';

Color wfStatusColor(String s) => switch (s) { 'active' => AppColors.success, 'paused' => AppColors.warning, 'archived' => AppColors.textTertiary, _ => AppColors.info };

class WorkflowsScreen extends StatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  State<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends State<WorkflowsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  String get _orgId => context.read<AuthProvider>().user!.activeOrgId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await WorkflowApi.list(_orgId);
      w.sort((a, b) => '${b['updatedAt']}'.compareTo('${a['updatedAt']}'));
      if (mounted) setState(() {
        _items = w;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    String trigger = 'lead_created';
    bool busy = false;
    final id = await showPremiumSheet<String>(
      context,
      title: 'New workflow',
      subtitle: 'When something happens → check conditions → run actions',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Name'),
          TextField(controller: name, decoration: const InputDecoration(hintText: 'e.g. Welcome Meta ad leads')),
          const FieldLabel('Description'),
          TextField(controller: desc, decoration: const InputDecoration(hintText: 'Optional')),
          const FieldLabel('Trigger'),
          ...WfVocab.triggers.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: PremiumCard(
                  padding: EdgeInsets.zero,
                  borderColor: trigger == e.key ? AppColors.primary : null,
                  onTap: () => setS(() => trigger = e.key),
                  child: PremiumTile(
                    icon: Icons.bolt_rounded,
                    title: e.value,
                    gradientIcon: trigger == e.key,
                    trailing: trigger == e.key ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : const SizedBox.shrink(),
                  ),
                ),
              )),
          const SizedBox(height: 14),
          GlowButton(
            label: 'Create & open builder',
            loading: busy,
            onPressed: () async {
              if (name.text.trim().isEmpty) return AppToast.error(context, 'Give it a name');
              setS(() => busy = true);
              try {
                final w = await WorkflowApi.create(_orgId, name: name.text.trim(), description: desc.text.trim(), triggerType: trigger);
                if (ctx.mounted) Navigator.pop(ctx, '${w['id']}');
              } on ApiException catch (e) {
                setS(() => busy = false);
                AppToast.error(context, e.message);
              }
            },
          ),
        ]),
      ),
    );
    if (id != null && mounted) {
      await context.push('/workflows/$id');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _items.where((w) => w['status'] == 'active').length;
    return Scaffold(
      appBar: PremiumAppBar(title: 'Workflows', subtitle: '$active active · ${_items.length} total'),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('New workflow')),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load workflows', message: _error)
              : _items.isEmpty
                  ? const PremiumEmpty(icon: Icons.account_tree_rounded, title: 'Automate your sales floor', message: 'Auto-assign, send templates, create follow-ups and escalate — without lifting a finger.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final w = _items[i];
                          final st = '${w['status'] ?? 'draft'}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: PremiumCard(
                              onTap: () async {
                                await context.push('/workflows/${w['id']}');
                                _load();
                              },
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                IconBubble(icon: Icons.account_tree_rounded, color: wfStatusColor(st), gradient: st == 'active'),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${w['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary)),
                                    Text('When: ${WfVocab.triggers[w['triggerType']] ?? w['triggerType']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: AppColors.textTertiary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${w['runCount'] ?? 0} runs${w['lastRunAt'] != null ? ' · last ${relTime(DateTime.tryParse('${w['lastRunAt']}'))} ago' : ''}${w['currentVersion'] != null ? ' · v${w['currentVersion']}' : ''}',
                                      style: AppText.body(size: 11, color: AppColors.textTertiary),
                                    ),
                                  ]),
                                ),
                                Pill(label: st, color: wfStatusColor(st)),
                              ]),
                            ),
                          ).stagger(i);
                        },
                      ),
                    ),
    );
  }
}
