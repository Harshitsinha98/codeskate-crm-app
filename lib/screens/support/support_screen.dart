import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/crm_api.dart';
import '../widgets/premium.dart';

/// AI help desk (POST /api/v1/support/chat) with escalation to a ticket.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _msg = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _history = [];
  bool _thinking = false;

  static const _suggestions = ['How do I connect WhatsApp?', 'How are leads assigned?', 'Track Meta ad leads', 'Add a teammate'];

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _msg.text).trim();
    if (text.isEmpty || _thinking) return;
    setState(() {
      _history.add({'role': 'user', 'text': text});
      _thinking = true;
      _msg.clear();
    });
    _end();
    try {
      final reply = await SupportApi.chat(text, _history.sublist(0, _history.length - 1).take(8).toList());
      if (mounted) setState(() => _history.add({'role': 'assistant', 'text': reply}));
    } on ApiException catch (e) {
      if (mounted) setState(() => _history.add({'role': 'assistant', 'text': '⚠️ ${e.message}'}));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _end();
    }
  }

  void _end() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: 300.ms, curve: Curves.easeOut);
      });

  Future<void> _ticket() async {
    final subject = TextEditingController(text: _history.isEmpty ? '' : _history.firstWhere((h) => h['role'] == 'user', orElse: () => {'text': ''})['text']);
    final desc = TextEditingController();
    bool busy = false;
    await showPremiumSheet(
      context,
      title: 'Talk to a human',
      subtitle: 'Our team replies in Internal tickets',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Subject'),
          TextField(controller: subject),
          const FieldLabel('Describe the issue'),
          TextField(controller: desc, minLines: 3, maxLines: 6),
          const SizedBox(height: 18),
          GlowButton(
            label: 'Raise ticket',
            loading: busy,
            onPressed: () async {
              setS(() => busy = true);
              try {
                await SupportApi.ticket(
                  subject: subject.text.trim().isEmpty ? 'Support request' : subject.text.trim(),
                  description: desc.text.trim().isEmpty ? _history.where((h) => h['role'] == 'user').map((h) => h['text']).join(' | ') : desc.text.trim(),
                  history: _history,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) AppToast.success(context, 'Ticket raised — we\'ll get back to you soon');
              } on ApiException catch (e) {
                setS(() => busy = false);
                AppToast.error(context, e.message);
              }
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Help & support',
        subtitle: 'Codeskate AI assistant',
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_rounded),
            tooltip: 'WhatsApp us',
            onPressed: () => launchUrl(Uri.parse(AppConstants.supportWhatsApp), mode: LaunchMode.externalApplication),
          ),
          IconButton(icon: const Icon(Icons.confirmation_number_rounded), tooltip: 'Raise ticket', onPressed: _ticket),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _history.isEmpty
              ? ListView(padding: const EdgeInsets.all(24), children: [
                  const SizedBox(height: 30),
                  const Center(child: BrandMark(size: 70)),
                  const SizedBox(height: 18),
                  Text('Hi! How can we help?', textAlign: TextAlign.center, style: AppText.display(size: 24)),
                  const SizedBox(height: 6),
                  Text('Ask anything about Codeskate — setup, WhatsApp, ads, billing.', textAlign: TextAlign.center, style: AppText.body(size: 13.5, color: AppColors.textTertiary)),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions.map((s) => ActionChip(label: Text(s), onPressed: () => _send(s))).toList(),
                  ),
                ])
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length + (_thinking ? 1 : 0) + (_history.length >= 4 ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _history.length && _thinking) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (k) {
                            return Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))
                                .animate(onPlay: (c) => c.repeat())
                                .fadeIn(delay: (k * 150).ms, duration: 300.ms)
                                .then()
                                .fadeOut(duration: 300.ms);
                          })),
                        ),
                      );
                    }
                    if (i >= _history.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(child: TextButton.icon(onPressed: _ticket, icon: const Icon(Icons.support_agent_rounded), label: const Text('Still stuck? Raise a ticket'))),
                      );
                    }
                    final h = _history[i];
                    final me = h['role'] == 'user';
                    return Align(
                      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: me ? AppColors.primaryGradient : null,
                          color: me ? null : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: me ? null : Border.all(color: AppColors.border),
                        ),
                        child: Text(h['text'] ?? '', style: AppText.body(size: 14, color: me ? Colors.white : AppColors.textPrimary)),
                      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(children: [
            Expanded(child: TextField(controller: _msg, onSubmitted: (_) => _send(), textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Ask a question…'))),
            const SizedBox(width: 8),
            Pressable(
              onTap: _thinking ? null : _send,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle, boxShadow: AppColors.glow(AppColors.orange500, 0.3)),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
