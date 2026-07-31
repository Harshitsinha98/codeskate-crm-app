import 'package:flutter/material.dart';

/// Codeskate CRM Brand Colors
/// Warm beige/orange palette for a professional yet inviting feel.
class AppColors {
  AppColors._();

  // Primary - Warm Orange
  static const Color primary = Color(0xFFE8652B);
  static const Color primaryLight = Color(0xFFFF8A50);
  static const Color primaryDark = Color(0xFFC24A1A);

  // Secondary - Deep Brown/Amber
  static const Color secondary = Color(0xFF8B5E34);
  static const Color secondaryLight = Color(0xFFBD8C60);
  static const Color secondaryDark = Color(0xFF5D3512);

  // Background - Warm Beige tones
  static const Color background = Color(0xFFFFF8F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFFF0E5);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF2D1B0E);
  static const Color textSecondary = Color(0xFF6B5344);
  static const Color textTertiary = Color(0xFF9C8678);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFFA726);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Lead Status Colors
  static const Color statusNew = Color(0xFF42A5F5);
  static const Color statusRinging = Color(0xFFFFA726);
  static const Color statusMeetingFixed = Color(0xFF66BB6A);
  static const Color statusNegotiation = Color(0xFFAB47BC);
  static const Color statusFollowUp = Color(0xFFFFCA28);
  static const Color statusClosedWon = Color(0xFF4CAF50);
  static const Color statusLost = Color(0xFFEF5350);

  // WhatsApp Green
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF128C7E);
  static const Color whatsappBubbleSent = Color(0xFFDCF8C6);
  static const Color whatsappBubbleReceived = Color(0xFFFFFFFF);

  // Misc
  static const Color divider = Color(0xFFE8DDD4);
  static const Color shimmerBase = Color(0xFFE8E0D8);
  static const Color shimmerHighlight = Color(0xFFF5EDE5);
  static const Color shadow = Color(0x1A000000);
  static const Color overlay = Color(0x33000000);

  // Gradient for headers/hero sections
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF8F2), Color(0xFFFFEEDD)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F2)],
  );
}
