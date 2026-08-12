import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/lead_model.dart';
import '../../providers/bridge_call_provider.dart';
import '../../services/call_tracker_service.dart';
import 'bridge_call_sheet.dart';

/// Tapping "Call" opens this chooser: Direct call always; Bridge call only when
/// the backend confirms it's available (Growth+ plan, active number, wallet).
Future<void> showCallOptionsSheet(BuildContext context, LeadModel lead) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CallOptionsSheet(lead: lead),
  );
}

class _CallOptionsSheet extends StatefulWidget {
  final LeadModel lead;
  const _CallOptionsSheet({required this.lead});

  @override
  State<_CallOptionsSheet> createState() => _CallOptionsSheetState();
}

class _CallOptionsSheetState extends State<_CallOptionsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BridgeCallProvider>().checkAvailability();
    });
  }

  Future<void> _directCall() async {
    Navigator.of(context).pop();
    final uri = Uri.parse('tel:${widget.lead.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      CallTrackerService.instance.catchUp();
    }
  }

  void _bridgeCall() {
    Navigator.of(context).pop();
    showBridgeCallSheet(context, widget.lead);
  }

  @override
  Widget build(BuildContext context) {
    final bridge = context.watch<BridgeCallProvider>();
    final showBridge = bridge.bridgeAvailable;
    final checking = !bridge.availabilityChecked;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.overlay.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Lead header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(widget.lead.initials,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.lead.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(widget.lead.phone,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bridge call (only when available)
            if (showBridge)
              _CallOption(
                icon: Icons.shield_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primary.withOpacity(0.1),
                title: 'Bridge Call',
                subtitle: 'Your number stays private · recorded',
                badge: 'Recommended',
                onTap: _bridgeCall,
              ),

            // Direct call (always)
            _CallOption(
              icon: Icons.phone_rounded,
              iconColor: AppColors.success,
              iconBg: AppColors.success.withOpacity(0.1),
              title: 'Direct Call',
              subtitle: 'Call from your phone · auto-logged',
              onTap: _directCall,
            ),

            // While checking, hint that bridge may appear.
            if (checking)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    ),
                    const SizedBox(width: 8),
                    Text('Checking for masked calling…',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textTertiary)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _CallOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _CallOption({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(badge!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
