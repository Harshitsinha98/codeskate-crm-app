import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/leads_provider.dart';
import '../../models/lead_model.dart';
import '../../services/call_tracker_service.dart';
import 'bridge_call_sheet.dart';

class LeadDetailScreen extends StatelessWidget {
  final String leadId;

  const LeadDetailScreen({super.key, required this.leadId});

  Color _statusColor(String status) {
    switch (status) {
      case 'New': return AppColors.statusNew;
      case 'Ringing': return AppColors.statusRinging;
      case 'Meeting Fixed': return AppColors.statusMeetingFixed;
      case 'Negotiation': return AppColors.statusNegotiation;
      case 'Follow-up': return AppColors.statusFollowUp;
      case 'Closed-Won': return AppColors.statusClosedWon;
      case 'Lost': return AppColors.statusLost;
      default: return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = context.watch<LeadsProvider>();
    final lead = leads.getLeadById(leadId);

    if (lead == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Lead not found')),
      );
    }

    final followUps = leads.getFollowUpsForLead(leadId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _statusColor(lead.status),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _statusColor(lead.status),
                      _statusColor(lead.status).withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  lead.initials,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lead.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lead.phone,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    color: AppColors.success,
                    onTap: () => _makePhoneCall(lead.phone),
                  ),
                  const SizedBox(width: 10),
                  _ActionButton(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: AppColors.whatsapp,
                    onTap: () => context.push('/conversation/${lead.id}'),
                  ),
                  const SizedBox(width: 10),
                  _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    color: AppColors.info,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: lead.phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone number copied!')),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _ActionButton(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    color: AppColors.warning,
                    onTap: () => _sendEmail(lead.email),
                  ),
                ],
              ).animate().slideY(begin: 0.1, duration: 300.ms).fadeIn(delay: 100.ms),
            ),
          ),

          // Bridge Call (masked, recorded) — primary CTA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => showBridgeCallSheet(context, lead),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.shield_rounded, size: 18),
                  label: const Text('Bridge Call — number masked & recorded'),
                ),
              ).animate().slideY(begin: 0.1, duration: 300.ms).fadeIn(delay: 150.ms),
            ),
          ),

          // Lead Info Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _InfoCard(
                title: 'Lead Details',
                children: [
                  _InfoRow(label: 'Status', value: lead.status, valueColor: _statusColor(lead.status)),
                  if (lead.priority != null)
                    _InfoRow(label: 'Priority', value: lead.priority!),
                  if (lead.source != null)
                    _InfoRow(label: 'Source', value: lead.source!),
                  if (lead.campaign != null)
                    _InfoRow(label: 'Campaign', value: lead.campaign!),
                  if (lead.assignedToName != null)
                    _InfoRow(label: 'Assigned To', value: lead.assignedToName!),
                  if (lead.email != null)
                    _InfoRow(label: 'Email', value: lead.email!),
                  if (lead.createdAt != null)
                    _InfoRow(
                      label: 'Created',
                      value: DateFormat('MMM dd, yyyy • hh:mm a').format(lead.createdAt!),
                    ),
                ],
              ).animate().slideY(begin: 0.1, duration: 300.ms).fadeIn(delay: 200.ms),
            ),
          ),

          // Follow-ups section
          if (followUps.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Follow-ups (${followUps.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final fu = followUps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fu.isOverdue
                            ? AppColors.errorLight
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: fu.isOverdue
                              ? AppColors.error.withOpacity(0.3)
                              : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            fu.type == 'Call'
                                ? Icons.phone_rounded
                                : fu.type == 'WhatsApp'
                                    ? Icons.chat_rounded
                                    : Icons.event_rounded,
                            size: 18,
                            color: fu.isOverdue ? AppColors.error : AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fu.title ?? '${fu.type} Follow-up',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (fu.dueAt != null)
                                  Text(
                                    DateFormat('MMM dd, hh:mm a').format(fu.dueAt!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: fu.isOverdue ? AppColors.error : AppColors.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: fu.isOverdue
                                  ? AppColors.error.withOpacity(0.1)
                                  : AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              fu.isOverdue ? 'Overdue' : fu.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: fu.isOverdue ? AppColors.error : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: followUps.length,
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      // When the user returns from the dialer, re-check the CallLog so a
      // direct call gets logged against this lead automatically. (The app
      // lifecycle observer also runs catchUp on resume; this is a belt-and-
      // braces trigger for reliability.)
      CallTrackerService.instance.catchUp();
    }
  }

  Future<void> _sendEmail(String? email) async {
    if (email == null) return;
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
