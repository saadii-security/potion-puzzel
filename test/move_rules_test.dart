import 'package:flutter_test/flutter_test.dart' hide EnginePhase;
import 'package:potion_sort/domain/engine/puzzle_engine.dart';
import 'package:potion_sort/domain/levels/level_qa.dart';
import 'package:potion_sort/domain/levels/onboard_levels.dart';
import 'package:potion_sort/domain/models/bottle.dart';
import 'package:potion_sort/domain/models/layer.dart';
import 'package:potion_sort/domain/models/level.dart';
import 'package:potion_sort/domain/models/objectives.dart';
import 'package:potion_sort/domain/models/potion_color.dart';
import 'package:potion_sort/domain/rules/move_rules.dart';

LevelDefinition _vial({
  required int id,
  required List<PotionBottle> bottles,
  int? maxMoves,
  int min = 1,
  bool boss = false,
}) => LevelDefinition(
  id: id,
  world: 1,
  name: 'vial',
  capacity: 4,
  bottles: bottles,
  objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
  maxMoves: maxMoves,
  estimatedMinMoves: min,
  difficulty: DifficultyBand.easy,
  boss: boss,
  fingerprint: 'moves',
);

void main() {
  test('pour cap is par plus at most two spares, baked not guessed', () {
    const par = 10;
    expect(MoveRules.threeStar(par), 10);
    expect(MoveRules.waste(par, id: 20), 2);
    final cap = MoveRules.budget(par, id: 20);
    expect(cap, 12);
    expect(MoveRules.starsFor(10, estimatedMinMoves: par, cap: cap), 3);
    expect(MoveRules.starsFor(11, estimatedMinMoves: par, cap: cap), 2);
    expect(MoveRules.starsFor(12, estimatedMinMoves: par, cap: cap), 1);
    expect(MoveRules.starsFor(13, estimatedMinMoves: par, cap: cap), 0);
  });

  test('first vial is exact; bosses are tighter than mid-grove', () {
    expect(MoveRules.budget(1, id: 1), 1);
    expect(
      MoveRules.budget(10, id: 6),
      greaterThan(MoveRules.budget(10, id: 50, boss: true)),
    );
  });

  test('onboard vials ship a baked cap next to proven par', () {
    for (final level in onboardLevels()) {
      expect(level.maxMoves, isNotNull, reason: 'vial ${level.id} has no cap');
      expect(
        level.maxMoves,
        level.estimatedMinMoves +
            MoveRules.waste(level.estimatedMinMoves, id: level.id),
      );
    }
    expect(onboardLevels().first.maxMoves, 1);
    final crystal = onboardLevels().firstWhere((l) => l.id == 16);
    expect(crystal.estimatedMinMoves, 4);
    expect(crystal.maxMoves, 5);
  });

  test('winning on the last pour still completes', () {
    final onboard = onboardLevels().first;
    final engine = PuzzleEngine(
      _vial(
        id: 1,
        bottles: onboard.bottles.map((b) => b.copy()).toList(),
        maxMoves: 1,
        min: 1,
      ),
    );
    engine.applyPour(1, 0);
    expect(engine.phase, EnginePhase.levelComplete);
    expect(engine.level.starsFor(engine.moves), 3);
  });

  test('spending the last pour without a win fails', () {
    final onboard = onboardLevels().first;
    final engine = PuzzleEngine(
      _vial(
        id: 1,
        bottles: onboard.bottles.map((b) => b.copy()).toList(),
        maxMoves: 1,
        min: 1,
      ),
    );
    engine.applyPour(1, 2);
    expect(engine.phase, EnginePhase.levelFailed);
    expect(engine.failReason, contains('pours'));
  });

  test('QA rejects a proven solution longer than the budget', () {
    final level = _vial(
      id: 9,
      bottles: [
        PotionBottle(
          id: 0,
          capacity: 4,
          layers: [
            PotionLayer(essence: Essence.ember),
            PotionLayer(essence: Essence.moss),
          ],
        ),
        PotionBottle(
          id: 1,
          capacity: 4,
          layers: [
            PotionLayer(essence: Essence.moss),
            PotionLayer(essence: Essence.ember),
          ],
        ),
        PotionBottle(id: 2, capacity: 4, layers: []),
      ],
      maxMoves: 1,
      min: 1,
    );
    expect(LevelQa.playableProblems(level).join(' '), contains('budget'));
  });
}
