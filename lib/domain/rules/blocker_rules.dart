import '../models/bottle.dart';
import '../models/potion_color.dart';

/// Crystal, freeze, lock, and reveal. Engine and solver share this.
class BlockerRules {
  static bool isBrewedElsewhere(
    List<PotionBottle> bottles,
    Essence color,
    int exceptId,
  ) {
    var elsewhere = 0;
    for (final b in bottles) {
      if (b.id == exceptId) continue;
      elsewhere += b.countEssence(color);
    }
    if (elsewhere <= 0) return false;
    for (final b in bottles) {
      if (b.id == exceptId || b.isEmpty) continue;
      if (b.layers.any((l) => l.blocked || l.hidden || l.essence != color)) {
        continue;
      }
      if (b.countEssence(color) == elsewhere) return true;
    }
    return false;
  }

  static int crackCrystals(List<PotionBottle> bottles) {
    var cracked = 0;
    var progress = true;
    while (progress) {
      progress = false;
      for (final b in bottles) {
        final top = b.top;
        if (top == null || !top.crystal) continue;
        if (!isBrewedElsewhere(bottles, top.essence, b.id)) continue;
        top.crystal = false;
        cracked++;
        progress = true;
      }
    }
    return cracked;
  }

  static int thawReady(List<PotionBottle> bottles) {
    var n = 0;
    for (var i = 0; i < bottles.length; i++) {
      final b = bottles[i];
      if (b.top?.frozen != true) continue;
      final left = i > 0 && bottles[i - 1].isCompleteColor(bottles);
      final right =
          i < bottles.length - 1 && bottles[i + 1].isCompleteColor(bottles);
      if (left || right) {
        b.top!.frozen = false;
        n++;
      }
    }
    return n;
  }

  static void unlockIfReady(List<PotionBottle> bottles) {
    if (!bottles.any((b) => b.isCompleteColor(bottles))) return;
    for (final b in bottles) {
      b.locked = false;
    }
  }

  static void revealTops(List<PotionBottle> bottles) {
    for (final b in bottles) {
      if (b.top?.hidden == true) b.top!.hidden = false;
    }
  }

  static ({int crystals, int frost}) afterPour(List<PotionBottle> bottles) {
    unlockIfReady(bottles);
    final crystals = crackCrystals(bottles);
    final frost = thawReady(bottles);
    revealTops(bottles);
    return (crystals: crystals, frost: frost);
  }
}
