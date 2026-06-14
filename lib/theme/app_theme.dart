import 'package:flutter/material.dart';

/// 小学生向けの、やさしく明るいテーマ。
/// 文字・ボタンは大きめ、角丸を多用します。
class AppTheme {
  static const Color primary = Color(0xFFFF8A3D); // あたたかいオレンジ
  static const Color secondary = Color(0xFF4DC9B0); // やさしいミント
  static const Color accent = Color(0xFFFFD23F); // たまごの黄色
  static const Color bgTop = Color(0xFFFFF6E5);
  static const Color bgBottom = Color(0xFFFFE8CC);
  static const Color textDark = Color(0xFF4A3B2A);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
      ),
      scaffoldBackgroundColor: bgTop,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textDark,
        displayColor: textDark,
        fontSizeFactor: 1.1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  /// 背景グラデーション。
  static BoxDecoration get backgroundGradient => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgBottom],
        ),
      );
}
