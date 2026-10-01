import '../models/bottle.dart';
import '../models/layer.dart';
import '../models/objectives.dart';

/// Single definition of "the board is won".
/// Live play and the solvability search must agree.
class WinRules {
  static bool isBoardSorted(List<PotionBottle> bottles) =>
      bottles.every((b) => b.isEmpty || b.isSorted(bottles));

  static bool meetsWin(
    List<PotionBottle> bottles,
    List<LevelObjective> objectives,
  ) {
    final required = objectives.where(
      (o) => o.kind != ObjectiveKind.limitedMoves,
    );
    if (required.isEmpty) return isBoardSorted(bottles);
    for (final o in required) {
      if (!_objectiveMet(bottles, o)) return false;
    }
    return true;
  }

  static int progressFor(
    List<PotionBottle> bottles,
    LevelObjective objective, {
    int moves = 0,
    int specialsForged = 0,
    int rainbows = 0,
  }) {
    switch (objective.kind) {
      case ObjectiveKind.sortAll:
        return isBoardSorted(bottles) ? 1 : 0;
      case ObjectiveKind.collectColor:
        return bottles.fold(0, (sum, bottle) {
          if (!bottle.isCompleteColor(bottles)) return sum;
          if (objective.essence != null &&
              bottle.layers.first.essence != objective.essence) {
            return sum;
          }
          return sum + bottle.layers.length;
        });
      case ObjectiveKind.breakCrystals:
        return _cleared(bottles, objective.target, (layer) => layer.crystal);
      case ObjectiveKind.limitedMoves:
        return moves;
      case ObjectiveKind.createSpecials:
        return specialsForged;
      case ObjectiveKind.breakFreeze:
        return _cleared(bottles, objective.target, (layer) => layer.frozen);
      case ObjectiveKind.targetBottle:
        return _objectiveMet(bottles, objective) ? 1 : 0;
      case ObjectiveKind.rainbow:
        return rainbows;
    }
  }

  static int _cleared(
    List<PotionBottle> bottles,
    int target,
    bool Function(PotionLayer layer) flag,
  ) {
    final remaining = bottles.fold<int>(
      0,
      (sum, bottle) => sum + bottle.layers.where(flag).length,
    );
    return (target - remaining).clamp(0, target);
  }

  static bool _objectiveMet(List<PotionBottle> bottles, LevelObjective o) {
    switch (o.kind) {
      case ObjectiveKind.sortAll:
        return isBoardSorted(bottles);
      case ObjectiveKind.collectColor:
        return progressFor(bottles, o) >= o.target;
      case ObjectiveKind.breakCrystals:
        return !bottles.any((b) => b.layers.any((l) => l.crystal));
      case ObjectiveKind.breakFreeze:
        return !bottles.any((b) => b.layers.any((l) => l.frozen));
      case ObjectiveKind.targetBottle:
        return bottles
            .where((b) => b.targetEssence != null)
            .any(
              (b) =>
                  b.isCompleteColor(bottles) &&
                  (o.essence == null ||
                      b.layers.first.essence == o.essence ||
                      b.layers.first.essence == b.targetEssence),
            );
      case ObjectiveKind.createSpecials:
      case ObjectiveKind.rainbow:
        // Not part of a generated win path. Do not ship levels that require these.
        return false;
      case ObjectiveKind.limitedMoves:
        return true;
    }
  }
}
