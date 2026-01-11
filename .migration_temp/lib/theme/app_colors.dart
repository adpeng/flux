import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF131419);
  static const Color surfaceAlt = Color(0xFF0F1014);
  static const Color accent = Color(0xFFC0C7D1); // 银色高光
  static const Color accentSoft = Color(0xFFE2E6ED);
  static const Color accentWarm = Color(0xFF9FA8B8); // 冷银灰
  static const Color textPrimary = Color(0xFFE8ECF2);
  static const Color textSecondary = Color(0xFFAAB2C0);
  static const Color border = Color(0xFF1E2027);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFF9F43);
  static const Color success = Color(0xFF6CF2BC);

  static const LinearGradient heroGlow = LinearGradient(
    colors: [
      Color(0x22C0C7D1),
      Color(0x1517191F),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlow = LinearGradient(
    colors: [
      Color(0xFF181A22),
      Color(0xFF101115),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
