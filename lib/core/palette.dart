import 'package:flutter/material.dart';

/// Theatrical velvet-and-gold palette shared by every screen.
class Palette {
  const Palette._();

  static const Color velvetDeep = Color(0xFF1B0620);
  static const Color velvet = Color(0xFF2A0B2E);
  static const Color velvetLight = Color(0xFF43154B);
  static const Color plum = Color(0xFF6B2079);
  static const Color crimson = Color(0xFF8E1230);
  static const Color crimsonLight = Color(0xFFC7203F);
  static const Color gold = Color(0xFFF4C542);
  static const Color goldDeep = Color(0xFFB8862A);
  static const Color goldPale = Color(0xFFFFE9A8);
  static const Color magenta = Color(0xFFE04FCF);
  static const Color cyan = Color(0xFF56D8F5);
  static const Color mint = Color(0xFF7BE8A8);
  static const Color ink = Color(0xFF120310);

  static const LinearGradient curtain = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3B0E45), Color(0xFF1B0620)],
  );

  static const LinearGradient goldBar = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFB8862A), Color(0xFFF4C542), Color(0xFFFFF3C4), Color(0xFFF4C542)],
    stops: [0.0, 0.45, 0.65, 1.0],
  );

  static const LinearGradient hypeBar = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE04FCF), Color(0xFFF4C542)],
  );

  static const LinearGradient buttonGold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE9A8), Color(0xFFF4C542), Color(0xFFB8862A)],
  );

  static const LinearGradient buttonVelvet = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7A2A8A), Color(0xFF3D0F47)],
  );

  static List<BoxShadow> glow(Color color, {double blur = 18, double spread = 0}) => [
        BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: blur, spreadRadius: spread),
      ];
}

/// Typography helpers. The game ships without custom font files, so we lean on
/// weight, spacing and shadow to carry the circus-poster feel.
class AppText {
  const AppText._();

  static TextStyle title(double size, {Color color = Palette.goldPale}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: size * 0.06,
        height: 1.05,
        shadows: const [
          Shadow(color: Color(0xFF3D0114), blurRadius: 0, offset: Offset(0, 2)),
          Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      );

  static TextStyle label(double size, {Color color = Palette.goldPale, FontWeight? weight}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w700,
        color: color,
        letterSpacing: size * 0.05,
        shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 5, offset: Offset(0, 1))],
      );

  static TextStyle body(double size, {Color color = const Color(0xFFEBD6F2)}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.3,
        shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 1))],
      );

  static TextStyle numeric(double size, {Color color = Palette.goldPale}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2))],
      );
}
