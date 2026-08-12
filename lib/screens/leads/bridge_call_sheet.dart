import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/lead_model.dart';
import '../../providers/bridge_call_provider.dart';

/// Shows the live bridge-call status sheet for [lead].
Future<void> showBridgeCallSheet(BuildContext context, LeadModel lead) {
  return showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BridgeCallSheet(lead: lead),
  );
}

class _BridgeCallSheet extends StatefulWidget {
  final LeadModel lead;
  const _BridgeCallSheet({required this.lead});

  @override
  State<_BridgeCallSheet> createState() => _BridgeCallSheetState();
}

class _BridgeCallSheetState extends State<_BridgeCallSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BridgeCallProvider>().start(widget.lead);
    });
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Future<void> _directDial() async {
    final uri = Uri.parse('tel:${widget.lead.phone}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
    if (mounted) Navigator.of(context).pop();
  }

  void _close() {
    context.read<BridgeCallProvider>().reset();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BridgeCallProvider>();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Lead identity
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                widget.lead.initials,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.lead.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Bridge call · number masked',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 24),

            _buildBody(b),

            const SizedBox(height: 24),
            _buildActions(b),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BridgeCallProvider b) {
    switch (b.phase) {
      case BridgePhase.initiating:
        return _statusBlock(
          icon: Icons.sync_rounded,
          color: AppColors.info,
          title: 'Starting call…',
          subtitle: 'Setting up your masked line.',
          spinning: true,
        );
      case BridgePhase.ringing:
        return _statusBlock(
          icon: Icons.phone_in_talk_rounded,
          color: AppColors.primary,
          title: 'Your phone is ringing',
          subtitle: 'Pick up and press 1 to connect to the customer.',
          spinning: true,
        );
      case BridgePhase.waitingCustomer:
        return _statusBlock(
          icon: Icons.ring_volume_rounded,
          color: AppColors.warning,
          title: 'Connecting customer…',
          subtitle: 'Calling ${widget.lead.name}. Please hold.',
          spinning: true,
        );
      case BridgePhase.inProgress:
        return _statusBlock(
          icon: Icons.graphic_eq_rounded,
          color: AppColors.success,
          title: 'Connected',
          subtitle: _fmt(b.elapsed),
          spinning: false,
        );
      case BridgePhase.completed:
        final r = b.result;
        return Column(
          children: [
            _statusBlock(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              title: 'Call completed',
              subtitle: r != null ? 'Duration ${_fmt(r.customerSeconds)}' : '',
              spinning: false,
            ),
            if (r != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric('Talk time', _fmt(r.customerSeconds)),
                    _metric('Billed', '${r.billedMinutes} min'),
                    _metric('Cost', '₹${r.costInr.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ],
          ],
        );
      case BridgePhase.failed:
        return _statusBlock(
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          title: 'Call not connected',
          subtitle: b.error,
          spinning: false,
        );
      case BridgePhase.idle:
        return const SizedBox(height: 40);
    }
  }

  Widget _statusBlock({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool spinning,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (spinning)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(color.withOpacity(0.5)),
                  ),
                ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        ],
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _buildActions(BridgeCallProvider b) {
    // Terminal states → Close (+ retry/direct-dial on failure).
    if (b.phase == BridgePhase.completed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _close,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Done'),
        ),
      );
    }

    if (b.phase == BridgePhase.failed) {
      final canFallback = b.errorCode == null; // unknown/network error
      return Column(
        children: [
          if (canFallback)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _directDial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Call directly instead'),
              ),
            ),
          if (canFallback) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _close,
              child: Text('Close',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      );
    }

    // Active call → allow cancel/hang up (closes sheet; backend ends on hangup).
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _close,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.call_end_rounded, size: 18),
        label: const Text('Hide'),
      ),
    );
  }
}
