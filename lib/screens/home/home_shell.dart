import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/inbox_provider.dart';
import '../../providers/leads_provider.dart';

/// Root shell with a floating frosted-glass tab bar and a sliding gradient
/// indicator. Call tracking + push are bound in main.dart.
class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    _Tab('/dashboard', 'Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
    _Tab('/leads', 'Leads', Icons.people_alt_outlined, Icons.people_alt_rounded),
    _Tab('/inbox', 'Inbox', Icons.forum_outlined, Icons.forum_rounded),
    _Tab('/followups', 'Tasks', Icons.event_note_outlined, Icons.event_note_rounded),
    _Tab('/more', 'More', Icons.grid_view_outlined, Icons.grid_view_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexWhere((t) => loc.startsWith(t.path)).clamp(0, _tabs.length - 1);
    final unread = context.select<InboxProvider, int>((p) => p.totalUnread);
    final overdue = context.select<LeadsProvider, int>((p) => p.overdueFollowUps);

    return Scaffold(
      backgroundColor: AppColors.background,
      // Body ends above the floating bar so every tab's list stays fully
      // scrollable without per-screen bottom padding.
      extendBody: false,
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.midnight900.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(color: AppColors.midnight900.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth / _tabs.length;
                return Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    left: w * index + (w - 52) / 2,
                    top: 9,
                    child: Container(
                      width: 52,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppColors.glow(AppColors.orange500, 0.45),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_tabs.length, (i) {
                      final t = _tabs[i];
                      final active = i == index;
                      final badge = i == 2 ? unread : (i == 3 ? overdue : 0);
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (active) return;
                            HapticFeedback.selectionClick();
                            context.go(t.path);
                          },
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(
                              height: 32,
                              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                                AnimatedSwitcher(
                                  duration: 200.ms,
                                  child: Icon(active ? t.activeIcon : t.icon,
                                      key: ValueKey(active), size: 21, color: active ? Colors.white : AppColors.midnight300),
                                ),
                                if (badge > 0)
                                  Positioned(
                                    top: 1,
                                    right: -12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      constraints: const BoxConstraints(minWidth: 17),
                                      decoration: BoxDecoration(
                                        color: i == 3 ? AppColors.error : AppColors.whatsapp,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(color: AppColors.midnight900, width: 1.5),
                                      ),
                                      child: Text(badge > 99 ? '99+' : '$badge',
                                          textAlign: TextAlign.center,
                                          style: AppText.body(size: 9.5, weight: FontWeight.w800, color: Colors.white, height: 1.2)),
                                    ).animate(key: ValueKey(badge)).scale(duration: 300.ms, curve: Curves.elasticOut),
                                  ),
                              ]),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: 200.ms,
                              style: AppText.body(
                                size: 10.5,
                                weight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? Colors.white : AppColors.midnight300,
                              ),
                              child: Text(t.label),
                            ),
                          ]),
                        ),
                      );
                    }),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _Tab(this.path, this.label, this.icon, this.activeIcon);
}
