import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../widgets/premium.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otp = TextEditingController();
  final _focus = FocusNode();
  bool _verifying = false;
  int _countdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _countdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  Future<void> _verify(String code) async {
    if (code.length != 6 || _verifying) return;
    setState(() => _verifying = true);
    final ok = await context.read<AuthProvider>().verifyOtp(code);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (!ok) {
      HapticFeedback.heavyImpact();
      _otp.clear();
      _focus.requestFocus();
    }
    // On success the router redirect moves to the dashboard.
  }

  Future<void> _resend([String? channel]) async {
    if (_countdown > 0) return;
    await context.read<AuthProvider>().resendOtp(widget.phoneNumber, channel: channel);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _channelLabel {
    switch (context.read<AuthProvider>().otpChannel) {
      case 'sms':
        return 'SMS';
      case 'voice':
        return 'a voice call';
      default:
        return 'WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pin = PinTheme(
      width: 50,
      height: 60,
      textStyle: AppText.mono(size: 22, color: Colors.white),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnight900,
        body: AuroraBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 12),
                Pressable(
                  onTap: () => context.go('/login'),
                  child: const GlassPanel(
                    padding: EdgeInsets.all(10),
                    radius: 14,
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppColors.glow(),
                  ),
                  child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 30),
                ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 26),
                Text('Enter the code', style: AppText.display(size: 32, color: Colors.white, letterSpacing: -1))
                    .animate()
                    .fadeIn(delay: 100.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(style: AppText.body(size: 14.5, color: AppColors.textOnDarkMuted, height: 1.5), children: [
                    TextSpan(text: 'We sent a 6-digit code on $_channelLabel to '),
                    TextSpan(text: '+91 ${widget.phoneNumber}', style: AppText.body(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                  ]),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 36),
                Center(
                  child: Pinput(
                    controller: _otp,
                    focusNode: _focus,
                    length: 6,
                    autofocus: true,
                    defaultPinTheme: pin,
                    focusedPinTheme: pin.copyDecorationWith(
                      border: Border.all(color: AppColors.orange400, width: 1.8),
                      boxShadow: AppColors.glow(AppColors.orange500, 0.3),
                    ),
                    submittedPinTheme: pin.copyDecorationWith(
                      color: AppColors.orange500.withValues(alpha: 0.14),
                      border: Border.all(color: AppColors.orange400.withValues(alpha: 0.6)),
                    ),
                    errorPinTheme: pin.copyDecorationWith(border: Border.all(color: AppColors.error)),
                    forceErrorState: auth.error.isNotEmpty && !_verifying,
                    onCompleted: _verify,
                    hapticFeedbackType: HapticFeedbackType.lightImpact,
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15),
                AnimatedSwitcher(
                  duration: 250.ms,
                  child: auth.error.isEmpty
                      ? const SizedBox(height: 24)
                      : Padding(
                          key: ValueKey(auth.error),
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF87171)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(auth.error, style: AppText.body(size: 13, color: const Color(0xFFFCA5A5)))),
                          ]),
                        ),
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: auth.isLoading && !_verifying ? 'Setting up your workspace…' : 'Verify & continue',
                  icon: Icons.lock_open_rounded,
                  loading: _verifying || auth.isLoading,
                  onPressed: () => _verify(_otp.text),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 22),
                Center(
                  child: _countdown > 0
                      ? Text('Resend code in ${_countdown}s', style: AppText.body(size: 13.5, color: AppColors.midnight300))
                      : Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
                          TextButton(onPressed: () => _resend(), child: Text('Resend', style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.orange300))),
                          TextButton(onPressed: () => _resend('sms'), child: Text('Try SMS', style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.orange300))),
                          TextButton(onPressed: () => _resend('voice'), child: Text('Call me', style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.orange300))),
                        ]),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
