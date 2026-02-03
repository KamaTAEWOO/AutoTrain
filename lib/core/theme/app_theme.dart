import 'package:flutter/material.dart';
import 'korail_colors.dart';

/// 앱 테마 및 컬러 정의
class AppTheme {
  AppTheme._();

  // ── 간격 상수 ──
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ── 테두리 둥글기 ──
  static const double radiusCard = 12.0;
  static const double radiusButton = 8.0;
  static const double radiusBadge = 20.0;

  // ── 그림자 높이 ──
  static const double elevationCard = 1.0;
  static const double elevationActiveCard = 3.0;

  /// Material 3 라이트 테마 (코레일 스타일)
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: KorailColors.korailBlue,
      brightness: Brightness.light,
      surface: KorailColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        primary: KorailColors.korailBlue,
        secondary: KorailColors.skyBlue,
      ),
      scaffoldBackgroundColor: KorailColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: KorailColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        elevation: elevationCard,
        color: KorailColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          backgroundColor: KorailColors.korailBlue,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm + spacingXs,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: KorailColors.korailBlue.withAlpha(30),
        elevation: 2,
      ),
    );
  }
}
