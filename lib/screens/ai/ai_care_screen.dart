import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

/// AI customer care: agent settings, knowledge base, playground, analytics.
class AiCareScreen extends StatefulWidget {
  const AiCareScreen({super.key});

  @override
  State<AiCareScreen> createState() => _AiCareScreenState();
}

class _AiCareScreenState extends State<AiCareScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'AI customer care',
        subtitle: 'Your 24×7 WhatsApp agent',
        bottomHeight: 46,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textOnDarkMuted,
          indicatorColor: AppColors.orange400,
          dividerColor: Colors.transparent,
          tabs: const [Tab(text: 'Agent'), Tab(text: 'Knowledge'), Tab(text: 'Playground'), Tab(text: 'Analytics')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [_AgentTab(), _KnowledgeTab(), _PlaygroundTab(), _AnalyticsTab()]),
    );
  }
}

String _org(BuildContext c) => c.read<AuthProvider>().user!.activeOrgId!;

// ── Agent settings ─────────────────────────────────────────────────────────
class _AgentTab extends StatefulWidget {
  const _AgentTab();
  @override
  State<_AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends State<_AgentTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _cfg;
  String? _error;
  bool _saving = false;
  final _bizName = TextEditingController();
  final _bizDesc = TextEditingController();
  final _welcome = TextEditingController();
  final _fallback = TextEditingController();
  final _catalogueLink = TextEditingController();
  final _website = TextEditingController();
  final _keywords = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await AiApi.config(_org(context));
      if (!mounted) return;
      setState(() => _cfg = c);
      _bizName.text = '${c['businessName'] ?? ''}';
      _bizDesc.text = '${c['businessDescription'] ?? ''}';
      _welcome.text = '${c['welcomeMessage'] ?? ''}';
      _fallback.text = '${c['fallbackMessage'] ?? ''}';
      _catalogueLink.text = '${c['catalogueLink'] ?? ''}';
      _website.text = '${c['websiteUrl'] ?? ''}';
      _keywords.text = ((c['escalationKeywords'] as List?) ?? []).join(', ');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _set(String k, dynamic v) => setState(() => _cfg![k] = v);

  Future<void> _save() async {
    setState(() => _saving = true);
    final c = Map<String, dynamic>.from(_cfg!)
      ..['businessName'] = _bizName.text.trim()
      ..['businessDescription'] = _bizDesc.text.trim()
      ..['welcomeMessage'] = _welcome.text.trim()
      ..['fallbackMessage'] = _fallback.text.trim()
      ..['catalogueLink'] = _catalogueLink.text.trim()
      ..['websiteUrl'] = _website.text.trim()
      ..['escalationKeywords'] = _keywords.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    c.remove('orgId');
    try {
      final r = await AiApi.saveConfig(_org(context), c);
      if (mounted) {
        setState(() => _cfg = r);
        AppToast.success(context, 'AI agent settings saved');
      }
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) return PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load AI settings', message: _error);
    final c = _cfg;
    if (c == null) return const SkeletonList();
    final enabled = c['enabled'] == true;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      PremiumCard(
        gradient: enabled ? const LinearGradient(colors: [AppColors.midnight900, AppColors.midnight700]) : null,
        child: Row(children: [
          IconBubble(icon: Icons.auto_awesome_rounded, color: enabled ? AppColors.orange400 : AppColors.textTertiary, gradient: enabled),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(enabled ? 'AI agent is live' : 'AI agent is off', style: AppText.body(size: 15, weight: FontWeight.w700, color: enabled ? Colors.white : AppColors.textPrimary)),
              Text(enabled ? 'Replying to WhatsApp customers automatically' : 'Turn on to auto-reply and qualify leads', style: AppText.body(size: 12, color: enabled ? AppColors.textOnDarkMuted : AppColors.textTertiary)),
            ]),
          ),
          Switch.adaptive(value: enabled, onChanged: (v) => _set('enabled', v)),
        ]),
      ),
      const FieldLabel('Business name'),
      TextField(controller: _bizName),
      const FieldLabel('What does your business do?'),
      TextField(controller: _bizDesc, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'Products, service area, timings, USP…')),
      const FieldLabel('Tone'),
      ChoiceChips<String>(
        options: const ['friendly', 'formal', 'sales'],
        selected: '${c['tone'] ?? 'friendly'}',
        label: (t) => switch (t) { 'formal' => '🎩 Formal', 'sales' => '🚀 Sales', _ => '😊 Friendly' },
        onSelected: (t) => _set('tone', t),
      ),
      FieldLabel('Confidence threshold · ${(((c['confidenceThreshold'] as num?) ?? 0.7) * 100).round()}%'),
      Slider(
        value: ((c['confidenceThreshold'] as num?) ?? 0.7).toDouble().clamp(0.3, 1.0),
        min: 0.3,
        max: 1,
        divisions: 14,
        activeColor: AppColors.primary,
        onChanged: (v) => _set('confidenceThreshold', double.parse(v.toStringAsFixed(2))),
      ),
      Row(children: [
        Expanded(
          child: _NumberField(label: 'Daily reply limit', value: (c['dailyLimit'] as num?)?.toInt() ?? 500, onChanged: (v) => _set('dailyLimit', v)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _NumberField(label: 'Max replies / lead', value: (c['maxAutoRepliesPerLead'] as num?)?.toInt() ?? 10, onChanged: (v) => _set('maxAutoRepliesPerLead', v)),
        ),
      ]),
      const SizedBox(height: 6),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Only during working hours'),
        subtitle: Text('${c['workingHoursStart'] ?? 9}:00 – ${c['workingHoursEnd'] ?? 18}:00'),
        value: c['workingHoursOnly'] == true,
        onChanged: (v) => _set('workingHoursOnly', v),
      ),
      if (c['workingHoursOnly'] == true)
        RangeSlider(
          values: RangeValues(((c['workingHoursStart'] as num?) ?? 9).toDouble(), ((c['workingHoursEnd'] as num?) ?? 18).toDouble()),
          min: 0,
          max: 24,
          divisions: 24,
          activeColor: AppColors.primary,
          labels: RangeLabels('${c['workingHoursStart'] ?? 9}:00', '${c['workingHoursEnd'] ?? 18}:00'),
          onChanged: (r) => setState(() {
            c['workingHoursStart'] = r.start.round();
            c['workingHoursEnd'] = r.end.round();
          }),
        ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Qualify new leads'),
        subtitle: const Text('Ask qualification questions before handing over'),
        value: c['qualificationEnabled'] == true,
        onChanged: (v) => _set('qualificationEnabled', v),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Introduce the human agent'),
        subtitle: Text('${c['agentIntroTemplate'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
        value: c['agentIntroEnabled'] != false,
        onChanged: (v) => _set('agentIntroEnabled', v),
      ),
      const FieldLabel('Welcome message'),
      TextField(controller: _welcome, minLines: 1, maxLines: 3),
      const FieldLabel('Fallback message (when unsure)'),
      TextField(controller: _fallback, minLines: 1, maxLines: 3),
      const FieldLabel('Escalate to human on keywords'),
      TextField(controller: _keywords, decoration: const InputDecoration(hintText: 'refund, complaint, manager')),
      const FieldLabel('Catalogue'),
      ChoiceChips<String>(
        options: const ['none', 'product_db', 'whatsapp_catalogue', 'website'],
        selected: '${c['catalogueMode'] ?? 'none'}',
        label: (m) => switch (m) { 'product_db' => 'Product catalogue', 'whatsapp_catalogue' => 'WhatsApp catalogue', 'website' => 'Website', _ => 'None' },
        onSelected: (m) => _set('catalogueMode', m),
      ),
      if (c['catalogueMode'] == 'whatsapp_catalogue') ...[const FieldLabel('Catalogue link'), TextField(controller: _catalogueLink)],
      if (c['catalogueMode'] == 'website') ...[const FieldLabel('Website URL'), TextField(controller: _website)],
      const SizedBox(height: 22),
      GlowButton(label: 'Save AI settings', icon: Icons.save_rounded, loading: _saving, onPressed: _save),
    ]);
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _NumberField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FieldLabel(label),
        TextFormField(initialValue: '$value', keyboardType: TextInputType.number, onChanged: (v) => onChanged(int.tryParse(v) ?? value)),
      ]);
}

// ── Knowledge base ─────────────────────────────────────────────────────────
class _KnowledgeTab extends StatefulWidget {
  const _KnowledgeTab();
  @override
  State<_KnowledgeTab> createState() => _KnowledgeTabState();
}

class _KnowledgeTabState extends State<_KnowledgeTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([AiApi.articles(_org(context)), AiApi.kbStats(_org(context))]);
      if (mounted) setState(() {
        _items = r[0] as List<Map<String, dynamic>>;
        _stats = r[1] as Map<String, dynamic>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? a]) async {
    final title = TextEditingController(text: '${a?['title'] ?? ''}');
    final content = TextEditingController(text: '${a?['content'] ?? ''}');
    final category = TextEditingController(text: '${a?['category'] ?? 'general'}');
    bool active = a?['active'] != false;
    bool busy = false;
    await showPremiumSheet(
      context,
      title: a == null ? 'New article' : 'Edit article',
      subtitle: 'FAQs, pricing, policies — the AI answers from these',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Title'),
          TextField(controller: title, decoration: const InputDecoration(hintText: 'e.g. Delivery & returns')),
          const FieldLabel('Content'),
          TextField(controller: content, minLines: 5, maxLines: 12, maxLength: 10000),
          const FieldLabel('Category'),
          TextField(controller: category),
          if (a != null) SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (v) => setS(() => active = v)),
          const SizedBox(height: 14),
          GlowButton(
            label: 'Save article',
            loading: busy,
            onPressed: () async {
              if (title.text.trim().isEmpty || content.text.trim().isEmpty) return AppToast.error(context, 'Title and content are required');
              setS(() => busy = true);
              final body = {'title': title.text.trim(), 'content': content.text.trim(), 'category': category.text.trim(), if (a != null) 'active': active};
              try {
                a == null ? await AiApi.createArticle(_org(context), body) : await AiApi.updateArticle(_org(context), '${a['id']}', body);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } on ApiException catch (e) {
                setS(() => busy = false);
                AppToast.error(context, e.message);
              }
            },
          ),
          if (a != null)
            TextButton(
              onPressed: () async {
                final ok = await confirmAction(context, title: 'Delete article?', message: 'The AI will stop using it.', destructive: true, confirmLabel: 'Delete');
                if (!ok) return;
                await AiApi.deleteArticle(_org(context), '${a['id']}');
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const SkeletonList();
    if (_error != null) return PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load', message: _error);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        Row(children: [
          Expanded(child: KpiTile(label: 'Articles', value: (_stats['totalArticles'] as num?) ?? _items.length, icon: Icons.menu_book_rounded)),
          const SizedBox(width: 10),
          Expanded(child: KpiTile(label: 'Est. tokens', value: (_stats['estimatedTokens'] as num?) ?? 0, icon: Icons.memory_rounded, color: AppColors.signal)),
        ]),
        const SizedBox(height: 12),
        GlowButton(label: 'Add article', icon: Icons.add_rounded, variant: GlowVariant.dark, onPressed: () => _edit()),
        const SizedBox(height: 14),
        if (_items.isEmpty) const PremiumEmpty(icon: Icons.menu_book_rounded, title: 'Teach your AI', message: 'Add FAQs, prices and policies so it answers like your best salesperson.'),
        ..._items.asMap().entries.map((e) {
          final a = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: PremiumCard(
              onTap: () => _edit(a),
              padding: const EdgeInsets.all(13),
              child: Row(children: [
                IconBubble(icon: Icons.article_rounded, color: a['active'] == false ? AppColors.textTertiary : AppColors.orange600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${a['content']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: AppColors.textTertiary)),
                  ]),
                ),
                const SizedBox(width: 6),
                Pill(label: '${a['category'] ?? 'general'}', color: AppColors.signal),
              ]),
            ),
          ).stagger(e.key);
        }),
      ]),
    );
  }
}

// ── Playground ─────────────────────────────────────────────────────────────
class _PlaygroundTab extends StatefulWidget {
  const _PlaygroundTab();
  @override
  State<_PlaygroundTab> createState() => _PlaygroundTabState();
}

class _PlaygroundTabState extends State<_PlaygroundTab> with AutomaticKeepAliveClientMixin {
  final _msg = TextEditingController();
  final List<(String, Map<String, dynamic>?)> _log = [];
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _ask() async {
    final m = _msg.text.trim();
    if (m.isEmpty) return;
    setState(() {
      _log.add((m, null));
      _busy = true;
      _msg.clear();
    });
    try {
      final r = await AiApi.test(_org(context), m);
      if (mounted) setState(() => _log.add(('', r)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _log.add(('', {'success': false, 'error': e.message})));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Expanded(
        child: _log.isEmpty
            ? const PremiumEmpty(icon: Icons.science_rounded, title: 'Test your AI agent', message: 'Type a question the way a customer would on WhatsApp.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: _log.map((e) {
                  if (e.$2 == null) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8, left: 60),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(18)),
                        child: Text(e.$1, style: AppText.body(size: 14, color: Colors.white)),
                      ),
                    );
                  }
                  final r = e.$2!;
                  final ok = r['success'] == true;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12, right: 40),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: ok ? AppColors.border : AppColors.error)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ok ? '${r['response']}' : '${r['error']}', style: AppText.body(size: 14, color: ok ? AppColors.textPrimary : AppColors.error)),
                        if (ok) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            Pill(label: 'Intent: ${r['intent']}', color: AppColors.signal),
                            Pill(label: '${(((r['confidence'] as num?) ?? 0) * 100).round()}% sure', color: AppColors.success),
                            Pill(label: '${r['tokensUsed']} tokens', color: AppColors.textTertiary),
                          ]),
                        ],
                      ]),
                    ),
                  );
                }).toList(),
              ),
      ),
      SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(children: [
          Expanded(child: TextField(controller: _msg, onSubmitted: (_) => _ask(), decoration: const InputDecoration(hintText: 'e.g. What is the price of the blue saree?'))),
          const SizedBox(width: 8),
          GlowButton(label: 'Ask', expand: false, height: 48, loading: _busy, onPressed: _ask),
        ]),
      ),
    ]);
  }
}

// ── Analytics ──────────────────────────────────────────────────────────────
class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _u;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AiApi.usage(_org(context)).then((v) {
      if (mounted) setState(() => _u = v);
    }).catchError((e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) return PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load usage', message: _error);
    if (_u == null) return const SkeletonList();
    final t = Map<String, dynamic>.from(_u!['totals'] ?? {});
    final daily = ((_u!['dailyStats'] as List?) ?? []).whereType<Map>().toList();
    final cost = Map<String, dynamic>.from(_u!['estimatedCost'] ?? {});
    return ListView(padding: const EdgeInsets.all(16), children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          KpiTile(label: 'Conversations handled', value: (t['totalCalls'] as num?) ?? 0, icon: Icons.forum_rounded),
          KpiTile(label: 'Resolution rate', value: (_u!['resolutionRate'] as num?) ?? 0, suffix: '%', icon: Icons.verified_rounded, color: AppColors.success),
          KpiTile(label: 'Auto replies', value: (t['autoReplies'] as num?) ?? 0, icon: Icons.auto_awesome_rounded, color: AppColors.signal),
          KpiTile(label: 'Escalations', value: (t['escalations'] as num?) ?? 0, icon: Icons.support_agent_rounded, color: AppColors.warning),
        ],
      ),
      const SizedBox(height: 12),
      TitledCard(
        title: 'Daily AI conversations · ${_u!['period'] ?? '30 days'}',
        margin: EdgeInsets.zero,
        trailing: cost['inr'] != null ? Pill(label: '≈ ${inr(cost['inr'] as num)}', color: AppColors.primaryDark) : null,
        child: SizedBox(
          height: 150,
          child: daily.isEmpty
              ? Center(child: Text('No AI activity yet', style: AppText.body(size: 13, color: AppColors.textTertiary)))
              : BarChart(BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  barGroups: [
                    for (var i = 0; i < daily.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: ((daily[i]['totalCalls'] as num?) ?? 0).toDouble(),
                          width: 7,
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.ember400, AppColors.orange500]),
                        ),
                      ]),
                  ],
                )),
        ),
      ),
    ]);
  }
}
