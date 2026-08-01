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
      body: widget.child,
      bottomNavigationBar: Consumer<NotificationsProvider>(
        builder: (context, notifs, _) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Home',
                      isSelected: _currentIndex == 0,
                      onTap: () => _onTabTapped(0),
                    ),
                    _NavItem(
                      icon: Icons.people_alt_rounded,
                      label: 'Leads',
                      isSelected: _currentIndex == 1,
                      onTap: () => _onTabTapped(1),
                    ),
                    _NavItem(
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      isSelected: _currentIndex == 2,
                      onTap: () => _onTabTapped(2),
                      badge: null,
                    ),
                    _NavItem(
                      icon: Icons.event_note_rounded,
                      label: 'Follow-ups',
                      isSelected: _currentIndex == 3,
                      onTap: () => _onTabTapped(3),
                      badge: notifs.unreadCount > 0 ? notifs.unreadCount.toString() : null,
                    ),
                    _NavItem(
                      icon: Icons.settings_rounded,
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
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? AppColors.primary : AppColors.textTertiary,
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
