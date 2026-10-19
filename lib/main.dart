import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/billing_provider.dart';
import 'providers/bridge_call_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/inbox_provider.dart';
import 'providers/leads_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/team_provider.dart';
import 'services/call_tracker_service.dart';
import 'services/push_service.dart';

void main() {
  // Friendly in-place error card (full stack only in debug builds) instead of
  // a blank screen if a single widget fails to build.
  ErrorWidget.builder = (details) => Material(
        color: AppColors.cream100,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              kDebugMode ? details.exceptionAsString() : 'Something went wrong showing this section.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ),
      );

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      // Android's google-services plugin may have created [DEFAULT] already.
      if (e.code != 'duplicate-app') {
        runApp(_StartupError(message: 'Could not start Firebase:\n$e'));
        return;
      }
    } catch (e) {
      runApp(_StartupError(message: 'Could not start Firebase:\n$e'));
      return;
    }

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.cream100,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    await PushService.instance.init();
    runApp(const CodeskateApp());
  }, (error, stack) {
    // Log only — never tear down the running UI for a background error.
    debugPrint('Uncaught error: $error\n$stack');
  });
}

class _StartupError extends StatelessWidget {
  final String message;
  const _StartupError({required this.message});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.midnight900,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.5)),
            ),
          ),
        ),
      );
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
    PushService.instance.onNavigate = (route) {
      if (_authProvider.isAuthenticated) _router.push(route);
    };
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
        ChangeNotifierProxyProvider<AuthProvider, InboxProvider>(
          create: (_) => InboxProvider(),
          update: (_, auth, inbox) => inbox!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, BillingProvider>(
          create: (_) => BillingProvider(),
          update: (_, auth, billing) => billing!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, BridgeCallProvider>(
          create: (_) => BridgeCallProvider(),
          update: (_, auth, bridge) => bridge!..updateAuth(auth),
        ),
      ],
      child: _SessionBinder(
        child: MaterialApp.router(
          title: 'Codeskate CRM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: _router,
          builder: (context, child) => MediaQuery(
            // Keep the premium layout intact under very large system fonts.
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
            ),
            child: child!,
          ),
        ),
      ),
    );
  }
}

/// Binds session-scoped services (native call tracker, push registration)
/// to auth state and app lifecycle.
class _SessionBinder extends StatefulWidget {
  final Widget child;
  const _SessionBinder({required this.child});

  @override
  State<_SessionBinder> createState() => _SessionBinderState();
}

class _SessionBinderState extends State<_SessionBinder> with WidgetsBindingObserver {
  bool _trackerConfigured = false;
  String? _sessionKey;

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
    if (state == AppLifecycleState.resumed) CallTrackerService.instance.catchUp();
  }

  void _sync() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final signedIn = auth.isAuthenticated && user?.activeOrgId != null && user?.needsSetup != true;
    final key = signedIn ? '${user!.uid}:${user.activeOrgId}' : null;
    if (key == _sessionKey) return;
    _sessionKey = key;

    if (signedIn) {
      if (!_trackerConfigured) {
        CallTrackerService.instance.configure(
          getOrgId: () => context.read<AuthProvider>().user?.activeOrgId,
          getUid: () => context.read<AuthProvider>().user?.uid,
          getUserName: () => context.read<AuthProvider>().user?.displayName ?? 'Employee',
          getRole: () => context.read<AuthProvider>().user?.activeOrgRole,
          getLeads: () => context.read<LeadsProvider>().leads,
        );
        _trackerConfigured = true;
      }
      CallTrackerService.instance.start();
      PushService.instance.registerFor(uid: user!.uid, orgId: user.activeOrgId);
    } else {
      if (_trackerConfigured || CallTrackerService.instance.isRunning) {
        CallTrackerService.instance.stop();
        _trackerConfigured = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
    return widget.child;
  }
}
