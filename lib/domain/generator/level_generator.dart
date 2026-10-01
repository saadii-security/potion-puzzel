import 'dart:math';

import '../../core/config.dart';
import '../levels/level_qa.dart';
import '../models/bottle.dart';
import '../models/layer.dart';
import '../models/level.dart';
import '../models/objectives.dart';
import '../models/potion_color.dart';
import '../rules/move_rules.dart';
import '../solver/level_solver.dart';
import 'board_scrambler.dart';

/// Isolate entry: certify one vial off the UI thread.
Map<String, dynamic> generateLevelJson(int id) =>
    LevelGenerator().generate(id).toJson();

/// Builds vials by reverse-shuffling a legal solved board, then certifying
/// with [LevelQa]. Nothing ships that starts solved or cannot be won.
class LevelGenerator {
  final _cache = <int, LevelDefinition>{};

  bool isCached(int id) => _cache.containsKey(id);

  void adopt(LevelDefinition level) => _cache[level.id] = level;

  LevelDefinition generate(int id) => _cache.putIfAbsent(id, () => _build(id));

  LevelDefinition _build(int id) {
    final world = ((id - 1) ~/ GameConfig.levelsPerWorld) + 1;
    final boss = GameConfig.worlds[world - 1].isBoss(id);
    final colors = _colorCount(world, id, boss);
    final empties = boss ? 2 : (id < 8 ? 1 : 2);
    final capacity = GameConfig.bottleCapacity;

    for (var attempt = 0; attempt < 4; attempt++) {
      final pours = 16 + attempt * 4 + world * 2;
      final bottles = BoardScrambler.fromSolved(
        colors: colors,
        empties: empties,
        capacity: capacity,
        pours: pours,
        seed: 91000 + id * 17 + attempt * 7919,
      );
      _applyMechanics(bottles, world, id);
      if (!LevelQa.bottlesValid(bottles, capacity)) continue;

      final objectives = _objectives(world, id, bottles, boss);
      final candidate = _definition(
        id: id,
        world: world,
        boss: boss,
        bottles: bottles,
        objectives: objectives,
        minMoves: (colors * 3 + id % 5).clamp(4, 40),
      );
      if (!LevelQa.isValid(candidate)) continue;

      final solved = LevelSolver.solve(
        candidate,
        limit: GameConfig.solveNodeLimit,
      );
      if (solved == null) continue;
      if (solved.moves < GameConfig.minPlayableMoves(id)) continue;

      return LevelQa.certify(
        _definition(
          id: id,
          world: world,
          boss: boss,
          bottles: bottles,
          objectives: objectives,
          minMoves: solved.moves,
        ),
      );
    }

    for (var extra = 0; extra < 8; extra++) {
      final bottles = BoardScrambler.fromSolved(
        colors: colors,
        empties: max(empties, 1),
        capacity: capacity,
        pours: 12 + extra * 4,
        seed: 22000 + id * 13 + extra * 97,
      );
      final candidate = _definition(
        id: id,
        world: world,
        boss: boss,
        bottles: bottles,
        objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
        minMoves: GameConfig.minPlayableMoves(id),
      );
      if (!LevelQa.isValid(candidate)) continue;
      final solved = LevelSolver.solve(
        candidate,
        limit: GameConfig.solveNodeLimit,
      );
      if (solved == null || solved.moves < GameConfig.minPlayableMoves(id)) {
        continue;
      }
      return LevelQa.certify(
        _definition(
          id: id,
          world: world,
          boss: boss,
          bottles: bottles,
          objectives: candidate.objectives,
          minMoves: solved.moves,
        ),
      );
    }

    // Final deterministic seed still passes the same exact certification door.
    // Never ship a guessed par when the search cap is exhausted.
    final bottles = BoardScrambler.fromSolved(
      colors: colors,
      empties: max(empties, 1),
      capacity: capacity,
      pours: 40,
      seed: 33000 + id * 29,
    );
    final candidate = _definition(
      id: id,
      world: world,
      boss: boss,
      bottles: bottles,
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      minMoves: GameConfig.minPlayableMoves(id),
    );
    if (LevelQa.isValid(candidate)) {
      final solved = LevelSolver.solve(
        candidate,
        limit: GameConfig.solveNodeLimit,
      );
      if (solved != null && solved.moves >= GameConfig.minPlayableMoves(id)) {
        return LevelQa.certify(
          _definition(
            id: id,
            world: world,
            boss: boss,
            bottles: bottles,
            objectives: candidate.objectives,
            minMoves: solved.moves,
          ),
        );
      }
    }
    throw StateError('Vial $id could not be exactly certified');
  }

  LevelDefinition _definition({
    required int id,
    required int world,
    required bool boss,
    required List<PotionBottle> bottles,
    required List<LevelObjective> objectives,
    required int minMoves,
  }) {
    return LevelDefinition(
      id: id,
      world: world,
      name: boss ? _bossName(world) : 'Vial $id',
      capacity: GameConfig.bottleCapacity,
      bottles: bottles,
      objectives: objectives,
      maxMoves: MoveRules.budget(minMoves, id: id, boss: boss),
      estimatedMinMoves: minMoves,
      difficulty: _band(world, id, minMoves, boss),
      boss: boss,
      fingerprint: _fingerprint(bottles),
    );
  }

  int _colorCount(int world, int id, bool boss) {
    var n = 2 + ((id - 1) ~/ 6).clamp(0, 6);
    n = n.clamp(2, playableEssences.length);
    if (world >= 2) n = max(n, 4);
    if (world >= 4) n = max(n, 5);
    if (boss) n = min(n + 1, 7);
    return n;
  }

  void _applyMechanics(List<PotionBottle> bottles, int world, int id) {
    if (world >= 2 && id % 7 == 0) {
      final idx = bottles.indexWhere((b) => !b.isEmpty);
      if (idx >= 0) bottles[idx].locked = true;
    }
    if (world >= 2 && id % 5 == 0) {
      var placed = 0;
      final used = <Essence>{};
      for (final b in bottles.where((x) => !x.isEmpty)) {
        if (placed >= 2) break;
        if (b.layers.last.blocked) continue;
        final color = b.layers.last.essence;
        if (color.isSpecial || used.contains(color)) continue;
        var elsewhere = 0;
        var pourableElsewhere = 0;
        for (final other in bottles) {
          if (other.id == b.id) continue;
          for (final l in other.layers) {
            if (l.essence != color) continue;
            elsewhere++;
            if (!l.blocked) pourableElsewhere++;
          }
        }
        if (elsewhere < 1 || pourableElsewhere < 1 || elsewhere > b.capacity) {
          continue;
        }
        b.layers.last.crystal = true;
        used.add(color);
        placed++;
      }
    }
    if (world >= 4 && id % 4 == 0) {
      var placed = 0;
      for (var i = 0; i < bottles.length && placed < 2; i++) {
        final b = bottles[i];
        if (b.layers.length <= 1 || b.layers.last.blocked) continue;
        b.layers.last.frozen = true;
        placed++;
      }
    }
    if (world >= 5 && id % 8 == 0 && bottles.length >= 4) {
      bottles[0].portalTwin = bottles[1].id;
      bottles[1].portalTwin = bottles[0].id;
    }
    if (world >= 5 && id % 6 == 0) {
      final b = bottles.firstWhere(
        (x) => !x.isEmpty,
        orElse: () => bottles.first,
      );
      if (b.layers.isNotEmpty) b.layers.first.hidden = true;
    }
    if (world >= 3 && id % 9 == 0) {
      final empty = bottles.where((b) => b.isEmpty);
      if (empty.isNotEmpty) {
        empty.first.layers.add(PotionLayer(essence: Essence.poison));
      }
    }
    if (id % 11 == 0) {
      Essence? color;
      for (final b in bottles) {
        for (final l in b.layers) {
          if (!l.essence.isSpecial) {
            color = l.essence;
            break;
          }
        }
        if (color != null) break;
      }
      if (color != null) {
        final home = bottles.firstWhere(
          (b) => b.layers.any((l) => l.essence == color),
          orElse: () => bottles.first,
        );
        home.targetEssence = color;
      }
    }
  }

  List<LevelObjective> _objectives(
    int world,
    int id,
    List<PotionBottle> bottles,
    bool boss,
  ) {
    final list = <LevelObjective>[LevelObjective(kind: ObjectiveKind.sortAll)];
    if (id >= 5 && id % 4 == 0) {
      final color = bottles
          .expand((b) => b.layers)
          .map((l) => l.essence)
          .firstWhere((e) => !e.isSpecial, orElse: () => Essence.ember);
      final have = PotionBottle.countEssenceIn(bottles, color);
      if (have >= 4) {
        list.add(
          LevelObjective(
            kind: ObjectiveKind.collectColor,
            essence: color,
            target: 4,
          ),
        );
      }
    }
    if (bottles.any((b) => b.layers.any((l) => l.crystal))) {
      list.add(
        LevelObjective(
          kind: ObjectiveKind.breakCrystals,
          target: bottles.fold(
            0,
            (n, b) => n + b.layers.where((l) => l.crystal).length,
          ),
        ),
      );
    }
    if (bottles.any((b) => b.layers.any((l) => l.frozen))) {
      list.add(
        LevelObjective(
          kind: ObjectiveKind.breakFreeze,
          target: bottles.fold(
            0,
            (n, b) => n + b.layers.where((l) => l.frozen).length,
          ),
        ),
      );
    }
    if (bottles.any((b) => b.targetEssence != null)) {
      list.add(
        LevelObjective(
          kind: ObjectiveKind.targetBottle,
          essence: bottles
              .firstWhere((b) => b.targetEssence != null)
              .targetEssence,
        ),
      );
    }
    return list;
  }

  DifficultyBand _band(int world, int id, int minMoves, bool boss) {
    if (boss) return DifficultyBand.master;
    final score = world * 8 + minMoves + (id % 10);
    if (score < 18) return DifficultyBand.easy;
    if (score < 28) return DifficultyBand.normal;
    if (score < 40) return DifficultyBand.hard;
    if (score < 52) return DifficultyBand.expert;
    return DifficultyBand.master;
  }

  String _bossName(int world) {
    const names = [
      'The Grove Warden',
      'Castle Alchemist',
      'Chaos Ember Drake',
      'The Frost Binder',
      'Tide Archivist',
      'Cosmic Distiller',
    ];
    return names[world - 1];
  }

  String _fingerprint(List<PotionBottle> bottles) {
    final parts =
        bottles
            .map(
              (b) =>
                  '${b.locked ? 'L' : ''}${b.layers.map((l) => '${l.essence.name[0]}${l.crystal ? 'C' : ''}${l.frozen ? 'F' : ''}').join()}',
            )
            .toList()
          ..sort();
    return parts.join('|');
  }
}
