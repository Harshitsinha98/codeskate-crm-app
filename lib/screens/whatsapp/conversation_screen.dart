import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/leads_provider.dart';
import '../../models/message_model.dart';

class ConversationScreen extends StatefulWidget {
  final String leadId;

  const ConversationScreen({super.key, required this.leadId});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();

  bool _showTemplates = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ChatProvider>().openConversation(widget.leadId);
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().closeConversation();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final chat = context.read<ChatProvider>();
    final result = await chat.sendMessage(widget.leadId, text);
    if (!mounted) return;
    if (result.ok) {
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      final msg = result.code == 'template_required'
          ? null // handled below: show template picker
          : result.code == 'no_backend'
              ? 'Backend URL not set. Run with --dart-define=BACKEND_URL=...'
              : (result.error ?? 'Could not send message.');
      if (result.code == 'template_required') {
        // Auto-show the template picker when the 24h window is closed.
        setState(() => _showTemplates = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('24h window closed. Select a template below to message this lead.'),
            backgroundColor: AppColors.warning,
          ),
        );
      } else if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _takeOver() async {
    final chat = context.read<ChatProvider>();
    final result = await chat.takeOver(widget.leadId);
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Could not take over the chat.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _reEnableAi() async {
    final chat = context.read<ChatProvider>();
    final result = await chat.reEnableAI(widget.leadId);
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Could not re-enable AI.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final leads = context.watch<LeadsProvider>();
    final lead = leads.getLeadById(widget.leadId);
    final messages = chat.getMessages(widget.leadId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.whatsapp.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  lead?.initials ?? '?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whatsapp,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead?.name ?? 'Conversation',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    lead?.phone ?? '',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            // AI status / human-takeover control bar
            _AiStatusBar(
              aiEnabled: lead?.aiEnabled ?? true,
              busy: chat.isTogglingAi,
              onTakeOver: _takeOver,
              onReEnableAi: _reEnableAi,
            ),
            // Messages
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppColors.textTertiary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: TextStyle(color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Messages from WhatsApp will appear here',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _MessageBubble(
                          message: messages[index],
                          showTimestamp: _shouldShowTimestamp(messages, index),
                        );
                      },
                    ),
            ),

            // Template picker (shown when 24h window closed or user taps icon)
            if (_showTemplates)
              _TemplatePicker(
                leadId: widget.leadId,
                onClose: () => setState(() => _showTemplates = false),
              ),

            // Reply composer
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Type a reply…',
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Template button
                    GestureDetector(
                      onTap: () => setState(() => _showTemplates = !_showTemplates),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _showTemplates
                              ? AppColors.primary.withOpacity(0.12)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          size: 18,
                          color: _showTemplates ? AppColors.primary : AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: chat.isSending ? null : _sendMessage,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: chat.isSending
                              ? AppColors.whatsapp.withOpacity(0.5)
                              : AppColors.whatsapp,
                          borderRadius: BorderRadius.circular(23),
                        ),
                        child: chat.isSending
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded,
                                size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowTimestamp(List<MessageModel> messages, int index) {
    if (index == 0) return true;
    final current = messages[index].timestamp;
    final previous = messages[index - 1].timestamp;
    if (current == null || previous == null) return false;
    return current.difference(previous).inMinutes > 30;
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool showTimestamp;

  const _MessageBubble({required this.message, this.showTimestamp = false});

  @override
  Widget build(BuildContext context) {
    final isOutbound = message.isOutbound;

    return Column(
      children: [
        if (showTimestamp && message.timestamp != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                DateFormat('MMM dd, hh:mm a').format(message.timestamp!),
                style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
            ),
          ),
        Align(
          alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOutbound ? AppColors.whatsappBubbleSent : AppColors.whatsappBubbleReceived,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isOutbound ? 16 : 4),
                bottomRight: Radius.circular(isOutbound ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.text ?? '[Media message]',
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.timestamp != null)
                      Text(
                        DateFormat('hh:mm a').format(message.timestamp!),
                        style: TextStyle(fontSize: 9, color: AppColors.textTertiary),
                      ),
                    if (isOutbound) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.status == 'read'
                            ? Icons.done_all_rounded
                            : message.status == 'delivered'
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                        size: 14,
                        color: message.status == 'read' ? AppColors.info : AppColors.textTertiary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


/// Shows whether AI is auto-replying or a human has taken over, with a
/// toggle to take over / re-enable AI (mirrors the web CRM ChatSessionControls).
class _AiStatusBar extends StatelessWidget {
  final bool aiEnabled;
  final bool busy;
  final VoidCallback onTakeOver;
  final VoidCallback onReEnableAi;

  const _AiStatusBar({
    required this.aiEnabled,
    required this.busy,
    required this.onTakeOver,
    required this.onReEnableAi,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = aiEnabled
        ? AppColors.info.withOpacity(0.08)
        : AppColors.warning.withOpacity(0.12);
    final Color fg = aiEnabled ? AppColors.info : AppColors.secondaryDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: bg,
      child: Row(
        children: [
          Icon(
            aiEnabled ? Icons.smart_toy_rounded : Icons.person_rounded,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              aiEnabled
                  ? 'AI is auto-replying to this customer'
                  : 'Human handling — AI paused',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: aiEnabled ? onTakeOver : onReEnableAi,
                  style: TextButton.styleFrom(
                    foregroundColor: fg,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    backgroundColor: Colors.white.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    aiEnabled ? 'Take over' : 'Re-enable AI',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
        ],
      ),
    );
  }
}



/// Collapsible template picker with parameter inputs and send button.
class _TemplatePicker extends StatefulWidget {
  final String leadId;
  final VoidCallback onClose;

  const _TemplatePicker({required this.leadId, required this.onClose});

  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  String? _selectedId;
  List<TextEditingController> _paramControllers = [];
  bool _sending = false;

  Map<String, dynamic>? get _selected {
    final templates = context.read<ChatProvider>().templates;
    return templates.where((t) => t['id'] == _selectedId).firstOrNull;
  }

  void _selectTemplate(String id, int paramCount) {
    setState(() {
      _selectedId = id;
      for (final c in _paramControllers) {
        c.dispose();
      }
      _paramControllers =
          List.generate(paramCount, (_) => TextEditingController());
    });
  }

  Future<void> _send() async {
    if (_selectedId == null) return;
    final params = _paramControllers.map((c) => c.text.trim()).toList();
    if (params.any((p) => p.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill all template values before sending.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    final chat = context.read<ChatProvider>();
    final result = await chat.sendTemplate(widget.leadId, _selectedId!, params);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.ok) {
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template sent!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Could not send template.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _paramControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final templates = chat.templates;

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(
              children: [
                Icon(Icons.description_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Send approved template',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: widget.onClose,
                  color: AppColors.textTertiary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Template list or parameter inputs
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _selectedId == null
                  ? _buildTemplateList(templates)
                  : _buildParamInputs(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(List<Map<String, dynamic>> templates) {
    if (templates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No approved templates synced. Ask an admin to sync from Automation.',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      );
    }
    return Column(
      children: templates.map((t) {
        final name = t['name']?.toString() ?? 'Template';
        final lang = t['language']?.toString() ?? '';
        final preview = t['preview']?.toString() ?? '';
        final paramCount = (t['parameterCount'] as num?)?.toInt() ?? 0;
        return GestureDetector(
          onTap: () => _selectTemplate(t['id'].toString(), paramCount),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name · $lang',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.textTertiary),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParamInputs() {
    final t = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back to list
        GestureDetector(
          onTap: () => setState(() => _selectedId = null),
          child: Row(
            children: [
              Icon(Icons.arrow_back_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                t?['name']?.toString() ?? 'Template',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
            ],
          ),
        ),
        if (t?['preview'] != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t!['preview'].toString(),
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: 8),
        ..._paramControllers.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextField(
              controller: e.value,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Value for {{${e.key + 1}}}',
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.whatsapp,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(_sending ? 'Sending…' : 'Send template'),
          ),
        ),
      ],
    );
  }
}
