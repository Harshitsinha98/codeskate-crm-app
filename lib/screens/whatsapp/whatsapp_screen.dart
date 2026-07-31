import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.whatsapp.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chat_rounded, size: 18, color: AppColors.whatsapp),
            ),
            const SizedBox(width: 10),
            const Text('WhatsApp'),
          ],
        ),
      ),
      body: chat.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.whatsapp))
          : chat.conversationList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.whatsapp.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.whatsapp),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'WhatsApp conversations with leads\nwill appear here',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chat.conversationList.length,
                  itemBuilder: (context, index) {
                    final conv = chat.conversationList[index];
                    final name = conv['name'] ?? conv['leadName'] ?? 'Unknown';
                    final phone = conv['phone'] ?? conv['leadPhone'] ?? '';
                    final lastMsg = conv['lastMessage'] ?? '';
                    final lastContactAt = conv['lastContactAt'];
                    DateTime? lastTime;
                    if (lastContactAt != null) {
                      if (lastContactAt is int) {
                        lastTime = DateTime.fromMillisecondsSinceEpoch(lastContactAt);
                      } else if (lastContactAt is String) {
                        lastTime = DateTime.tryParse(lastContactAt);
                      }
                    }

                    return _ConversationTile(
                      name: name,
                      phone: phone,
                      lastMessage: lastMsg,
                      lastTime: lastTime,
                      aiEnabled: conv['aiEnabled'] ?? true,
                      onTap: () => context.push('/conversation/${conv['id']}'),
                    ).animate(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.05, duration: 250.ms).fadeIn();
                  },
                ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String phone;
  final String lastMessage;
  final DateTime? lastTime;
  final bool aiEnabled;
  final VoidCallback? onTap;

  const _ConversationTile({
    required this.name,
    required this.phone,
    required this.lastMessage,
    this.lastTime,
    this.aiEnabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.whatsapp.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whatsapp,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastTime != null)
                        Text(
                          timeago.format(lastTime!, locale: 'en_short'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (aiEnabled)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.info),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          lastMessage.isNotEmpty ? lastMessage : phone,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}
