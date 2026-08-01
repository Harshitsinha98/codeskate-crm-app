import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/leads_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/team_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'services/call_tracker_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set system UI overlay style for warm brand feel
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CodeskateApp());
}

class CodeskateApp extends StatefulWidget {
  const CodeskateApp({super.key});

  @override
  State<CodeskateApp> createState() => _CodeskateAppState();
}

class _CodeskateAppState extends State<CodeskateApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _router = AppRouter.createRouter(_authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProxyProvider<AuthProvider, LeadsProvider>(
          create: (_) => LeadsProvider(),
          update: (_, auth, leads) => leads!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationsProvider>(
          create: (_) => NotificationsProvider(),
          update: (_, auth, notifs) => notifs!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TeamProvider>(
          create: (_) => TeamProvider(),
          update: (_, auth, team) => team!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SettingsProvider>(
          create: (_) => SettingsProvider(),
          update: (_, auth, settings) => settings!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) => chat!..updateAuth(auth),
        ),
      ],
      child: _CallTrackerBinder(
        child: MaterialApp.router(
          title: 'Codeskate CRM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: _router,
        ),
      ),
    );
  }
}

/// Wires the native Android call tracker to the app lifecycle and auth state.
///
/// - When a user is authenticated (org resolved), it configures the
///   [CallTrackerService] with live getters and starts listening.
/// - When the user signs out, it stops the tracker.
/// - On app resume, it runs a catch-up check so a call that ended while the
///   app was backgrounded is still logged to the matching lead.
///
/// The service itself is a no-op on non-Android platforms, so this is safe to
/// mount unconditionally.
class _CallTrackerBinder extends StatefulWidget {
  final Widget child;

  const _CallTrackerBinder({required this.child});

  @override
  State<_CallTrackerBinder> createState() => _CallTrackerBinderState();
}

class _CallTrackerBinderState extends State<_CallTrackerBinder>
    with WidgetsBindingObserver {
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A call may have started/ended while the app was in the background.
    // Re-check the CallLog when we come back to the foreground.
    if (state == AppLifecycleState.resumed) {
      CallTrackerService.instance.catchUp();
    }
  }

  void _syncTracker() {
    final auth = context.read<AuthProvider>();
    final signedIn = auth.isAuthenticated && auth.user?.activeOrgId != null;

    if (signedIn) {
      if (!_configured) {
        CallTrackerService.instance.configure(
          getOrgId: () => context.read<AuthProvider>().user?.activeOrgId,
          getUid: () => context.read<AuthProvider>().user?.uid,
          getUserName: () =>
              context.read<AuthProvider>().user?.displayName ?? 'Employee',
          getRole: () => context.read<AuthProvider>().user?.activeOrgRole,
          getLeads: () => context.read<LeadsProvider>().leads,
        );
        _configured = true;
      }
      // start() is idempotent (returns early if already running).
      CallTrackerService.instance.start();
    } else if (_configured || CallTrackerService.instance.isRunning) {
      CallTrackerService.instance.stop();
      _configured = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever auth state changes so we react to login/logout.
    context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTracker();
    });
    return widget.child;
  }
}
