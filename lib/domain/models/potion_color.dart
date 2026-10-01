import 'package:flutter/material.dart';

enum Essence {
  ember,
  azure,
  moss,
  sun,
  violet,
  cocoa,
  frost,
  blush,
  rainbow,
  wild,
  poison,
  mystery,
}

extension EssenceX on Essence {
  bool get isSpecial =>
      this == Essence.rainbow ||
      this == Essence.wild ||
      this == Essence.poison ||
      this == Essence.mystery;

  bool get isPourableColor =>
      !isSpecial || this == Essence.rainbow || this == Essence.wild;

  String get glyph {
    switch (this) {
      case Essence.ember:
        return '◆';
      case Essence.azure:
        return '●';
      case Essence.moss:
        return '▲';
      case Essence.sun:
        return '■';
      case Essence.violet:
        return '★';
      case Essence.cocoa:
        return '✚';
      case Essence.frost:
        return '❖';
      case Essence.blush:
        return '✿';
      case Essence.rainbow:
        return '🌈';
      case Essence.wild:
        return '?';
      case Essence.poison:
        return '☠';
      case Essence.mystery:
        return '◌';
    }
  }

  String get label {
    switch (this) {
      case Essence.ember:
        return 'Ember';
      case Essence.azure:
        return 'Azure';
      case Essence.moss:
        return 'Moss';
      case Essence.sun:
        return 'Sun';
      case Essence.violet:
        return 'Violet';
      case Essence.cocoa:
        return 'Cocoa';
      case Essence.frost:
        return 'Frost';
      case Essence.blush:
        return 'Blush';
      case Essence.rainbow:
        return 'Prism';
      case Essence.wild:
        return 'Wild';
      case Essence.poison:
        return 'Blight';
      case Essence.mystery:
        return 'Veil';
    }
  }

  Color get tint {
    switch (this) {
      case Essence.ember:
        return const Color(0xFFE85D4C);
      case Essence.azure:
        return const Color(0xFF3D8BFF);
      case Essence.moss:
        return const Color(0xFF3FA36C);
      case Essence.sun:
        return const Color(0xFFF4C430);
      case Essence.violet:
        return const Color(0xFF8B5CFF);
      case Essence.cocoa:
        return const Color(0xFF8A5A33);
      case Essence.frost:
        return const Color(0xFF5EE0D0);
      case Essence.blush:
        return const Color(0xFFFF7AA2);
      case Essence.rainbow:
        return const Color(0xFFFF8AD8);
      case Essence.wild:
        return const Color(0xFFD8D2FF);
      case Essence.poison:
        return const Color(0xFF6B8F2A);
      case Essence.mystery:
        return const Color(0xFF6A6580);
    }
  }

  bool matches(Essence other) {
    if (this == Essence.mystery || other == Essence.mystery) return false;
    if (this == Essence.poison || other == Essence.poison) {
      return this == other;
    }
    if (this == Essence.rainbow ||
        other == Essence.rainbow ||
        this == Essence.wild ||
        other == Essence.wild) {
      return true;
    }
    return this == other;
  }
}

const playableEssences = [
  Essence.ember,
  Essence.azure,
  Essence.moss,
  Essence.sun,
  Essence.violet,
  Essence.cocoa,
  Essence.frost,
  Essence.blush,
];
