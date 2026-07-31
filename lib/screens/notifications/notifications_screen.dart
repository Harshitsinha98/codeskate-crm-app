import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/theme/app_colors.dart';
import '../../providers/notifications_provider.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _getIcon(NotificationModel notif) {
    final text = notif.text.toLowerCase();
    if (text.contains('lead') || text.contains('assigned')) return Icons.person_add_rounded;
    if (text.contains('follow') || text.contains('overdue')) return Icons.event_note_rounded;
    if (text.contains('whatsapp') || text.contains('message')) return Icons.chat_rounded;
    if (text.contains('won') || text.contains('closed')) return Icons.celebration_rounded;
    if (text.contains('lost')) return Icons.cancel_rounded;
    return Icons.notifications_rounded;
  }

  Color _getColor(NotificationModel notif) {
    final text = notif.text.toLowerCase();
    if (text.contains('overdue')) return AppColors.error;
    if (text.contains('won') || text.contains('success')) return AppColors.success;
    if (text.contains('whatsapp')) return AppColors.whatsapp;
    if (text.contains('follow')) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final notifs = context.watch<NotificationsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifs.unreadCount > 0)
            TextButton(
              onPressed: () => notifs.markAllAsRead(),
              child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: notifs.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : notifs.notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.notifications_off_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All caught up!',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No unread notifications',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notifs.notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifs.notifications[index];
                    return _NotificationTile(
                      notification: notif,
                      icon: _getIcon(notif),
                      color: _getColor(notif),
                      onDismiss: () => notifs.markAsRead(notif.id),
                    ).animate(delay: Duration(milliseconds: 50 * index))
                        .slideX(begin: 0.05, duration: 250.ms)
                        .fadeIn();
                  },
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final IconData icon;
  final Color color;
  final VoidCallback? onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.color,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.success.withOpacity(0.1),
        child: const Icon(Icons.check_circle_rounded, color: AppColors.success),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.read ? Colors.white : AppColors.primaryLight.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.read ? AppColors.divider : AppColors.primary.withOpacity(0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: notification.read ? FontWeight.w400 : FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (notification.createdAt != null)
                    Text(
                      timeago.format(notification.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                    ),
                ],
              ),
            ),
            if (!notification.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
