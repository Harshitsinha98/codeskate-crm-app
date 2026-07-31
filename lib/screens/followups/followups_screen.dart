import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/leads_provider.dart';
import '../../models/followup_model.dart';

class FollowUpsScreen extends StatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leads = context.watch<LeadsProvider>();

    final overdue = leads.overdueFollowUpsList;
    final today = leads.todayFollowUpsList;
    final upcoming = leads.followUps
        .where((f) => f.isOpen && !f.isOverdue && !f.isDueToday)
        .toList()
      ..sort((a, b) => (a.dueAt ?? DateTime.now()).compareTo(b.dueAt ?? DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-ups'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Overdue (${overdue.length})'),
            Tab(text: 'Today (${today.length})'),
            Tab(text: 'Upcoming (${upcoming.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowUpList(context, overdue, isOverdue: true),
          _buildFollowUpList(context, today),
          _buildFollowUpList(context, upcoming),
        ],
      ),
    );
  }

  Widget _buildFollowUpList(BuildContext context, List<FollowUpModel> items, {bool isOverdue = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isOverdue ? AppColors.success : AppColors.primary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isOverdue ? Icons.check_circle_rounded : Icons.event_available_rounded,
                size: 36,
                color: isOverdue ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOverdue ? 'No overdue tasks!' : 'No follow-ups here',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isOverdue ? 'Great job staying on track' : 'Tasks will appear when scheduled',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _FollowUpCard(
          followUp: items[index],
          isOverdue: isOverdue,
          onTap: () {
            if (items[index].leadId.isNotEmpty) {
              context.push('/lead/${items[index].leadId}');
            }
          },
        ).animate(delay: Duration(milliseconds: 50 * index))
            .slideY(begin: 0.1, duration: 300.ms)
            .fadeIn();
      },
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  final FollowUpModel followUp;
  final bool isOverdue;
  final VoidCallback? onTap;

  const _FollowUpCard({
    required this.followUp,
    this.isOverdue = false,
    this.onTap,
  });

  IconData get _typeIcon {
    switch (followUp.type) {
      case 'Call': return Icons.phone_rounded;
      case 'WhatsApp': return Icons.chat_rounded;
      case 'Email': return Icons.email_rounded;
      case 'Meeting': return Icons.videocam_rounded;
      case 'Visit': return Icons.location_on_rounded;
      default: return Icons.event_note_rounded;
    }
  }

  Color get _typeColor {
    switch (followUp.type) {
      case 'Call': return AppColors.success;
      case 'WhatsApp': return AppColors.whatsapp;
      case 'Email': return AppColors.info;
      case 'Meeting': return AppColors.statusNegotiation;
      case 'Visit': return AppColors.warning;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOverdue ? AppColors.errorLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOverdue ? AppColors.error.withOpacity(0.2) : AppColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon, size: 22, color: _typeColor),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    followUp.title ?? '${followUp.type} Follow-up',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (followUp.leadName != null)
                    Text(
                      followUp.leadName!,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: isOverdue ? AppColors.error : AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        followUp.dueAt != null
                            ? DateFormat('MMM dd, hh:mm a').format(followUp.dueAt!)
                            : 'No due date',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOverdue ? AppColors.error : AppColors.textTertiary,
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status badge
            if (isOverdue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Overdue',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
