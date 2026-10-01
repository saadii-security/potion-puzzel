import 'package:flutter/material.dart';

/// Candy-Crush-style visual language: deep grape outlines, glossy saturated
/// candy fills, thick bevels, and rounded display type.
///
/// Every surface in the app is built from three pieces: a dark outline, a
/// vertical candy gradient, and a specular gloss on the top half. Keep those
/// three together and new widgets look native to the theme for free.
class CandyTheme {
  // Outlines and shadows. Candy Crush never uses pure black.
  static const outline = Color(0xFF3B1153);
  static const outlineSoft = Color(0xFF5B2A7A);

  // Panel purples.
  static const grapeLight = Color(0xFF9B59F6);
  static const grape = Color(0xFF7B3FE4);
  static const grapeDark = Color(0xFF4A1D8F);
  static const grapeDeep = Color(0xFF2E0F52);

  // Action colours.
  static const greenLight = Color(0xFFA8E063);
  static const green = Color(0xFF63C71C);
  static const greenDark = Color(0xFF3E8E0C);

  static const orangeLight = Color(0xFFFFD25E);
  static const orange = Color(0xFFFF9E1B);
  static const orangeDark = Color(0xFFD96A00);

  static const pinkLight = Color(0xFFFF9CC8);
  static const pink = Color(0xFFFF4FA3);
  static const pinkDark = Color(0xFFC2185B);

  static const blueLight = Color(0xFF7FE0FF);
  static const blue = Color(0xFF29B6F6);
  static const blueDark = Color(0xFF0277BD);

  static const goldLight = Color(0xFFFFF176);
  static const gold = Color(0xFFFFC61A);
  static const goldDark = Color(0xFFE08A00);

  static const cream = Color(0xFFFFF8E7);
  static const stone = Color(0xFF9E8FAE);

  /// Top-lit candy fill: light at the top, saturated at the bottom.
  static LinearGradient candy(Color light, Color base, Color dark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [light, base, dark],
      stops: const [0.0, 0.55, 1.0],
    );
  }

  static LinearGradient get greenCandy => candy(greenLight, green, greenDark);
  static LinearGradient get orangeCandy =>
      candy(orangeLight, orange, orangeDark);
  static LinearGradient get pinkCandy => candy(pinkLight, pink, pinkDark);
  static LinearGradient get blueCandy => candy(blueLight, blue, blueDark);
  static LinearGradient get goldCandy => candy(goldLight, gold, goldDark);
  static LinearGradient get grapeCandy => candy(grapeLight, grape, grapeDark);
  static LinearGradient get creamCandy =>
      candy(Colors.white, cream, const Color(0xFFFFE0A8));

  /// The candy gradient that matches a flat accent colour, so callers can keep
  /// passing a single colour and still get the glossy three-stop fill.
  static LinearGradient candyFor(Color base) {
    if (base == green) return greenCandy;
    if (base == orange) return orangeCandy;
    if (base == pink) return pinkCandy;
    if (base == blue) return blueCandy;
    if (base == gold) return goldCandy;
    if (base == grape) return grapeCandy;
    final hsl = HSLColor.fromColor(base);
    return candy(
      hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor(),
      base,
      hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor(),
    );
  }

  /// Chunky bevelled surface: dark rim plus a solid drop shadow underneath.
  static BoxDecoration bevel({
    required Gradient gradient,
    double radius = 24,
    double depth = 6,
    Color rim = outline,
    double rimWidth = 3,
  }) {
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: rim, width: rimWidth),
      boxShadow: [
        BoxShadow(color: rim, offset: Offset(0, depth), blurRadius: 0),
        BoxShadow(
          color: outline.withValues(alpha: 0.35),
          offset: Offset(0, depth + 4),
          blurRadius: 10,
        ),
      ],
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: grape,
        brightness: Brightness.light,
        primary: grape,
        surface: cream,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: grapeDeep,
      textTheme: base.textTheme.apply(
        fontFamily: 'CandyBody',
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}
