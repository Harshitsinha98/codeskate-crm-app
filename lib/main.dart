import 'dart:async';
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
import 'providers/billing_provider.dart';
import 'services/call_tracker_service.dart';

void main() {
  // Surface any build/runtime error ON SCREEN (red text) instead of a blank
  // white screen, so problems are diagnosable on-device without a debugger.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: Text(
              'APP ERROR:\n\n${details.exceptionAsString()}\n\n${details.stack}',
              style: const TextStyle(color: Colors.red, fontSize: 12, height: 1.4),
            ),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Firebase init (guard against duplicate-app).
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e, st) {
      runApp(_StartupError(message: 'Firebase init failed:\n\n$e\n\n$st'));
      return;
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(const CodeskateApp());
  }, (error, stack) {
    // Any uncaught async error → show it on screen.
    runApp(_StartupError(message: 'Uncaught error:\n\n$error\n\n$stack'));
  });
}

/// Full-screen readable error display (used when startup fails).
class _StartupError extends StatelessWidget {
  final String message;
  const _StartupError({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Text(
                message,
                style: const TextStyle(color: Colors.red, fontSize: 13, height: 1.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        ChangeNotifierProxyProvider<AuthProvider, BillingProvider>(
          create: (_) => BillingProvider(),
          update: (_, auth, billing) => billing!..updateAuth(auth),
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
      CallTrackerService.instance.start();
    } else if (_configured || CallTrackerService.instance.isRunning) {
      CallTrackerService.instance.stop();
      _configured = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTracker();
    });
    return widget.child;
  }
}
