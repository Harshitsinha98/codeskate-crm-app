import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leads_provider.dart';
import '../../services/call_tracker_service.dart';

class HomeShell extends StatefulWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _callTrackerStarted = false;

  @override
  void initState() {
    super.initState();
    // Start native call tracking once we're logged in (Android only, no-op
    // elsewhere). Reads latest auth/leads via provider callbacks at event time.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCallTracker());
  }

  void _initCallTracker() {
    if (_callTrackerStarted) return;
    final auth = context.read<AuthProvider>();
    if (auth.user?.activeOrgId == null) return;
    final leads = context.read<LeadsProvider>();
    CallTrackerService.instance.configure(
      getOrgId: () => auth.user?.activeOrgId,
      getUid: () => auth.user?.uid,
      getUserName: () => auth.user?.name ?? 'Employee',
      getRole: () => auth.user?.activeOrgRole,
      getLeads: () => leads.leads,
    );
    CallTrackerService.instance.start();
    _callTrackerStarted = true;
  }

  @override
  void dispose() {
    CallTrackerService.instance.stop();
    super.dispose();
  }

  static const _routes = [
    '/dashboard',
    '/leads',
    '/whatsapp',
    '/followups',
    '/settings',
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync bottom nav with current route
    final location = GoRouterState.of(context).matchedLocation;
    final index = _routes.indexOf(location);
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.child,
      bottomNavigationBar: Consumer<NotificationsProvider>(
        builder: (context, notifs, _) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.space_dashboard_outlined,
                      activeIcon: Icons.space_dashboard_rounded,
                      label: 'Home',
                      isSelected: _currentIndex == 0,
                      onTap: () => _onTabTapped(0),
                    ),
                    _NavItem(
                      icon: Icons.people_alt_outlined,
                      activeIcon: Icons.people_alt_rounded,
                      label: 'Leads',
                      isSelected: _currentIndex == 1,
                      onTap: () => _onTabTapped(1),
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Chats',
                      isSelected: _currentIndex == 2,
                      onTap: () => _onTabTapped(2),
                    ),
                    _NavItem(
                      icon: Icons.event_note_outlined,
                      activeIcon: Icons.event_note_rounded,
                      label: 'Tasks',
                      isSelected: _currentIndex == 3,
                      onTap: () => _onTabTapped(3),
                      badge: notifs.unreadCount > 0
                          ? notifs.unreadCount.toString()
                          : null,
                    ),
                    _NavItem(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
                      label: 'Settings',
                      isSelected: _currentIndex == 4,
                      onTap: () => _onTabTapped(4),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textTertiary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Soft pill behind the active icon.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isSelected ? activeIcon : icon, size: 21, color: color),
                  if (badge != null)
                    Positioned(
                      right: -7,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 15),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: AppColors.surface, width: 1.2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
