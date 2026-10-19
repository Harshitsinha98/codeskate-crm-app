import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'widgets/premium.dart';

/// Animated brand intro: aurora → mark springs in → wordmark reveals →
/// routes as soon as auth is resolved (min 1.6s for the animation).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _minElapsed = false;
  bool _routed = false;
  AuthProvider? _auth;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1700), () {
      _minElapsed = true;
      _tryRoute();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth == null) {
      _auth = context.read<AuthProvider>();
      _auth!.addListener(_tryRoute);
    }
  }

  void _tryRoute() {
    if (!mounted || _routed || !_minElapsed) return;
    final auth = _auth!;
    if (auth.state == AuthState.initial || auth.state == AuthState.loading) return;
    _routed = true;
    if (auth.isAuthenticated) {
      context.go(auth.user?.needsSetup == true ? '/setup' : '/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_tryRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnight900,
        body: AuroraBackground(
          intensity: 1.2,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const BrandMark(size: 92)
                  .animate()
                  .scale(begin: const Offset(0.4, 0.4), duration: 900.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 300.ms)
                  .then(delay: 200.ms)
                  .shimmer(duration: 1400.ms, color: Colors.white.withValues(alpha: 0.35)),
              const SizedBox(height: 26),
              Text('codeskate', style: AppText.display(size: 34, color: Colors.white, letterSpacing: -1.2))
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 500.ms)
                  .slideY(begin: 0.4, curve: Curves.easeOutCubic),
              const SizedBox(height: 6),
              Text('SALES · WHATSAPP · ADS', style: AppText.mono(size: 11.5, color: AppColors.orange300, weight: FontWeight.w600).copyWith(letterSpacing: 3))
                  .animate()
                  .fadeIn(delay: 650.ms, duration: 500.ms),
              const SizedBox(height: 48),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(AppColors.orange500),
                  ),
                ),
              ).animate().fadeIn(delay: 900.ms),
            ]),
          ),
        ),
      ),
    );
  }
}
