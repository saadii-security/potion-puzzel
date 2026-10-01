import '../models/bottle.dart';
import '../models/level.dart';
import '../models/objectives.dart';
import '../rules/blocker_rules.dart';
import '../rules/pour_rules.dart';
import '../rules/win_rules.dart';

class SolveResult {
  final int moves;
  const SolveResult(this.moves);
}

/// Finds a proven shortest win with A*.
///
/// This only runs while authoring/certifying a level. Live play reads the
/// baked move count from [LevelDefinition] and never invokes the solver.
class LevelSolver {
  static int? estimateMinMoves(
    List<PotionBottle> start,
    int capacity, {
    int limit = 2500,
  }) {
    final dummy = LevelDefinition(
      id: 0,
      world: 1,
      name: 'probe',
      capacity: capacity,
      bottles: start,
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 1,
      difficulty: DifficultyBand.easy,
      fingerprint: 'probe',
    );
    return solve(dummy, limit: limit)?.moves;
  }

  /// Returns null when no win is found before [limit]. A returned result is
  /// always optimal: A* only accepts a goal when its cheapest path is popped.
  static SolveResult? solve(LevelDefinition level, {int limit = 5000}) {
    final start = level.bottles.map((b) => b.copy()).toList();
    BlockerRules.revealTops(start);
    final canonical = _canCanonicalizeBottles(start);
    final startKey = _key(start, canonical: canonical);
    final frontier = _MinHeap()
      ..add(
        _Node(
          key: startKey,
          moves: 0,
          estimate: _lowerBound(start, level.objectives),
          bottles: start,
        ),
      );
    final best = <String, int>{startKey: 0};
    var explored = 0;

    while (frontier.isNotEmpty && explored < limit) {
      final node = frontier.removeFirst();
      if (best[node.key] != node.moves) continue;
      explored++;
      if (WinRules.meetsWin(node.bottles, level.objectives)) {
        return SolveResult(node.moves);
      }

      final bottles = node.bottles;
      for (var from = 0; from < bottles.length; from++) {
        for (var to = 0; to < bottles.length; to++) {
          if (!PourRules.canPour(bottles, from, to)) continue;
          final next = bottles.map((b) => b.copy()).toList();
          PourRules.pour(next, from, to);
          BlockerRules.afterPour(next);
          final key = _key(next, canonical: canonical);
          final moves = node.moves + 1;
          if ((best[key] ?? 1 << 30) <= moves) continue;
          best[key] = moves;
          frontier.add(
            _Node(
              key: key,
              moves: moves,
              estimate: moves + _lowerBound(next, level.objectives),
              bottles: next,
            ),
          );
        }
      }
    }
    return null;
  }

  /// Every unlike adjacent pair must be exposed by a separate pour. A pour
  /// can remove at most one such boundary, so this never overestimates.
  static int _lowerBound(
    List<PotionBottle> bottles,
    List<LevelObjective> objectives,
  ) {
    if (!objectives.any((o) => o.kind == ObjectiveKind.sortAll)) return 0;
    var boundaries = 0;
    for (final bottle in bottles) {
      for (var i = 1; i < bottle.layers.length; i++) {
        if (bottle.layers[i - 1].essence != bottle.layers[i].essence) {
          boundaries++;
        }
      }
    }
    return boundaries;
  }

  /// Plain water-sort bottles are interchangeable. Mechanics can attach law
  /// to an id, slot, or bottle, so keep fixed order whenever any are present.
  static bool _canCanonicalizeBottles(List<PotionBottle> bottles) =>
      bottles.every(
        (b) =>
            !b.locked &&
            b.portalTwin == null &&
            b.targetEssence == null &&
            !b.extra &&
            b.layers.every(
              (layer) =>
                  !layer.crystal &&
                  !layer.frozen &&
                  !layer.hidden &&
                  !layer.bomb &&
                  !layer.lightning,
            ),
      );

  static String _key(List<PotionBottle> bottles, {required bool canonical}) {
    final parts = bottles.map((b) {
      final lock = b.locked ? 'L' : '';
      final tgt = b.targetEssence != null ? 'T${b.targetEssence!.index}' : '';
      final portal = b.portalTwin != null ? 'P${b.portalTwin}' : '';
      final extra = b.extra ? 'X' : '';
      final layers = b.layers
          .map(
            (l) =>
                '${l.essence.index}'
                '${l.crystal ? 'c' : ''}'
                '${l.frozen ? 'f' : ''}'
                '${l.hidden ? 'h' : ''}'
                '${l.bomb ? 'b' : ''}'
                '${l.lightning ? 'l' : ''}',
          )
          .join(',');
      final id = canonical ? '' : '${b.id}:';
      return '$id${b.capacity}$lock$tgt$portal$extra[$layers]';
    }).toList();
    if (canonical) parts.sort();
    return parts.join('/');
  }
}

class _Node {
  final String key;
  final int moves;
  final int estimate;
  final List<PotionBottle> bottles;
  const _Node({
    required this.key,
    required this.moves,
    required this.estimate,
    required this.bottles,
  });
}

class _MinHeap {
  final _nodes = <_Node>[];

  bool get isNotEmpty => _nodes.isNotEmpty;

  void add(_Node node) {
    _nodes.add(node);
    var child = _nodes.length - 1;
    while (child > 0) {
      final parent = (child - 1) ~/ 2;
      if (!_before(_nodes[child], _nodes[parent])) break;
      final swap = _nodes[child];
      _nodes[child] = _nodes[parent];
      _nodes[parent] = swap;
      child = parent;
    }
  }

  _Node removeFirst() {
    final first = _nodes.first;
    final last = _nodes.removeLast();
    if (_nodes.isEmpty) return first;
    _nodes[0] = last;
    var parent = 0;
    while (true) {
      final left = parent * 2 + 1;
      if (left >= _nodes.length) break;
      final right = left + 1;
      var child = left;
      if (right < _nodes.length && _before(_nodes[right], _nodes[left])) {
        child = right;
      }
      if (!_before(_nodes[child], _nodes[parent])) break;
      final swap = _nodes[child];
      _nodes[child] = _nodes[parent];
      _nodes[parent] = swap;
      parent = child;
    }
    return first;
  }

  static bool _before(_Node a, _Node b) =>
      a.estimate < b.estimate ||
      (a.estimate == b.estimate && a.moves > b.moves);
}
