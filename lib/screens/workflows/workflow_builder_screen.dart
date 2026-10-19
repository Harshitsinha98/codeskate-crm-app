import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/team_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';
import 'workflow_vocab.dart';
import 'workflows_screen.dart';

/// Visual workflow builder: trigger → conditions (ALL/ANY) → actions,
/// draft / publish / rollback, test-run and run history.
class WorkflowBuilderScreen extends StatefulWidget {
  final String workflowId;
  const WorkflowBuilderScreen({super.key, required this.workflowId});

  @override
  State<WorkflowBuilderScreen> createState() => _WorkflowBuilderScreenState();
}

class _WorkflowBuilderScreenState extends State<WorkflowBuilderScreen> {
  Map<String, dynamic>? _wf;
  List<Map<String, dynamic>> _versions = [];
  List<Map<String, dynamic>> _runs = [];
  String _logic = 'ALL';
  List<Map<String, dynamic>> _conditions = [];
  List<Map<String, dynamic>> _actions = [];
  bool _dirty = false;
  bool _busy = false;
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
      final r = await WorkflowApi.get(_orgId, widget.workflowId);
      final runs = await WorkflowApi.runs(_orgId, widget.workflowId).catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      final versions = ((r['versions'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final wf = Map<String, dynamic>.from(r['workflow'] ?? {});
      final draft = versions.where((v) => v['version'] == wf['draftVersion']).firstOrNull ?? versions.where((v) => v['version'] == wf['currentVersion']).firstOrNull;
      final def = Map<String, dynamic>.from(draft?['definition'] ?? {});
      setState(() {
        _wf = wf;
        _versions = versions;
        _runs = runs;
        _logic = '${def['conditionLogic'] ?? 'ALL'}';
        _conditions = ((def['conditions'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _actions = ((def['actions'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _dirty = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _definition => {'conditionLogic': _logic, 'conditions': _conditions, 'actions': _actions};

  Future<void> _run(Future<void> Function() fn, String ok) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) AppToast.success(context, ok);
      await _load();
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_actions.isEmpty) return AppToast.error(context, 'Add at least one action');
    await _run(() => WorkflowApi.saveDraft(_orgId, widget.workflowId, _definition), 'Draft saved');
  }

  Future<void> _publish() async {
    if (_dirty) {
      if (_actions.isEmpty) return AppToast.error(context, 'Add at least one action');
      setState(() => _busy = true);
      try {
        await WorkflowApi.saveDraft(_orgId, widget.workflowId, _definition);
      } on ApiException catch (e) {
        setState(() => _busy = false);
        return AppToast.error(context, e.message);
      }
    }
    await _run(() => WorkflowApi.publish(_orgId, widget.workflowId), 'Published — workflow is live');
  }

  Future<void> _testRun() async {
    final fields = <String, TextEditingController>{
      'source': TextEditingController(text: 'Meta Ads (Click-to-WhatsApp)'),
      'status': TextEditingController(text: 'New'),
      'city': TextEditingController(),
      'product': TextEditingController(),
    };
    await showPremiumSheet(
      context,
      title: 'Test run',
      subtitle: 'Checks conditions against a sample lead — no actions are executed',
      builder: (ctx) {
        Map<String, dynamic>? result;
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final e in fields.entries) ...[FieldLabel(e.key), TextField(controller: e.value)],
            const SizedBox(height: 16),
            GlowButton(
              label: 'Run test',
              icon: Icons.science_rounded,
              loading: busy,
              onPressed: () async {
                setS(() => busy = true);
                try {
                  if (_dirty) await WorkflowApi.saveDraft(_orgId, widget.workflowId, _definition);
                  final r = await WorkflowApi.testRun(_orgId, widget.workflowId, {for (final e in fields.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()});
                  setS(() {
                    result = r;
                    busy = false;
                  });
                } on ApiException catch (e) {
                  setS(() => busy = false);
                  AppToast.error(context, e.message);
                }
              },
            ),
            if (result != null) ...[
              const SizedBox(height: 16),
              PremiumCard(
                color: result!['matched'] == true ? AppColors.successLight : AppColors.errorLight,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(result!['matched'] == true ? '✅ Matched — actions would run' : '❌ Not matched', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary)),
                  ...((result!['results'] as List?) ?? []).whereType<Map>().map((c) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${c['passed'] == true ? '✓' : '✗'} ${(c['condition'] as Map?)?['type']} ${(c['condition'] as Map?)?['operator']} ${(c['condition'] as Map?)?['value'] ?? ''}',
                            style: AppText.mono(size: 12, weight: FontWeight.w500)),
                      )),
                ]),
              ),
            ],
          ]);
        });
      },
    );
  }

  Future<void> _editCondition([int? index]) async {
    final existing = index == null ? null : _conditions[index];
    String type = '${existing?['type'] ?? 'lead_source'}';
    String op = '${existing?['operator'] ?? 'equals'}';
    final value = TextEditingController(
        text: existing?['value'] is List ? (existing!['value'] as List).join(', ') : '${existing?['value'] ?? ''}');
    final result = await showPremiumSheet<Map<String, dynamic>>(
      context,
      title: index == null ? 'Add condition' : 'Edit condition',
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final ops = WfVocab.opsFor(type);
        if (!ops.containsKey(op)) op = ops.keys.first;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Field'),
          ChoiceChips<String>(options: WfVocab.conditionTypes.keys.toList(), selected: type, label: (t) => WfVocab.conditionTypes[t]!, onSelected: (t) => setS(() => type = t)),
          const FieldLabel('Operator'),
          ChoiceChips<String>(options: ops.keys.toList(), selected: op, label: (o) => ops[o]!, onSelected: (o) => setS(() => op = o)),
          if (WfVocab.needsValue(op)) ...[
            FieldLabel(WfVocab.listValue(op) ? 'Values (comma separated)' : 'Value'),
            TextField(controller: value, decoration: InputDecoration(hintText: type == 'lead_source' ? 'e.g. Meta Ads (Click-to-WhatsApp)' : (type == 'employee' ? 'employee uid' : ''))),
          ],
          const SizedBox(height: 18),
          GlowButton(
            label: 'Save condition',
            onPressed: () {
              final v = value.text.trim();
              if (WfVocab.needsValue(op) && v.isEmpty) return AppToast.error(context, 'Enter a value');
              Navigator.pop(ctx, {
                'type': type,
                'operator': op,
                if (WfVocab.needsValue(op)) 'value': WfVocab.listValue(op) ? v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() : v,
              });
            },
          ),
          if (index != null)
            TextButton(onPressed: () => Navigator.pop(ctx, {'__delete': true}), child: const Text('Remove condition', style: TextStyle(color: AppColors.error))),
        ]);
      }),
    );
    if (result == null) return;
    setState(() {
      if (result['__delete'] == true) {
        _conditions.removeAt(index!);
      } else if (index == null) {
        _conditions.add(result);
      } else {
        _conditions[index] = result;
      }
      _dirty = true;
    });
  }

  Future<void> _editAction([int? index]) async {
    final existing = index == null ? null : _actions[index];
    String type = '${existing?['type'] ?? 'whatsapp_template'}';
    Map<String, dynamic> p = Map<String, dynamic>.from(existing?['params'] ?? WfVocab.defaultParams(type));
    final team = context.read<TeamProvider>().activeMembers;
    final templates = context.read<ChatProvider>().templates;
    final statuses = context.read<SettingsProvider>().statuses;

    final result = await showPremiumSheet<Map<String, dynamic>>(
      context,
      title: index == null ? 'Add action' : 'Edit action',
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget text(String key, String label, {int lines = 1, String? hint}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FieldLabel(label),
              TextFormField(initialValue: '${p[key] ?? ''}', minLines: lines, maxLines: lines + 2, decoration: InputDecoration(hintText: hint), onChanged: (v) => p[key] = v),
            ]);
        Widget employee(String key) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const FieldLabel('Employee'),
              ChoiceChips<String>(options: team.map((m) => m.id).toList(), selected: p[key]?.toString(), label: (id) => team.firstWhere((m) => m.id == id).name, onSelected: (id) => setS(() => p[key] = id)),
            ]);
        final fields = <Widget>[];
        switch (type) {
          case 'assign':
          case 'reassign':
            fields.addAll([
              const FieldLabel('Strategy'),
              ChoiceChips<String>(
                options: const ['round_robin', 'workload', 'specific_employee'],
                selected: '${p['strategy']}',
                label: (s) => s.replaceAll('_', ' '),
                onSelected: (s) => setS(() => p['strategy'] = s),
              ),
              if (p['strategy'] == 'specific_employee') employee('employeeUid'),
              if (type == 'reassign') text('reason', 'Reason'),
            ]);
          case 'reminder':
            fields.addAll([
              const FieldLabel('Follow-up type'),
              ChoiceChips<String>(options: WfVocab.taskTypes, selected: '${p['taskType']}', label: (s) => s, onSelected: (s) => setS(() => p['taskType'] = s)),
              const FieldLabel('Due after (minutes)'),
              TextFormField(initialValue: '${p['afterMinutes'] ?? 60}', keyboardType: TextInputType.number, onChanged: (v) => p['afterMinutes'] = int.tryParse(v) ?? 0),
              text('title', 'Title', hint: 'e.g. Call new ad lead'),
            ]);
          case 'whatsapp_template':
            final t = templates.where((t) => t['id'] == p['templateId']).firstOrNull;
            final n = (t?['parameterCount'] as num?)?.toInt() ?? 0;
            final params = List<String>.from(p['parameters'] ?? []);
            while (params.length < n) {
              params.add('');
            }
            p['parameters'] = params.take(n).toList();
            fields.addAll([
              const FieldLabel('Template'),
              ChoiceChips<String>(
                options: templates.map((t) => '${t['id']}').toList(),
                selected: p['templateId']?.toString(),
                label: (id) => '${templates.firstWhere((t) => '${t['id']}' == id)['name']}',
                onSelected: (id) => setS(() {
                  p['templateId'] = id;
                  p['parameters'] = <String>[];
                }),
              ),
              for (var i = 0; i < n; i++) ...[
                FieldLabel('{{${i + 1}}} — supports {{name}}, {{phone}}'),
                TextFormField(initialValue: params[i], onChanged: (v) => (p['parameters'] as List)[i] = v),
              ],
            ]);
          case 'update_status':
            fields.addAll([
              const FieldLabel('New status'),
              ChoiceChips<String>(options: statuses, selected: '${p['status']}', label: (s) => s, colorOf: AppColors.forStatus, onSelected: (s) => setS(() => p['status'] = s)),
            ]);
          case 'email':
            fields.addAll([
              const FieldLabel('Send to'),
              ChoiceChips<String>(options: const ['lead', 'assignee', 'admins', 'custom'], selected: '${p['to']}', label: (s) => s, onSelected: (s) => setS(() => p['to'] = s)),
              if (p['to'] == 'custom') text('customEmail', 'Email address'),
              text('subject', 'Subject'),
              text('body', 'Body', lines: 4),
            ]);
          case 'activity':
            fields.add(text('text', 'Activity text', lines: 2));
          case 'escalation':
            fields.addAll([
              const FieldLabel('Escalate to'),
              ChoiceChips<String>(
                options: const ['admins', 'assignee_manager', 'specific_employee'],
                selected: '${p['escalateTo']}',
                label: (s) => s.replaceAll('_', ' '),
                onSelected: (s) => setS(() => p['escalateTo'] = s),
              ),
              if (p['escalateTo'] == 'specific_employee') employee('employeeUid'),
              text('message', 'Message', lines: 2),
            ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Action'),
          ChoiceChips<String>(
            options: WfVocab.actions.keys.toList(),
            selected: type,
            label: (t) => WfVocab.actions[t]!,
            onSelected: (t) => setS(() {
              type = t;
              p = Map<String, dynamic>.from(WfVocab.defaultParams(t));
            }),
          ),
          ...fields,
          const SizedBox(height: 18),
          GlowButton(label: 'Save action', onPressed: () => Navigator.pop(ctx, {'type': type, 'params': p})),
          if (index != null) TextButton(onPressed: () => Navigator.pop(ctx, {'__delete': true}), child: const Text('Remove action', style: TextStyle(color: AppColors.error))),
        ]);
      }),
    );
    if (result == null) return;
    setState(() {
      if (result['__delete'] == true) {
        _actions.removeAt(index!);
      } else if (index == null) {
        _actions.add(result);
      } else {
        _actions[index] = result;
      }
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wf = _wf;
    final status = '${wf?['status'] ?? 'draft'}';
    return Scaffold(
      appBar: PremiumAppBar(
        title: '${wf?['name'] ?? 'Workflow'}',
        subtitle: wf == null ? null : 'When: ${WfVocab.triggers[wf['triggerType']] ?? wf['triggerType']}',
        actions: [
          if (wf != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (v) {
                if (v == 'test') _testRun();
                if (['active', 'paused', 'archived'].contains(v)) {
                  _run(() => WorkflowApi.setStatus(_orgId, widget.workflowId, v), 'Workflow $v');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'test', child: Text('Test run')),
                if (status != 'active' && wf['currentVersion'] != null) const PopupMenuItem(value: 'active', child: Text('Activate')),
                if (status == 'active') const PopupMenuItem(value: 'paused', child: Text('Pause')),
                if (status != 'archived') const PopupMenuItem(value: 'archived', child: Text('Archive')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load workflow', message: _error)
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
                  Row(children: [
                    Pill(label: status, color: wfStatusColor(status), solid: true),
                    const SizedBox(width: 8),
                    if (wf?['currentVersion'] != null) Pill(label: 'Live v${wf!['currentVersion']}', color: AppColors.success),
                    if (wf?['draftVersion'] != null) ...[const SizedBox(width: 6), Pill(label: 'Draft v${wf!['draftVersion']}', color: AppColors.info)],
                    const Spacer(),
                    if (_dirty) const Pill(label: 'Unsaved', color: AppColors.warning, icon: Icons.edit_rounded),
                  ]),
                  const SizedBox(height: 14),
                  _Node(
                    icon: Icons.bolt_rounded,
                    color: AppColors.orange600,
                    title: 'WHEN',
                    child: Text('${WfVocab.triggers[wf?['triggerType']] ?? wf?['triggerType']}', style: AppText.body(size: 14.5, weight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                  _Connector(),
                  _Node(
                    icon: Icons.filter_alt_rounded,
                    color: AppColors.info,
                    title: 'IF',
                    trailing: _conditions.length > 1
                        ? SegmentTabs<String>(values: const ['ALL', 'ANY'], selected: _logic, label: (s) => s == 'ALL' ? 'All match' : 'Any match', onChanged: (s) => setState(() {
                              _logic = s;
                              _dirty = true;
                            }))
                        : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (_conditions.isEmpty) Text('No conditions — runs for every event', style: AppText.body(size: 13, color: AppColors.textTertiary)),
                      ..._conditions.asMap().entries.map((e) {
                        final c = e.value;
                        final v = c['value'] is List ? (c['value'] as List).join(', ') : '${c['value'] ?? ''}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Pressable(
                            onTap: () => _editCondition(e.key),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.infoLight.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                              child: Text.rich(TextSpan(style: AppText.body(size: 13, color: AppColors.textPrimary), children: [
                                TextSpan(text: '${WfVocab.conditionTypes[c['type']] ?? c['type']} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: '${WfVocab.opsFor('${c['type']}')[c['operator']] ?? c['operator']} '),
                                TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.info)),
                              ])),
                            ),
                          ),
                        );
                      }),
                      TextButton.icon(onPressed: () => _editCondition(), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add condition')),
                    ]),
                  ),
                  _Connector(),
                  _Node(
                    icon: Icons.play_circle_fill_rounded,
                    color: AppColors.success,
                    title: 'THEN',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (_actions.isEmpty) Text('Add at least one action', style: AppText.body(size: 13, color: AppColors.error)),
                      ..._actions.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Pressable(
                              onTap: () => _editAction(e.key),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppColors.successLight.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  Text('${e.key + 1}', style: AppText.mono(size: 12, color: AppColors.success)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(WfVocab.describeAction(e.value), style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary))),
                                  const Icon(Icons.edit_rounded, size: 15, color: AppColors.textTertiary),
                                ]),
                              ),
                            ),
                          )),
                      TextButton.icon(onPressed: () => _editAction(), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add action')),
                    ]),
                  ),
                  if (_versions.isNotEmpty) ...[
                    const SectionTitle('Versions', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
                    ..._versions.map((v) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PremiumCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Text('v${v['version']}', style: AppText.mono(size: 14)),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${v['changeNote'] ?? v['status']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12.5, color: AppColors.textSecondary))),
                              Pill(label: '${v['status']}', color: v['status'] == 'published' ? AppColors.success : AppColors.textTertiary),
                              if (v['status'] == 'superseded')
                                TextButton(
                                  onPressed: () => _run(() => WorkflowApi.rollback(_orgId, widget.workflowId, (v['version'] as num).toInt()), 'Rolled back to v${v['version']}'),
                                  child: const Text('Restore'),
                                ),
                            ]),
                          ),
                        )),
                  ],
                  if (_runs.isNotEmpty) ...[
                    const SectionTitle('Recent runs', padding: EdgeInsets.fromLTRB(4, 18, 4, 10)),
                    ..._runs.take(15).map((r) {
                      final acts = ((r['actionsExecuted'] as List?) ?? []).whereType<Map>().toList();
                      final failed = acts.where((a) => a['status'] == 'failed').length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PremiumCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Icon(failed > 0 ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: failed > 0 ? AppColors.warning : AppColors.success, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('${acts.length} actions${failed > 0 ? ' · $failed failed' : ''} · ${r['entityType']} ${r['entityId'] ?? ''}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12.5, color: AppColors.textSecondary)),
                            ),
                            Text(relTime(DateTime.tryParse('${r['startedAt']}')), style: AppText.body(size: 11, color: AppColors.textTertiary)),
                          ]),
                        ),
                      );
                    }),
                  ],
                ]),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Expanded(child: GlowButton(label: 'Save draft', variant: GlowVariant.ghost, loading: _busy && _dirty, onPressed: _busy || !_dirty ? null : _saveDraft)),
                const SizedBox(width: 10),
                Expanded(child: GlowButton(label: 'Publish', icon: Icons.rocket_launch_rounded, loading: _busy && !_dirty, onPressed: _busy ? null : _publish)),
              ]),
            ),
    );
  }
}

class _Node extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Node({required this.icon, required this.color, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => PremiumCard(
        borderColor: color.withValues(alpha: 0.3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconBubble(icon: icon, color: color, size: 32, gradient: true),
            const SizedBox(width: 10),
            Text(title, style: AppText.mono(size: 13, color: color)),
            const Spacer(),
            if (trailing != null) Flexible(child: trailing!),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

class _Connector extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(width: 2, height: 22, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.border, AppColors.orange300]))),
      );
}
