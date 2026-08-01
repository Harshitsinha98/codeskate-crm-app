import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/home/home_shell.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/leads/leads_screen.dart';
import '../../screens/leads/lead_detail_screen.dart';
import '../../screens/whatsapp/whatsapp_screen.dart';
import '../../screens/whatsapp/conversation_screen.dart';
import '../../screens/chat/employee_chat_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/followups/followups_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthProvider authProvider) => GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final auth = authProvider;
      final isLoggedIn = auth.isAuthenticated;
      final isLoading = auth.isLoading || auth.state == AuthState.initial;
      final isOnAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/otp' ||
          state.matchedLocation == '/splash';

      // While auth state is still being determined (profile loading after
      // sign-in, or initial app start), don't redirect — let the user stay
      // on the current page until we know for sure.
      if (isLoading) return null;

      if (!isLoggedIn && !isOnAuth) return '/login';
      if (isLoggedIn && isOnAuth && state.matchedLocation != '/splash') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const DashboardScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/leads',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LeadsScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/whatsapp',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const WhatsAppScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const EmployeeChatScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const NotificationsScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/followups',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const FollowUpsScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
        ],
      ),
      // Full screen routes (outside shell)
      GoRoute(
        path: '/lead/:leadId',
        builder: (context, state) {
          final leadId = state.pathParameters['leadId']!;
          return LeadDetailScreen(leadId: leadId);
        },
      ),
      GoRoute(
        path: '/conversation/:leadId',
        builder: (context, state) {
          final leadId = state.pathParameters['leadId']!;
          return ConversationScreen(leadId: leadId);
        },
      ),
    ],
  );

  static Widget _fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}
