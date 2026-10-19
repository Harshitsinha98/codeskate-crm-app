import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../screens/ads/meta_ads_screen.dart';
import '../../screens/ai/ai_care_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/automation/automation_screen.dart';
import '../../screens/billing/billing_screen.dart';
import '../../screens/billing/wallet_screen.dart';
import '../../screens/broadcast/broadcast_create_screen.dart';
import '../../screens/broadcast/broadcast_detail_screen.dart';
import '../../screens/broadcast/broadcast_screen.dart';
import '../../screens/calls/call_history_screen.dart';
import '../../screens/chat/employee_chat_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/followups/followups_screen.dart';
import '../../screens/home/home_shell.dart';
import '../../screens/inbox/team_inbox_screen.dart';
import '../../screens/integrations/integrations_screen.dart';
import '../../screens/leads/lead_detail_screen.dart';
import '../../screens/leads/leads_screen.dart';
import '../../screens/more/more_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/onboarding/setup_screen.dart';
import '../../screens/products/products_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/support/support_screen.dart';
import '../../screens/team/employee_detail_screen.dart';
import '../../screens/team/team_screen.dart';
import '../../screens/tickets/tickets_screen.dart';
import '../../screens/voice/voice_screen.dart';
import '../../screens/whatsapp/conversation_screen.dart';
import '../../screens/workflows/workflow_builder_screen.dart';
import '../../screens/workflows/workflows_screen.dart';

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  /// Routes only org owners/admins may open (mirrors web `role="admin"`).
  static const _adminOnly = [
    '/team',
    '/broadcasts',
    '/products',
    '/ai-care',
    '/workflows',
    '/automation',
    '/integrations',
    '/meta-ads',
    '/call-history',
  ];

  static const _publicPaths = {'/login', '/otp', '/splash'};

  static GoRouter createRouter(AuthProvider authProvider) => GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/splash',
        refreshListenable: authProvider,
        redirect: (context, state) {
          final auth = authProvider;
          final loc = state.matchedLocation;
          final loading = auth.isLoading || auth.state == AuthState.initial;
          if (loc == '/splash') return null; // splash routes itself
          if (loading) return null;

          final loggedIn = auth.isAuthenticated;
          final isPublic = _publicPaths.contains(loc);
          if (!loggedIn) return isPublic ? null : '/login';

          final needsSetup = auth.user?.needsSetup == true;
          if (needsSetup) return loc == '/setup' ? null : '/setup';
          if (loc == '/setup' || isPublic) return '/dashboard';

          final isAdmin = auth.user?.isAdmin ?? false;
          if (!isAdmin && _adminOnly.any((p) => loc == p || loc.startsWith('$p/'))) return '/dashboard';
          return null;
        },
        routes: [
          GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
          GoRoute(path: '/login', pageBuilder: (_, s) => _fade(s, const LoginScreen())),
          GoRoute(
            path: '/otp',
            pageBuilder: (_, s) => _fade(s, OtpScreen(phoneNumber: s.extra as String? ?? '')),
          ),
          GoRoute(path: '/setup', pageBuilder: (_, s) => _fade(s, const SetupScreen())),
          ShellRoute(
            navigatorKey: _shellNavigatorKey,
            builder: (context, state, child) => HomeShell(child: child),
            routes: [
              GoRoute(path: '/dashboard', pageBuilder: (_, s) => _fade(s, const DashboardScreen())),
              GoRoute(path: '/leads', pageBuilder: (_, s) => _fade(s, const LeadsScreen())),
              GoRoute(path: '/inbox', pageBuilder: (_, s) => _fade(s, const TeamInboxScreen())),
              GoRoute(path: '/followups', pageBuilder: (_, s) => _fade(s, const FollowUpsScreen())),
              GoRoute(path: '/more', pageBuilder: (_, s) => _fade(s, const MoreScreen())),
            ],
          ),
          // ── Full-screen routes ──
          GoRoute(path: '/whatsapp', redirect: (_, __) => '/inbox'),
          GoRoute(path: '/lead/:leadId', builder: (_, s) => LeadDetailScreen(leadId: s.pathParameters['leadId']!)),
          GoRoute(path: '/conversation/:leadId', builder: (_, s) => ConversationScreen(leadId: s.pathParameters['leadId']!)),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/chat', builder: (_, __) => const EmployeeChatScreen()),
          GoRoute(path: '/billing', builder: (_, __) => const BillingScreen()),
          GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
          GoRoute(path: '/call-history', builder: (_, __) => const CallHistoryScreen()),
          GoRoute(path: '/team', builder: (_, __) => const TeamScreen()),
          GoRoute(path: '/team/:uid', builder: (_, s) => EmployeeDetailScreen(uid: s.pathParameters['uid']!)),
          GoRoute(path: '/broadcasts', builder: (_, __) => const BroadcastScreen()),
          GoRoute(path: '/broadcasts/new', builder: (_, __) => const BroadcastCreateScreen()),
          GoRoute(path: '/broadcasts/:id', builder: (_, s) => BroadcastDetailScreen(broadcastId: s.pathParameters['id']!)),
          GoRoute(path: '/tickets', builder: (_, __) => const TicketsScreen()),
          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/ai-care', builder: (_, __) => const AiCareScreen()),
          GoRoute(path: '/workflows', builder: (_, __) => const WorkflowsScreen()),
          GoRoute(path: '/workflows/:id', builder: (_, s) => WorkflowBuilderScreen(workflowId: s.pathParameters['id']!)),
          GoRoute(path: '/automation', builder: (_, __) => const AutomationScreen()),
          GoRoute(path: '/integrations', builder: (_, __) => const IntegrationsScreen()),
          GoRoute(path: '/meta-ads', builder: (_, __) => const MetaAdsScreen()),
          GoRoute(path: '/voice', builder: (_, __) => const VoiceScreen()),
          GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
        ],
      );

  static CustomTransitionPage _fade(GoRouterState state, Widget child) => CustomTransitionPage(
        key: state.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      );
}
