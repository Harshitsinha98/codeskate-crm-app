import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'premium.dart';

/// Org switcher for users in multiple workspaces.
Future<void> showOrgSwitcher(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final user = auth.user;
  if (user == null) return;
  final orgIds = user.memberships.map((m) => m.orgId).toList();
  final names = <String, String>{};
  try {
    for (final id in orgIds) {
      final d = await FirebaseFirestore.instance.collection('organizations').doc(id).get();
      names[id] = (d.data()?['name'] ?? 'Workspace').toString();
    }
  } catch (_) {}
  if (!context.mounted) return;
  await showPremiumSheet(
    context,
    title: 'Switch workspace',
    subtitle: 'You are a member of ${orgIds.length} workspace${orgIds.length == 1 ? '' : 's'}',
    builder: (ctx) => Column(
      children: user.memberships.map((m) {
        final active = m.orgId == user.activeOrgId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PremiumCard(
            padding: EdgeInsets.zero,
            borderColor: active ? AppColors.primary : null,
            onTap: active
                ? null
                : () async {
                    Navigator.pop(ctx);
                    final ok = await auth.switchOrg(m.orgId);
                    if (context.mounted && ok) AppToast.success(context, 'Switched to ${names[m.orgId] ?? 'workspace'}');
                  },
            child: PremiumTile(
              icon: Icons.apartment_rounded,
              title: names[m.orgId] ?? m.orgId,
              subtitle: m.role[0].toUpperCase() + m.role.substring(1),
              gradientIcon: active,
              trailing: active ? const Pill(label: 'Active', color: AppColors.success) : null,
            ),
          ),
        );
      }).toList(),
    ),
  );
}

/// Small helper: section card with title.
class TitledCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  const TitledCard({super.key, required this.title, required this.child, this.trailing, this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14)});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: margin,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: AppText.display(size: 15.5, weight: FontWeight.w700, letterSpacing: -0.2))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

String relTime(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}';
}

String inr(num v) {
  final s = v.round().toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}
