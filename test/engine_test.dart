import 'package:flutter_test/flutter_test.dart' hide EnginePhase;
import 'package:potion_sort/domain/engine/puzzle_engine.dart';
import 'package:potion_sort/domain/levels/level_catalog.dart';
import 'package:potion_sort/domain/levels/onboard_levels.dart';
import 'package:potion_sort/domain/models/bottle.dart';
import 'package:potion_sort/domain/models/layer.dart';
import 'package:potion_sort/domain/models/level.dart';
import 'package:potion_sort/domain/models/objectives.dart';
import 'package:potion_sort/domain/models/potion_color.dart';

void main() {
  test('level 1 is one legal pour from solved', () {
    final engine = PuzzleEngine(onboardLevels().first);
    expect(engine.canPour(1, 0), isTrue);
    engine.applyPour(1, 0);
    expect(engine.phase, EnginePhase.levelComplete);
    expect(engine.moves, 1);
  });

  test('illegal pour is rejected', () {
    final engine = PuzzleEngine(LevelCatalog.load(2));
    expect(engine.canPour(0, 1), isFalse);
  });

  test('tap returns the resolved portal destination once', () {
    final level = LevelDefinition(
      id: 99,
      world: 2,
      name: 'Portal',
      capacity: 4,
      bottles: [
        PotionBottle(
          id: 0,
          capacity: 4,
          layers: [
            PotionLayer(essence: Essence.moss),
            PotionLayer(essence: Essence.ember),
          ],
        ),
        PotionBottle(id: 1, capacity: 4, layers: [], portalTwin: 2),
        PotionBottle(id: 2, capacity: 4, layers: []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      maxMoves: 2,
      estimatedMinMoves: 1,
      difficulty: DifficultyBand.normal,
      fingerprint: 'portal',
    );
    final engine = PuzzleEngine(level);
    expect(engine.tap(0), isNull);
    final move = engine.tap(1);
    expect(move?.from, 0);
    expect(move?.to, 2);
    expect(move?.count, 1);
    expect(engine.bottles[1].isEmpty, isTrue);
    expect(engine.bottles[2].layers, hasLength(1));
  });

  test('undo restores bottles', () {
    final engine = PuzzleEngine(LevelCatalog.load(1));
    engine.applyPour(1, 0);
    expect(engine.undo(), isTrue);
    expect(engine.moves, 0);
    expect(engine.bottles[1].layers, isNotEmpty);
  });

  test('rainbow booster is not consumed or undoable on a full board', () {
    final level = LevelDefinition(
      id: 98,
      world: 2,
      name: 'Full',
      capacity: 1,
      bottles: [
        PotionBottle(
          id: 0,
          capacity: 1,
          layers: [PotionLayer(essence: Essence.ember)],
        ),
        PotionBottle(
          id: 1,
          capacity: 1,
          layers: [PotionLayer(essence: Essence.moss)],
        ),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      maxMoves: 1,
      estimatedMinMoves: 1,
      difficulty: DifficultyBand.normal,
      fingerprint: 'full',
    );
    final engine = PuzzleEngine(level);
    expect(engine.addRainbow(), isFalse);
    expect(engine.rainbows, 0);
    expect(engine.undo(), isFalse);
  });

  test('catalog serves 300 ids', () {
    final a = LevelCatalog.load(21);
    final b = LevelCatalog.load(21);
    expect(a.fingerprint, b.fingerprint);
    expect(LevelCatalog.load(300).world, 6);
    expect(playableEssences.length, greaterThanOrEqualTo(6));
  });

  test(
    'crystal lid is not pourable until the rest of that color is gathered',
    () {
      final engine = PuzzleEngine(LevelCatalog.load(16));
      expect(engine.bottles[0].top?.crystal, isTrue);
      expect(engine.canPour(0, 4), isFalse);

      engine.applyPour(1, 2);
      expect(engine.bottles[0].top?.crystal, isTrue);

      engine.applyPour(3, 2);
      expect(
        engine.bottles[0].top?.crystal,
        isFalse,
        reason: 'lid must crack once the other moss is stacked',
      );
      expect(engine.canPour(0, 2), isTrue);

      engine.applyPour(0, 2);
      engine.applyPour(0, 4);
      expect(engine.phase, EnginePhase.levelComplete);
    },
  );

  test('engine uses the shared blocker pipeline to thaw frost', () {
    final level = LevelDefinition(
      id: 97,
      world: 4,
      name: 'Frost',
      capacity: 2,
      bottles: [
        PotionBottle(
          id: 0,
          capacity: 2,
          layers: [PotionLayer(essence: Essence.ember)],
        ),
        PotionBottle(
          id: 1,
          capacity: 2,
          layers: [PotionLayer(essence: Essence.moss, frozen: true)],
        ),
        PotionBottle(
          id: 2,
          capacity: 2,
          layers: [
            PotionLayer(essence: Essence.moss),
            PotionLayer(essence: Essence.ember),
          ],
        ),
      ],
      objectives: [
        LevelObjective(kind: ObjectiveKind.sortAll),
        LevelObjective(kind: ObjectiveKind.breakFreeze, target: 1),
      ],
      maxMoves: 3,
      estimatedMinMoves: 2,
      difficulty: DifficultyBand.hard,
      fingerprint: 'frost',
    );
    final engine = PuzzleEngine(level);

    engine.applyPour(2, 0);

    expect(engine.bottles[1].top?.frozen, isFalse);
    expect(engine.frostThawed, 1);
    expect(
      engine.objectives
          .firstWhere((o) => o.kind == ObjectiveKind.breakFreeze)
          .progress,
      1,
    );
  });
}
