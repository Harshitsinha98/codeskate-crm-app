import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/theme/app_colors.dart';
import '../../models/lead_model.dart';

class LeadMiniCard extends StatelessWidget {
  final LeadModel lead;
  final VoidCallback? onTap;

  const LeadMiniCard({super.key, required this.lead, this.onTap});

  Color get _statusColor {
    switch (lead.status) {
      case 'New':
        return AppColors.statusNew;
      case 'Ringing':
        return AppColors.statusRinging;
      case 'Meeting Fixed':
        return AppColors.statusMeetingFixed;
      case 'Negotiation':
        return AppColors.statusNegotiation;
      case 'Follow-up':
        return AppColors.statusFollowUp;
      case 'Closed-Won':
        return AppColors.statusClosedWon;
      case 'Lost':
        return AppColors.statusLost;
      default:
        return AppColors.textTertiary;
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  lead.initials,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lead.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lead.isHot)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '🔥 Hot',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lead.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (lead.source != null) ...[
                        Icon(Icons.campaign_rounded, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            lead.source!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (lead.createdAt != null)
                        Text(
                          timeago.format(lead.createdAt!, locale: 'en_short'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
