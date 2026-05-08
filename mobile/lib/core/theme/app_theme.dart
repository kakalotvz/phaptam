import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color(0xFF6D4C41);
  static const secondary = Color(0xFFD4AF37);
  static const background = Color(0xFFF5F5DC);
  static const darkBackground = Color(0xFF121212);
  static const statusSuccess = Color(0xFF15803D);
  static const statusWarning = Color(0xFFB45309);
  static const statusInfo = Color(0xFF2563EB);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: const Color(0xFFFFFCF0),
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: background,
      extensions: const [
        AppStatusColors(
          success: statusSuccess,
          warning: statusWarning,
          info: statusInfo,
        ),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Color(0xFF2F241F),
        elevation: 0,
        centerTitle: false,
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: const Color(0xFFB08A7D),
      secondary: secondary,
      surface: const Color(0xFF1B1B1B),
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: darkBackground,
      extensions: const [
        AppStatusColors(
          success: Color(0xFF4ADE80),
          warning: Color(0xFFFBBF24),
          info: Color(0xFF60A5FA),
        ),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: GoogleFonts.notoSans().fontFamily,
      textTheme: GoogleFonts.notoSansTextTheme().copyWith(
        displayLarge: GoogleFonts.notoSerif(fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.notoSerif(fontWeight: FontWeight.w800),
        headlineLarge: GoogleFonts.notoSerif(fontWeight: FontWeight.w800),
        headlineMedium: GoogleFonts.notoSerif(fontWeight: FontWeight.w800),
        titleLarge: GoogleFonts.notoSerif(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.brightness == Brightness.dark
            ? const Color(0xFF1D4ED8)
            : statusInfo,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: scheme.secondary.withValues(alpha: .18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color success;
  final Color warning;
  final Color info;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}
