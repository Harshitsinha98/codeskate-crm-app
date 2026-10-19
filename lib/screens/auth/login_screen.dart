import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../widgets/premium.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  String? _localError;

  @override
  void dispose() {
    _phone.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp([String? channel]) async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      setState(() => _localError = 'Enter your 10-digit mobile number');
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() {
      _loading = true;
      _localError = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(digits, channel: channel);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok || auth.state == AuthState.otpSent) context.go('/otp', extra: digits);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final err = _localError ?? (auth.error.isEmpty ? null : auth.error);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnight900,
        body: AuroraBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 36),
                        Row(children: [
                          const BrandMark(size: 46),
                          const SizedBox(width: 12),
                          Text('codeskate', style: AppText.display(size: 22, color: Colors.white, weight: FontWeight.w700)),
                          const Spacer(),
                          const Pill(label: 'CRM', color: AppColors.orange300),
                        ]).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
                        const Spacer(),
                        Text('Close more deals.\nFrom anywhere.',
                                style: AppText.display(size: 38, color: Colors.white, weight: FontWeight.w700, letterSpacing: -1.2))
                            .animate()
                            .fadeIn(delay: 120.ms, duration: 600.ms)
                            .slideY(begin: 0.25, curve: Curves.easeOutCubic),
                        const SizedBox(height: 14),
                        Text(
                          'Leads, WhatsApp inbox, Meta ads, calls and follow-ups — your whole sales floor in your pocket.',
                          style: AppText.body(size: 15, color: AppColors.textOnDarkMuted, height: 1.5),
                        ).animate().fadeIn(delay: 260.ms, duration: 600.ms),
                        const SizedBox(height: 22),
                        Wrap(spacing: 8, runSpacing: 8, children: const [
                          _Feature(icon: Icons.bolt_rounded, label: 'Instant lead alerts'),
                          _Feature(icon: Icons.forum_rounded, label: 'Shared WhatsApp inbox'),
                          _Feature(icon: Icons.campaign_rounded, label: 'Meta ads'),
                        ]).animate().fadeIn(delay: 380.ms, duration: 600.ms),
                        const SizedBox(height: 30),
                        GlassPanel(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          radius: 26,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Sign in with your mobile', style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textOnDarkMuted)),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: err != null ? AppColors.error : Colors.white.withValues(alpha: 0.14)),
                              ),
                              child: Row(children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text('🇮🇳  +91', style: AppText.mono(size: 16, color: Colors.white)),
                                ),
                                Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.14)),
                                Expanded(
                                  child: TextField(
                                    controller: _phone,
                                    focusNode: _focus,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    cursorColor: AppColors.orange400,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: AppText.mono(size: 18, color: Colors.white).copyWith(letterSpacing: 2),
                                    onChanged: (_) {
                                      if (_localError != null) setState(() => _localError = null);
                                      if (auth.error.isNotEmpty) auth.clearError();
                                    },
                                    onSubmitted: (_) => _sendOtp(),
                                    decoration: InputDecoration(
                                      hintText: '98765 43210',
                                      hintStyle: AppText.mono(size: 18, color: Colors.white24),
                                      counterText: '',
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                            AnimatedSwitcher(
                              duration: 250.ms,
                              child: err == null
                                  ? const SizedBox(height: 14)
                                  : Padding(
                                      key: ValueKey(err),
                                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                                      child: Row(children: [
                                        const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF87171)),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(err, style: AppText.body(size: 12.5, color: const Color(0xFFFCA5A5)))),
                                      ]),
                                    ).animate().shakeX(hz: 4, amount: 3, duration: 350.ms),
                            ),
                            const SizedBox(height: 4),
                            GlowButton(
                              label: 'Get OTP on WhatsApp',
                              icon: Icons.arrow_forward_rounded,
                              loading: _loading,
                              onPressed: auth.isRateLimited ? null : () => _sendOtp(),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: _loading || auth.isRateLimited ? null : () => _sendOtp('sms'),
                                child: Text('Send via SMS instead', style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.orange300)),
                              ),
                            ),
                          ]),
                        ).animate().fadeIn(delay: 480.ms, duration: 600.ms).slideY(begin: 0.15, curve: Curves.easeOutCubic),
                        const SizedBox(height: 18),
                        Center(
                          child: Text('By continuing you agree to the Codeskate Terms & Privacy Policy',
                              textAlign: TextAlign.center, style: AppText.body(size: 11.5, color: AppColors.midnight300)),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.orange400),
          const SizedBox(width: 6),
          Text(label, style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.textOnDark)),
        ]),
      );
}
