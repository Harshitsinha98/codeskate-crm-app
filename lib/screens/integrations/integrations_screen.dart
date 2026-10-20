import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/crm_api.dart';
import '../../services/meta_connect.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

/// All lead channels: WhatsApp Cloud API, Meta Lead Ads + Click-to-WhatsApp,
/// Google Ads webhook, website form & developer API key.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  Map<String, dynamic>? _wa;
  Map<String, dynamic>? _ads;
  Map<String, dynamic>? _web;
  bool _loading = true;
  final Set<String> _busy = {};

  String get _orgId => context.read<AuthProvider>().user!.activeOrgId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Future<Map<String, dynamic>?> safe(Future<Map<String, dynamic>> f) => f.then<Map<String, dynamic>?>((v) => v).catchError((_) => null);
    final r = await Future.wait([safe(IntegrationsApi.whatsappStatus(_orgId)), safe(IntegrationsApi.adLeadsStatus(_orgId)), safe(IntegrationsApi.websiteIntegration(_orgId))]);
    if (!mounted) return;
    setState(() {
      _wa = r[0];
      _ads = r[1];
      _web = r[2];
      _loading = false;
    });
  }

  Future<void> _do(String key, Future<String> Function() fn) async {
    setState(() => _busy.add(key));
    try {
      final msg = await fn();
      if (mounted) AppToast.success(context, msg);
      _load();
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  void _openWeb(String path) => launchUrl(Uri.parse('${AppConstants.webAppUrl}$path'), mode: LaunchMode.externalApplication);

  /// In-app Meta Lead Ads connect: Facebook login → pick a Page → subscribe.
  Future<void> _connectMeta() async {
    setState(() => _busy.add('meta'));
    try {
      final token = await MetaConnect.login();
      final pages = await MetaConnect.pages(_orgId, token);
      if (!mounted) return;
      if (pages.isEmpty) {
        AppToast.error(context, 'No eligible Facebook Pages. Use an account with Lead Ads access to the Page.');
        return;
      }
      final pageId = pages.length == 1
          ? pages.first['id']
          : await showPremiumSheet<String>(
              context,
              title: 'Choose a Facebook Page',
              subtitle: 'Instant-form leads from this Page enter this workspace',
              builder: (ctx) => Column(
                children: pages
                    .map((p) => PremiumTile(
                          icon: Icons.flag_rounded,
                          color: AppColors.meta,
                          title: p['name'] ?? 'Page',
                          subtitle: 'Page ID ${p['id']}',
                          onTap: () => Navigator.pop(ctx, p['id']),
                        ))
                    .toList(),
              ),
            );
      if (pageId == null || !mounted) return;
      final name = await MetaConnect.connect(_orgId, pageId, token);
      if (mounted) AppToast.success(context, 'Connected "$name" — new ad leads will arrive automatically');
      _load();
    } on MetaConnectException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } catch (e) {
      if (mounted) AppToast.error(context, 'Meta connect failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy.remove('meta'));
    }
  }

  Future<void> _showSecret(String title, Map<String, String> values) => showPremiumSheet(
        context,
        title: title,
        subtitle: 'Copy these now — secrets are only shown once',
        builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: values.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FieldLabel(e.key),
                      Pressable(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: e.value));
                          AppToast.success(context, '${e.key} copied');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.midnight900, borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            Expanded(child: SelectableText(e.value, style: AppText.mono(size: 12, color: AppColors.orange300, weight: FontWeight.w500))),
                            const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
                          ]),
                        ),
                      ),
                    ]),
                  ))
              .toList(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wa = _wa ?? {};
    final meta = Map<String, dynamic>.from(_ads?['meta'] ?? {});
    final google = Map<String, dynamic>.from(_ads?['google'] ?? {});
    final web = _web ?? {};
    final waConnected = wa['connected'] == true;
    final reauth = wa['reauthorizationRequired'] == true;

    return Scaffold(
      appBar: PremiumAppBar(title: 'Integrations', subtitle: 'Every lead channel in one place', actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)]),
      body: _loading
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
                _Channel(
                  icon: Icons.chat_rounded,
                  color: AppColors.whatsappDark,
                  title: 'WhatsApp Business',
                  status: reauth ? 'Reconnect needed' : (waConnected ? 'Connected' : (wa['connecting'] == true ? 'Connecting' : 'Not connected')),
                  ok: waConnected && !reauth,
                  details: [
                    if (wa['phoneNumberId'] != null) 'Phone number ID: ${wa['phoneNumberId']}',
                    if (wa['connectedAt'] != null) 'Connected ${relTime(DateTime.tryParse('${wa['connectedAt']}'))} ago',
                  ],
                  actions: waConnected
                      ? [
                          _Btn('Sync now', Icons.sync_rounded, _busy.contains('sync'), () => _do('sync', () async {
                                final r = await IntegrationsApi.whatsappSync(_orgId);
                                return '${r['imported'] ?? 0} queued messages imported';
                              })),
                          _Btn('Templates', Icons.dashboard_customize_rounded, _busy.contains('tpl'), () => _do('tpl', () async {
                                final r = await IntegrationsApi.templatesSync(_orgId);
                                return '${r['available'] ?? 0} templates ready';
                              })),
                          _Btn('Repair webhook', Icons.build_circle_rounded, _busy.contains('repair'), () => _do('repair', () async {
                                await IntegrationsApi.whatsappRepair(_orgId);
                                return 'Webhook re-subscribed';
                              })),
                          _Btn('Disconnect', Icons.link_off_rounded, _busy.contains('disc'), () async {
                            final ok = await confirmAction(context, title: 'Disconnect WhatsApp?', message: 'Inbox, AI and broadcasts stop until you reconnect.', destructive: true, confirmLabel: 'Disconnect');
                            if (ok) {
                              _do('disc', () async {
                                await IntegrationsApi.whatsappDisconnect(_orgId);
                                return 'WhatsApp disconnected';
                              });
                            }
                          }, danger: true),
                        ]
                      : [_Btn('Connect on web', Icons.open_in_new_rounded, false, () => _openWeb('/admin/whatsapp'))],
                  footnote: waConnected ? null : 'Meta Embedded Signup runs in the browser — tap to finish on app.codeskate.com.',
                ),
                _Channel(
                  icon: Icons.ads_click_rounded,
                  color: AppColors.meta,
                  title: 'Meta Ads (Facebook & Instagram)',
                  status: meta['connected'] == true ? 'Lead Ads connected' : 'Lead Ads not connected',
                  ok: meta['connected'] == true,
                  details: [
                    if (meta['pageName'] != null) 'Page: ${meta['pageName']}',
                    if (meta['lastDeliveryAt'] != null) 'Last lead ${relTime(DateTime.tryParse('${meta['lastDeliveryAt']}'))} ago',
                    'Click-to-WhatsApp ads: ${waConnected ? 'auto-tracked ✓' : 'connect WhatsApp first'}',
                    if (meta['setupMessage'] != null && meta['connected'] != true) '${meta['setupMessage']}',
                  ],
                  actions: [
                    _Btn('Ad performance', Icons.insights_rounded, false, () {}, primary: true, route: '/meta-ads'),
                    if (meta['connected'] == true)
                      _Btn('Disconnect', Icons.link_off_rounded, _busy.contains('meta'), () => _do('meta', () async {
                            await IntegrationsApi.metaDisconnect(_orgId);
                            return 'Meta Lead Ads disconnected';
                          }), danger: true)
                    else if (AppConstants.metaAdsEnabled)
                      _Btn('Connect Facebook Page', Icons.facebook_rounded, _busy.contains('meta'), () => _connectMeta(), primary: true)
                    else
                      _Btn('Connect page', Icons.open_in_new_rounded, false, () => _openWeb('/admin/ad-leads')),
                  ],
                  footnote: 'Click-to-WhatsApp leads are captured automatically from the WhatsApp webhook — no page connection needed.',
                ),
                _Channel(
                  icon: Icons.travel_explore_rounded,
                  color: AppColors.statusRinging,
                  title: 'Google Ads lead forms',
                  status: google['configured'] == true ? 'Webhook active' : 'Not configured',
                  ok: google['configured'] == true,
                  details: [if (google['webhookUrl'] != null) '${google['webhookUrl']}', if (google['keyPrefix'] != null) 'Key: ${google['keyPrefix']}…'],
                  actions: [
                    _Btn(google['configured'] == true ? 'Rotate key' : 'Create webhook', Icons.key_rounded, _busy.contains('google'), () async {
                      setState(() => _busy.add('google'));
                      try {
                        final r = await IntegrationsApi.googleAdsWebhook(_orgId);
                        if (mounted) await _showSecret('Google Ads webhook', {'Webhook URL': '${r['webhookUrl']}', 'Key': '${r['key']}'});
                        _load();
                      } on ApiException catch (e) {
                        if (mounted) AppToast.error(context, e.message);
                      } finally {
                        if (mounted) setState(() => _busy.remove('google'));
                      }
                    }),
                  ],
                ),
                _Channel(
                  icon: Icons.language_rounded,
                  color: AppColors.ember500,
                  title: 'Website lead form',
                  status: web['configured'] == true ? 'Form live' : 'Not set up',
                  ok: web['configured'] == true,
                  details: [
                    if (web['formTitle'] != null) 'Form: ${web['formTitle']}',
                    if ((web['allowedDomains'] as List?)?.isNotEmpty == true) 'Domains: ${(web['allowedDomains'] as List).join(', ')}',
                  ],
                  actions: [
                    _Btn(web['configured'] == true ? 'Regenerate links' : 'Create form', Icons.dynamic_form_rounded, _busy.contains('web'), () async {
                      setState(() => _busy.add('web'));
                      try {
                        final r = await IntegrationsApi.createWebsiteIntegration(_orgId, domains: List<String>.from(web['allowedDomains'] ?? []), title: web['formTitle']?.toString());
                        if (mounted) {
                          await _showSecret('Website form', {
                            if (r['embedUrl'] != null) 'Hosted form / iframe URL': '${r['embedUrl']}',
                            'Webhook URL': '${r['webhookUrl']}',
                          });
                        }
                        _load();
                      } on ApiException catch (e) {
                        if (mounted) AppToast.error(context, e.message);
                      } finally {
                        if (mounted) setState(() => _busy.remove('web'));
                      }
                    }),
                    _Btn('Developer API key', Icons.code_rounded, _busy.contains('key'), () async {
                      setState(() => _busy.add('key'));
                      try {
                        final r = await IntegrationsApi.websiteKey(_orgId);
                        if (mounted) await _showSecret('Website API', {'Endpoint': '${r['endpoint']}', 'Header x-codeskate-intake-key': '${r['key']}'});
                      } on ApiException catch (e) {
                        if (mounted) AppToast.error(context, e.message);
                      } finally {
                        if (mounted) setState(() => _busy.remove('key'));
                      }
                    }),
                  ],
                ),
              ].asMap().entries.map((e) => e.value.stagger(e.key)).toList()),
            ),
    );
  }
}

class _Btn {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;
  final bool danger;
  final bool primary;
  final String? route;
  _Btn(this.label, this.icon, this.busy, this.onTap, {this.danger = false, this.primary = false, this.route});
}

class _Channel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String status;
  final bool ok;
  final List<String> details;
  final List<_Btn> actions;
  final String? footnote;

  const _Channel({required this.icon, required this.color, required this.title, required this.status, required this.ok, this.details = const [], this.actions = const [], this.footnote});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBubble(icon: icon, color: color, gradient: true, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: ok ? AppColors.success : AppColors.warning, shape: BoxShape.circle, boxShadow: ok ? AppColors.glow(AppColors.success, 0.6) : null),
                ),
                const SizedBox(width: 6),
                Text(status, style: AppText.body(size: 12.5, weight: FontWeight.w600, color: ok ? AppColors.success : AppColors.warning)),
              ]),
            ]),
          ),
        ]),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...details.map((d) => Padding(padding: const EdgeInsets.only(top: 3), child: Text(d, style: AppText.body(size: 12.2, color: AppColors.textSecondary)))),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions
                .map((a) => Pressable(
                      onTap: a.busy
                          ? null
                          : (a.route != null ? () => context.push(a.route!) : a.onTap),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: a.primary ? AppColors.primaryGradient : null,
                          color: a.primary ? null : (a.danger ? AppColors.errorLight : AppColors.surfaceVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (a.busy)
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            Icon(a.icon, size: 15, color: a.primary ? Colors.white : (a.danger ? AppColors.error : AppColors.textPrimary)),
                          const SizedBox(width: 6),
                          Text(a.label, style: AppText.body(size: 12.5, weight: FontWeight.w700, color: a.primary ? Colors.white : (a.danger ? AppColors.error : AppColors.textPrimary))),
                        ]),
                      ),
                    ))
                .toList(),
          ),
        ],
        if (footnote != null) ...[
          const SizedBox(height: 10),
          Text(footnote!, style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
        ],
      ]),
    );
  }
}
