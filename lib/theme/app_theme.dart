import 'package:flutter/material.dart';

class AppTheme {
  // Luxury Heritage Palette
  static const Color bgDark = Color(0xFF191009);
  static const Color bgSurface = Color(0xFF261910);
  static const Color bgCard = Color(0xFF332216);
  static const Color bgCardHover = Color(0xFF422C1D);
  static const Color bgAccent = Color(0xFF523623);

  static const Color gold = Color(0xFFFFD54F);
  static const Color goldLight = Color(0xFFFFF0B8);
  static const Color goldDark = Color(0xFFD4AF37);

  static const Color tigerOrange = Color(0xFFF28C28);
  static const Color goatTan = Color(0xFFE3C99A);

  static const Color terracotta = Color(0xFFE05338);
  static const Color jade = Color(0xFF10B981);
  static const Color lapis = Color(0xFF3B82F6);
  static const Color saffron = Color(0xFFF59E0B);

  static const Color textLight = Color(0xFFFDFBF7);
  static const Color textMuted = Color(0xFFC7B7A6);
  static const Color textDisabled = Color(0xFF7A6856);

  static BoxDecoration cardDecoration({
    bool isSelected = false,
    Color? borderColor,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: isSelected ? bgCardHover : bgCard,
      borderRadius: borderRadius ?? BorderRadius.circular(18),
      border: Border.all(
        color: isSelected
            ? (borderColor ?? gold)
            : const Color(0x2BD4AF37),
        width: isSelected ? 2.2 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        if (isSelected)
          BoxShadow(
            color: (borderColor ?? gold).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }

  static BoxDecoration heroCardDecoration({required Color accent}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withOpacity(0.25),
          bgCard,
          bgDark,
        ],
      ),
      border: Border.all(
        color: accent.withOpacity(0.6),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: accent.withOpacity(0.15),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: saffron,
        surface: bgSurface,
        onSurface: textLight,
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
