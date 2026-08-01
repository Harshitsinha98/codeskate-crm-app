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
          ? 'The 24-hour reply window has closed. An approved template is required (use the web CRM).'
          : result.code == 'no_backend'
              ? 'Backend URL not set. Run with --dart-define=BACKEND_URL=...'
              : (result.error ?? 'Could not send message.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
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
