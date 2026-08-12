import 'package:flutter/material.dart';

/// Codeskate CRM — modern SaaS palette.
/// Crisp cool-neutral surfaces with a confident orange brand accent.
class AppColors {
  AppColors._();

  // Primary — Brand Orange (crisp, modern)
  static const Color primary = Color(0xFFF15A22);
  static const Color primaryLight = Color(0xFFFF8149);
  static const Color primaryDark = Color(0xFFC2410C);

  // Secondary — Indigo/Slate accent (for variety in charts/badges)
  static const Color secondary = Color(0xFF6366F1);
  static const Color secondaryLight = Color(0xFF818CF8);
  static const Color secondaryDark = Color(0xFF4338CA);

  // Backgrounds — cool, clean neutrals (SaaS)
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F4F8);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text — slate scale
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Lead status
  static const Color statusNew = Color(0xFF3B82F6);
  static const Color statusRinging = Color(0xFFF59E0B);
  static const Color statusMeetingFixed = Color(0xFF10B981);
  static const Color statusNegotiation = Color(0xFF8B5CF6);
  static const Color statusFollowUp = Color(0xFFEAB308);
  static const Color statusClosedWon = Color(0xFF16A34A);
  static const Color statusLost = Color(0xFFEF4444);

  // WhatsApp
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF128C7E);
  static const Color whatsappBubbleSent = Color(0xFFDCF8C6);
  static const Color whatsappBubbleReceived = Color(0xFFFFFFFF);

  // Misc — subtle, neutral
  static const Color divider = Color(0xFFE9EDF3);
  static const Color border = Color(0xFFE2E8F0);
  static const Color shimmerBase = Color(0xFFEEF1F5);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);
  static const Color shadow = Color(0x14101828);
  static const Color overlay = Color(0x4D0F172A);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF15A22), Color(0xFFFF8149)],
  );

  // Clean, subtle app background gradient (login/splash/hero backdrops).
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F4F8)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
  );
}
