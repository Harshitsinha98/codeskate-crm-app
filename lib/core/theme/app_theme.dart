import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Brand type system (same as web): Space Grotesk for display, Inter for
/// body, JetBrains Mono for numbers / IDs.
class AppText {
  AppText._();

  static TextStyle display({double size = 28, FontWeight weight = FontWeight.w700, Color color = AppColors.textPrimary, double letterSpacing = -0.6}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing, height: 1.15);

  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color color = AppColors.textSecondary, double height = 1.4}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle mono({double size = 13, FontWeight weight = FontWeight.w600, Color color = AppColors.textPrimary}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.2);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final inter = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textOnPrimary,
        surfaceTint: Colors.transparent,
      ),
      textTheme: inter.copyWith(
        displayLarge: AppText.display(size: 34),
        displayMedium: AppText.display(size: 28),
        displaySmall: AppText.display(size: 24),
        headlineLarge: AppText.display(size: 24, weight: FontWeight.w700),
        headlineMedium: AppText.display(size: 20, weight: FontWeight.w700),
        headlineSmall: AppText.display(size: 18, weight: FontWeight.w700),
        titleLarge: AppText.display(size: 18, weight: FontWeight.w600, letterSpacing: -0.3),
        titleMedium: AppText.body(size: 15, weight: FontWeight.w600, color: AppColors.textPrimary),
        titleSmall: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: AppText.body(size: 15, color: AppColors.textPrimary),
        bodyMedium: AppText.body(size: 14),
        bodySmall: AppText.body(size: 12, color: AppColors.textTertiary),
        labelLarge: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.textOnPrimary),
        labelMedium: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary),
        labelSmall: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.textTertiary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppText.display(size: 20, weight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.orange200,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: AppText.body(size: 15, weight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.midnight900,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppText.body(size: 14, weight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppText.body(size: 14, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          textStyle: AppText.body(size: 13.5, weight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppText.body(size: 14, color: AppColors.textTertiary),
        labelStyle: AppText.body(size: 14, color: AppColors.textTertiary),
        floatingLabelStyle: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.primaryDark),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.orange100,
        labelStyle: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: AppColors.border),
        ),
        side: const BorderSide(color: AppColors.border),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.border),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cream50,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cream50,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: AppText.display(size: 19, weight: FontWeight.w700),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.midnight900,
        contentTextStyle: AppText.body(size: 13.5, color: Colors.white, weight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: AppColors.primary,
        labelStyle: AppText.body(size: 13.5, weight: FontWeight.w700),
        unselectedLabelStyle: AppText.body(size: 13.5, weight: FontWeight.w500),
        dividerColor: AppColors.divider,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.cream50,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppText.body(size: 14, color: AppColors.textPrimary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        titleTextStyle: AppText.body(size: 14.5, weight: FontWeight.w600, color: AppColors.textPrimary),
        subtitleTextStyle: AppText.body(size: 12.5, color: AppColors.textTertiary),
      ),
    );
  }
}
