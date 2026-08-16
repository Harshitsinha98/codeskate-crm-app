import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/theme/app_colors.dart';
import '../../models/lead_model.dart';
import 'ui_kit.dart';

/// Modern SaaS list row for a lead: initials avatar, name + phone, a status
/// dot-label, and a quiet timestamp. Flat surface, hairline border.
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
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              lead.initials,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: _statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lead.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (lead.isHot) ...[
                      const SizedBox(width: 6),
                      const StatusPill(
                        label: 'HOT',
                        color: AppColors.error,
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    // status dot + label
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lead.status,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                    Text(
                      '  ·  ${lead.phone}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Time + chevron
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lead.createdAt != null)
                Text(
                  timeago.format(lead.createdAt!, locale: 'en_short'),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              const SizedBox(height: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary.withOpacity(0.55)),
            ],
          ),
        ],
      ),
    );
  }
}
