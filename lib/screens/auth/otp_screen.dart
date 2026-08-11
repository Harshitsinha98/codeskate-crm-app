import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinput/pinput.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isVerifying = false;
  bool _canResend = false;
  int _resendCountdown = 30;

  AuthProvider? _auth;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth ??= context.read<AuthProvider>()..addListener(_onAuthChanged);
  }

  /// Navigate automatically when auth state changes (profile loaded).
  void _onAuthChanged() {
    if (!mounted) return;
    final auth = _auth;
    if (auth == null) return;
    // The GoRouter redirect handles navigation once isAuthenticated is true.
    // We don't need to manually navigate — just let the listener fire.
    // (The router's refreshListenable is the auth provider, so it re-evaluates
    // redirect whenever auth state changes.)
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) {
        setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 6) return;

    setState(() => _isVerifying = true);
    final auth = context.read<AuthProvider>();
    await auth.verifyOtp(otp);

    if (mounted) {
      setState(() => _isVerifying = false);
      // Navigation is handled by GoRouter redirect — when auth state becomes
      // authenticated, the redirect guard sends user to /dashboard.
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    final auth = context.read<AuthProvider>();
    await auth.resendOtp(widget.phoneNumber);
    _startResendTimer();
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 56,
      textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.warmGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Back button
                IconButton(
                  onPressed: () => context.go('/login'),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 40),

                // OTP illustration
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 32),

                // Header
                Text(
                  'Verify OTP',
                  style: Theme.of(context).textTheme.displayMedium,
                ).animate().slideX(begin: -0.2, duration: 400.ms).fadeIn(delay: 100.ms),

                const SizedBox(height: 8),

                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                          height: 1.5,
                        ),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to '),
                      TextSpan(
                        text: '+91 ${widget.phoneNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 40),

                // OTP Input
                Center(
                  child: Pinput(
                    controller: _otpController,
                    focusNode: _focusNode,
                    length: 6,
                    autofocus: true,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration?.copyWith(
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    ),
                    submittedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration?.copyWith(
                        color: AppColors.surfaceVariant,
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                    ),
                    errorPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration?.copyWith(
                        border: Border.all(color: AppColors.error),
                      ),
                    ),
                    onCompleted: _verifyOtp,
                    hapticFeedbackType: HapticFeedbackType.lightImpact,
                  ),
                ).animate().slideY(begin: 0.2, duration: 400.ms).fadeIn(delay: 300.ms),

                const SizedBox(height: 16),

                // Error
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.error.isEmpty) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.error,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.error,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : () => _verifyOtp(_otpController.text),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Verify & Login'),
                  ),
                ).animate().slideY(begin: 0.2, duration: 400.ms).fadeIn(delay: 400.ms),

                const SizedBox(height: 24),

                // Resend
                Center(
                  child: _canResend
                      ? TextButton(
                          onPressed: _resendOtp,
                          child: Text(
                            'Resend OTP',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Text(
                          'Resend in ${_resendCountdown}s',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
