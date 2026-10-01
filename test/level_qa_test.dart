import 'package:flutter_test/flutter_test.dart';
import 'package:potion_sort/domain/levels/level_catalog.dart';
import 'package:potion_sort/domain/levels/level_qa.dart';
import 'package:potion_sort/domain/levels/onboard_levels.dart';
import 'package:potion_sort/domain/models/bottle.dart';
import 'package:potion_sort/domain/models/layer.dart';
import 'package:potion_sort/domain/models/level.dart';
import 'package:potion_sort/domain/models/objectives.dart';
import 'package:potion_sort/domain/models/potion_color.dart';
import 'package:potion_sort/domain/rules/pour_rules.dart';

List<PotionLayer> _stack(Essence e, int n) =>
    List.generate(n, (_) => PotionLayer(essence: e));

void main() {
  test('rejects leftover extra drops (the level 11 bug)', () {
    final bottles = [
      PotionBottle(id: 0, capacity: 4, layers: _stack(Essence.ember, 4)),
      PotionBottle(id: 1, capacity: 4, layers: _stack(Essence.ember, 1)),
      PotionBottle(id: 2, capacity: 4, layers: _stack(Essence.moss, 2)),
      PotionBottle(id: 3, capacity: 4, layers: _stack(Essence.moss, 3)),
      PotionBottle(id: 4, capacity: 4, layers: _stack(Essence.azure, 4)),
      PotionBottle(id: 5, capacity: 4, layers: []),
    ];
    expect(LevelQa.bottlesValid(bottles, 4), isFalse);
    expect(LevelQa.layoutProblems(bottles, 4).join(' '), contains('ember'));
    expect(bottles[0].isCompleteColor(bottles), isFalse);
    expect(bottles[4].isCompleteColor(bottles), isTrue);
  });

  test('a full vial corks only when every drop of that color fits', () {
    final exact = [
      PotionBottle(id: 0, capacity: 4, layers: _stack(Essence.ember, 4)),
      PotionBottle(id: 1, capacity: 4, layers: []),
    ];
    expect(exact[0].isCompleteColor(exact), isTrue);
    expect(LevelQa.bottlesValid(exact, 4), isTrue);

    final leftover = [
      PotionBottle(id: 0, capacity: 4, layers: _stack(Essence.ember, 4)),
      PotionBottle(id: 1, capacity: 4, layers: _stack(Essence.ember, 1)),
      PotionBottle(id: 2, capacity: 4, layers: []),
    ];
    expect(leftover[0].isCompleteColor(leftover), isFalse);
    expect(leftover[1].isCompleteColor(leftover), isFalse);
  });

  test('two sealed vials of the same color are both complete', () {
    final bottles = [
      PotionBottle(id: 0, capacity: 4, layers: _stack(Essence.ember, 4)),
      PotionBottle(id: 1, capacity: 4, layers: _stack(Essence.ember, 4)),
      PotionBottle(id: 2, capacity: 4, layers: []),
    ];
    expect(bottles[0].isCompleteColor(bottles), isTrue);
    expect(bottles[1].isCompleteColor(bottles), isTrue);
    expect(LevelQa.bottlesValid(bottles, 4), isTrue);
  });

  test('tutorial partial vial corks when it holds every drop', () {
    final bottles = [
      PotionBottle(id: 0, capacity: 4, layers: _stack(Essence.ember, 3)),
      PotionBottle(id: 1, capacity: 4, layers: []),
    ];
    expect(bottles[0].isCompleteColor(bottles), isTrue);
    expect(LevelQa.bottlesValid(bottles, 4), isTrue);
  });

  test('every onboard level including vial 11 has legal color counts', () {
    for (final level in onboardLevels()) {
      expect(
        LevelQa.problems(level),
        isEmpty,
        reason: 'level ${level.id}: ${LevelQa.problems(level).join('; ')}',
      );
    }
  });

  test('level 11 has exactly four drops of each playable color', () {
    final level = LevelCatalog.load(11);
    expect(LevelQa.isValid(level), isTrue);
    final counts = <Essence, int>{};
    for (final b in level.bottles) {
      for (final layer in b.layers) {
        if (layer.essence.isSpecial) continue;
        counts[layer.essence] = (counts[layer.essence] ?? 0) + 1;
      }
    }
    expect(counts.values, isNotEmpty);
    for (final entry in counts.entries) {
      expect(
        entry.value,
        4,
        reason: '${entry.key.name} has ${entry.value} drops',
      );
    }
  });

  test('the release ship door rejects a layout-valid stale par', () {
    final original = onboardLevels().firstWhere((level) => level.id == 2);
    final stale = LevelDefinition(
      id: original.id,
      world: original.world,
      name: original.name,
      capacity: original.capacity,
      bottles: original.bottles.map((b) => b.copy()).toList(),
      objectives: original.objectives.map((o) => o.copy()).toList(),
      maxMoves: original.maxMoves,
      estimatedMinMoves: 1,
      difficulty: original.difficulty,
      tutorial: original.tutorial,
      boss: original.boss,
      fingerprint: original.fingerprint,
    );

    expect(LevelQa.isValid(stale), isTrue);
    expect(() => LevelQa.certify(stale), throwsStateError);
    expect(() => LevelCatalog.adopt(stale), throwsStateError);
  });

  test('crystal with no drops elsewhere is a deadlock', () {
    final bottles = [
      PotionBottle(
        id: 0,
        capacity: 4,
        layers: [
          PotionLayer(essence: Essence.sun),
          PotionLayer(essence: Essence.moss, crystal: true),
        ],
      ),
      PotionBottle(id: 1, capacity: 4, layers: _stack(Essence.ember, 4)),
      PotionBottle(id: 2, capacity: 4, layers: []),
    ];
    expect(
      LevelQa.layoutProblems(bottles, 4).join(' '),
      contains('crystal moss'),
    );
  });

  test('catalog levels keep legal color counts', () {
    for (final id in [1, 5, 11, 16, 20, 21, 50]) {
      final level = LevelCatalog.load(id);
      expect(
        LevelQa.problems(level),
        isEmpty,
        reason: 'level $id: ${LevelQa.problems(level).join('; ')}',
      );
    }
  });

  test('marked vial rejects the wrong color and false homes do not cork', () {
    final marked = PotionBottle(
      id: 0,
      capacity: 4,
      layers: [],
      targetEssence: Essence.moss,
    );
    final mossHome = PotionBottle(
      id: 1,
      capacity: 4,
      layers: _stack(Essence.moss, 4),
    );
    final ember = PotionBottle(
      id: 2,
      capacity: 4,
      layers: _stack(Essence.ember, 1),
    );
    final empty = PotionBottle(id: 3, capacity: 4, layers: []);
    final bottles = [marked, mossHome, ember, empty];

    expect(mossHome.isCompleteColor(bottles), isFalse);
    expect(PourRules.canPour(bottles, 2, 0), isFalse);
    expect(PourRules.canPour(bottles, 1, 0), isTrue);
  });

  test('level 22 is proven solvable', () {
    final level = LevelCatalog.load(22);
    expect(LevelQa.isValid(level), isTrue);
    expect(
      LevelQa.playableProblems(level),
      isEmpty,
      reason: LevelQa.playableProblems(level).join('; '),
    );
    expect(level.bottles.any((b) => b.targetEssence != null), isTrue);
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('a fully sorted board is rejected as already won', () {
    final level = LevelDefinition(
      id: 31,
      world: 1,
      name: 'pre-solved',
      capacity: 4,
      bottles: [
        PotionBottle(id: 0, capacity: 4, layers: _stack(Essence.ember, 4)),
        PotionBottle(id: 1, capacity: 4, layers: _stack(Essence.azure, 4)),
        PotionBottle(id: 2, capacity: 4, layers: []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 0,
      difficulty: DifficultyBand.easy,
      fingerprint: 'sorted',
    );
    expect(LevelQa.problems(level).join(' '), contains('already sorted'));
  });

  test('a corked vial at start is rejected', () {
    final level = LevelDefinition(
      id: 21,
      world: 1,
      name: 'pre-corked',
      capacity: 4,
      bottles: [
        PotionBottle(id: 0, capacity: 4, layers: _stack(Essence.ember, 4)),
        PotionBottle(
          id: 1,
          capacity: 4,
          layers: [
            PotionLayer(essence: Essence.azure),
            PotionLayer(essence: Essence.moss),
          ],
        ),
        PotionBottle(
          id: 2,
          capacity: 4,
          layers: [
            PotionLayer(essence: Essence.moss),
            PotionLayer(essence: Essence.azure),
          ],
        ),
        PotionBottle(id: 3, capacity: 4, layers: []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 4,
      difficulty: DifficultyBand.easy,
      fingerprint: 'corked',
    );
    expect(LevelQa.problems(level).join(' '), contains('already finished'));
  });

  test(
    'generated vials do not start corked',
    () {
      for (final id in [21, 31, 37]) {
        final level = LevelCatalog.load(id);
        expect(
          level.bottles.any(
            (b) => !b.isEmpty && b.isCompleteColor(level.bottles),
          ),
          isFalse,
          reason: 'level $id has a pre-finished vial',
        );
        expect(
          LevelQa.problems(level),
          isEmpty,
          reason: 'level $id: ${LevelQa.problems(level).join('; ')}',
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'level 31 is shuffled, not pre-solved',
    () {
      final level = LevelCatalog.load(31);
      expect(
        level.bottles.every((b) => b.isEmpty || b.isSorted(level.bottles)),
        isFalse,
      );
      expect(
        LevelQa.playableProblems(level),
        isEmpty,
        reason: LevelQa.playableProblems(level).join('; '),
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('every onboard vial is playable', () {
    for (final level in onboardLevels()) {
      final problems = LevelQa.playableProblems(level);
      expect(
        problems,
        isEmpty,
        reason: 'level ${level.id}: ${problems.join('; ')}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'sample generated vials are playable',
    () {
      for (final id in [21, 22, 33]) {
        final level = LevelCatalog.load(id);
        final problems = LevelQa.playableProblems(level);
        expect(problems, isEmpty, reason: 'level $id: ${problems.join('; ')}');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
