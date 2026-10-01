import '../../core/config.dart';
import '../models/bottle.dart';
import '../models/level.dart';
import '../models/objectives.dart';
import '../models/potion_color.dart';
import '../rules/win_rules.dart';
import '../solver/level_solver.dart';

/// One door for "may this vial ship?"
/// Layout invariants first, then a real solution search.
class LevelQa {
  static bool isValid(LevelDefinition level) => problems(level).isEmpty;

  static bool bottlesValid(List<PotionBottle> bottles, int capacity) =>
      layoutProblems(bottles, capacity).isEmpty;

  static bool isPlayable(LevelDefinition level, {int? solveLimit}) =>
      playableProblems(level, solveLimit: solveLimit).isEmpty;

  static LevelDefinition certify(LevelDefinition level, {int? solveLimit}) {
    final errors = playableProblems(level, solveLimit: solveLimit);
    if (errors.isNotEmpty) {
      throw StateError('Vial ${level.id} failed QA: ${errors.join('; ')}');
    }
    return level;
  }

  /// Color counts, crystal lids, workspace, already-sorted, matching objectives.
  static List<String> problems(LevelDefinition level) {
    final errors = layoutProblems(level.bottles, level.capacity);
    final counts = _playableCounts(level.bottles);
    for (final o in level.objectives) {
      if (o.kind != ObjectiveKind.collectColor || o.essence == null) continue;
      final have = counts[o.essence!] ?? 0;
      if (have < o.target) {
        errors.add(
          'collect ${o.essence!.name} ×${o.target} but only $have exist',
        );
      }
    }
    errors.addAll(_targetBottleProblems(level, counts));
    if (WinRules.isBoardSorted(level.bottles)) {
      errors.add('board starts already sorted');
    }
    for (final b in level.bottles) {
      if (!b.isEmpty && b.isCompleteColor(level.bottles)) {
        errors.add('bottle ${b.id} starts already finished');
      }
    }
    return errors;
  }

  static List<String> layoutProblems(List<PotionBottle> bottles, int capacity) {
    final errors = <String>[];
    if (capacity <= 0) {
      errors.add('capacity must be positive');
      return errors;
    }
    for (final b in bottles) {
      if (b.capacity != capacity) {
        errors.add('bottle ${b.id} capacity ${b.capacity} != level $capacity');
      }
      if (b.layers.length > b.capacity) {
        errors.add(
          'bottle ${b.id} has ${b.layers.length} layers over cap ${b.capacity}',
        );
      }
    }

    final counts = _playableCounts(bottles);
    for (final entry in counts.entries) {
      final n = entry.value;
      if (n > capacity && n % capacity != 0) {
        errors.add(
          '${entry.key.name} has $n drops (leftover ${n % capacity}; vial cap $capacity)',
        );
      }
    }

    errors.addAll(_crystalDeadlocks(bottles, capacity));

    final pourable = bottles.any(
      (b) => !b.isEmpty && !b.locked && b.top != null && !b.top!.blocked,
    );
    final solved = WinRules.isBoardSorted(bottles);
    if (!pourable && !solved) {
      errors.add('every vial is sealed — no legal first pour');
    }
    final emptySlots = bottles.fold<int>(0, (sum, b) => sum + b.space);
    if (emptySlots == 0 && !solved) {
      errors.add('no empty space and the board is not already sorted');
    }
    return errors;
  }

  /// Layout plus a proven solution of at least [GameConfig.minPlayableMoves] pours.
  static List<String> playableProblems(
    LevelDefinition level, {
    int? solveLimit,
  }) {
    final errors = problems(level);
    if (errors.isNotEmpty) return errors;
    final limit = solveLimit ?? GameConfig.solveNodeLimit;
    final solved = LevelSolver.solve(level, limit: limit);
    if (solved == null) {
      errors.add('unsolvable (no win in $limit states)');
      return errors;
    }
    if (solved.moves <= 0) {
      errors.add('already won — the vial loads solved');
    }
    final minMoves = GameConfig.minPlayableMoves(level.id);
    if (solved.moves < minMoves) {
      errors.add(
        'too trivial (${solved.moves} pours, need at least $minMoves)',
      );
    }
    if (level.maxMoves == null) {
      errors.add('vial ships with no baked pour cap');
    }
    final budget = level.moveBudget;
    if (solved.moves > budget) {
      errors.add('needs ${solved.moves} pours but the budget is $budget');
    }
    if (level.estimatedMinMoves != solved.moves) {
      errors.add(
        'par is ${level.estimatedMinMoves} but solver proved ${solved.moves}',
      );
    }
    return errors;
  }

  static Map<Essence, int> _playableCounts(List<PotionBottle> bottles) {
    final counts = <Essence, int>{};
    for (final b in bottles) {
      for (final layer in b.layers) {
        if (layer.essence.isSpecial) continue;
        counts[layer.essence] = (counts[layer.essence] ?? 0) + 1;
      }
    }
    return counts;
  }

  static List<String> _crystalDeadlocks(
    List<PotionBottle> bottles,
    int capacity,
  ) {
    final errors = <String>[];
    for (final b in bottles) {
      for (final layer in b.layers) {
        if (!layer.crystal || layer.essence.isSpecial) continue;
        var elsewhere = 0;
        var pourableElsewhere = 0;
        for (final other in bottles) {
          if (other.id == b.id) continue;
          for (final l in other.layers) {
            if (l.essence != layer.essence) continue;
            elsewhere++;
            if (!l.blocked) pourableElsewhere++;
          }
        }
        if (elsewhere == 0 || pourableElsewhere == 0) {
          errors.add(
            'crystal ${layer.essence.name} in bottle ${b.id} has no pourable drops elsewhere to brew',
          );
        } else if (elsewhere > capacity && elsewhere % capacity != 0) {
          errors.add(
            'crystal ${layer.essence.name} in bottle ${b.id} leaves $elsewhere drops elsewhere',
          );
        }
      }
    }
    return errors;
  }

  static List<String> _targetBottleProblems(
    LevelDefinition level,
    Map<Essence, int> counts,
  ) {
    final errors = <String>[];
    final marked = level.bottles.where((b) => b.targetEssence != null).toList();
    final wantsTarget = level.objectives.any(
      (o) => o.kind == ObjectiveKind.targetBottle,
    );
    if (wantsTarget && marked.isEmpty) {
      errors.add('fill-the-marked-vial objective has no marked vial');
    }
    if (marked.length > 1) {
      errors.add('multiple marked vials');
    }
    if (marked.isEmpty) return errors;
    final color = marked.first.targetEssence!;
    final have = counts[color] ?? 0;
    if (have == 0) {
      errors.add('marked vial wants ${color.name} but that color is missing');
    } else if (have > level.capacity) {
      errors.add('marked vial cannot hold $have ${color.name} drops');
    }
    return errors;
  }
}
