import 'dart:math';

import '../models/bottle.dart';
import '../models/layer.dart';
import '../models/potion_color.dart';
import '../rules/win_rules.dart';

/// Reverse-from-solved shuffle. Starts with exact vial-counts of each color,
/// then pours until the board is mixed. Shared by generated and onboard vials.
class BoardScrambler {
  static List<PotionBottle> solved({
    required int colors,
    required int empties,
    required int capacity,
  }) {
    final bottles = <PotionBottle>[];
    var id = 0;
    for (final e in playableEssences.take(colors)) {
      bottles.add(
        PotionBottle(
          id: id++,
          capacity: capacity,
          layers: List.generate(capacity, (_) => PotionLayer(essence: e)),
        ),
      );
    }
    for (var i = 0; i < empties; i++) {
      bottles.add(PotionBottle(id: id++, capacity: capacity, layers: []));
    }
    return bottles;
  }

  static List<PotionBottle> fromSolved({
    required int colors,
    required int empties,
    required int capacity,
    required int pours,
    required int seed,
  }) {
    final rng = Random(seed);
    final bottles = solved(
      colors: colors,
      empties: empties,
      capacity: capacity,
    );
    mix(bottles, rng, pours: pours);
    return bottles;
  }

  /// Keeps pouring until [pours] succeed, then until nothing is pre-corked
  /// and the board is not already won.
  static void mix(
    List<PotionBottle> bottles,
    Random rng, {
    required int pours,
  }) {
    var done = 0;
    var tries = 0;
    while (done < pours && tries < pours * 80) {
      tries++;
      if (_mixOnce(bottles, rng)) done++;
    }
    var extra = 0;
    while (_needsMoreMix(bottles) && extra < 120) {
      extra++;
      if (!_mixOnce(bottles, rng, preferFinished: true)) break;
    }
  }

  static bool _needsMoreMix(List<PotionBottle> bottles) =>
      WinRules.isBoardSorted(bottles) ||
      bottles.any((b) => !b.isEmpty && b.isCompleteColor(bottles));

  static bool _mixOnce(
    List<PotionBottle> bottles,
    Random rng, {
    bool preferFinished = false,
  }) {
    final fromIdx = <int>[
      for (var i = 0; i < bottles.length; i++)
        if (!bottles[i].isEmpty) i,
    ];
    if (preferFinished) {
      final finished = [
        for (final i in fromIdx)
          if (bottles[i].isCompleteColor(bottles)) i,
      ];
      if (finished.isNotEmpty) {
        fromIdx
          ..clear()
          ..addAll(finished);
      }
    }
    final toIdx = <int>[
      for (var i = 0; i < bottles.length; i++)
        if (!bottles[i].isFull) i,
    ];
    if (fromIdx.isEmpty || toIdx.isEmpty) return false;
    fromIdx.shuffle(rng);
    toIdx.shuffle(rng);
    for (final from in fromIdx) {
      for (final to in toIdx) {
        if (from == to) continue;
        if (_pourMix(bottles[from], bottles[to], rng)) return true;
      }
    }
    return false;
  }

  static bool _pourMix(PotionBottle a, PotionBottle b, Random rng) {
    if (a.isEmpty || b.isFull) return false;
    var maxTake = min(a.topRun(), b.space);
    if (maxTake <= 0) return false;
    if (b.isEmpty &&
        a.layers.isNotEmpty &&
        a.layers.every((l) => l.essence == a.layers.first.essence) &&
        maxTake >= a.layers.length) {
      maxTake = a.layers.length - 1;
    }
    if (maxTake <= 0) return false;
    final take = 1 + rng.nextInt(maxTake);
    for (var k = 0; k < take; k++) {
      b.layers.add(a.layers.removeLast());
    }
    return true;
  }
}
