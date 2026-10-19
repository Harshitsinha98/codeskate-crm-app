import 'package:flutter/material.dart';

/// Codeskate brand palette — mirrors the web CRM's tailwind tokens
/// (SNS-ADS-ERP/lead-erp/tailwind.config.js): Orange · Ember · Cream ·
/// Midnight · Ink.
class AppColors {
  AppColors._();

  // ── Brand: Orange (primary) ────────────────────────────────────────────
  static const Color orange50 = Color(0xFFFFF5ED);
  static const Color orange100 = Color(0xFFFFE8D4);
  static const Color orange200 = Color(0xFFFFCEA8);
  static const Color orange300 = Color(0xFFFFAC70);
  static const Color orange400 = Color(0xFFFF8A3D);
  static const Color orange500 = Color(0xFFFF6B1A);
  static const Color orange600 = Color(0xFFF04E00);
  static const Color orange700 = Color(0xFFC73C05);

  // ── Brand: Ember (deep warm accent) ────────────────────────────────────
  static const Color ember300 = Color(0xFFE89B78);
  static const Color ember400 = Color(0xFFDB6E44);
  static const Color ember500 = Color(0xFFC74E24);
  static const Color ember600 = Color(0xFFA63A18);
  static const Color ember700 = Color(0xFF822C14);

  // ── Brand: Cream (warm canvas) ─────────────────────────────────────────
  static const Color cream50 = Color(0xFFFFFDF9);
  static const Color cream100 = Color(0xFFFDF8F0);
  static const Color cream200 = Color(0xFFFBF0E1);
  static const Color cream300 = Color(0xFFF6E6CF);

  // ── Brand: Midnight (dark hero surfaces) ───────────────────────────────
  static const Color midnight950 = Color(0xFF080606);
  static const Color midnight900 = Color(0xFF0F0C0A);
  static const Color midnight800 = Color(0xFF171310);
  static const Color midnight700 = Color(0xFF231D18);
  static const Color midnight600 = Color(0xFF332C25);
  static const Color midnight500 = Color(0xFF4A4239);
  static const Color midnight300 = Color(0xFFA49C94);

  // ── Semantic aliases used across the app ───────────────────────────────
  static const Color primary = orange500;
  static const Color primaryLight = orange400;
  static const Color primaryDark = orange600;

  static const Color secondary = ember500;
  static const Color secondaryLight = ember400;
  static const Color secondaryDark = ember700;

  static const Color background = cream100;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF7EFE5);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Ink text scale
  static const Color textPrimary = Color(0xFF2A211A);
  static const Color textSecondary = Color(0xFF4A3D31);
  static const Color textTertiary = Color(0xFF8C7B69);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF7F6F5);
  static const Color textOnDarkMuted = Color(0xFFA49C94);

  // Status
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFEA580C);
  static const Color warningLight = Color(0xFFFFEDD5);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color signal = Color(0xFF9333EA);
  static const Color signalLight = Color(0xFFF3E8FF);

  // Lead status
  static const Color statusNew = Color(0xFF2563EB);
  static const Color statusRinging = Color(0xFFF59E0B);
  static const Color statusMeetingFixed = Color(0xFF0D9488);
  static const Color statusNegotiation = Color(0xFF9333EA);
  static const Color statusFollowUp = Color(0xFFEA580C);
  static const Color statusClosedWon = Color(0xFF059669);
  static const Color statusLost = Color(0xFFDC2626);

  static Color forStatus(String status) {
    switch (status) {
      case 'New':
        return statusNew;
      case 'Ringing':
        return statusRinging;
      case 'Meeting Fixed':
        return statusMeetingFixed;
      case 'Negotiation':
        return statusNegotiation;
      case 'Follow-up':
        return statusFollowUp;
      case 'Closed-Won':
        return statusClosedWon;
      case 'Lost':
        return statusLost;
      default:
        // Stable colour for custom org statuses.
        const palette = [ember500, info, signal, Color(0xFF0D9488), orange600];
        return palette[status.hashCode.abs() % palette.length];
    }
  }

  // WhatsApp / Meta
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF128C7E);
  static const Color whatsappBubbleSent = Color(0xFFFFE8D4);
  static const Color whatsappBubbleReceived = Color(0xFFFFFFFF);
  static const Color meta = Color(0xFF0866FF);

  // Lines & effects
  static const Color divider = Color(0xFFECE3D7);
  static const Color border = Color(0xFFEADFD2);
  static const Color shimmerBase = Color(0xFFF3EADF);
  static const Color shimmerHighlight = Color(0xFFFFFBF6);
  static const Color shadow = Color(0x14784F28);
  static const Color overlay = Color(0x660F0C0A);

  // ── Gradients ──────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange400, orange600],
  );

  static const LinearGradient emberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange500, ember500],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [orange500, orange400, orange300],
  );

  static const LinearGradient midnightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [midnight900, midnight800, midnight900],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cream100, cream200, orange100],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), cream50],
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F784F28), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A784F28), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static List<BoxShadow> glow([Color color = orange500, double strength = 0.35]) => [
        BoxShadow(
          color: color.withValues(alpha: strength),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];
}
