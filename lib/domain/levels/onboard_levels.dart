import '../generator/board_scrambler.dart';
import '../models/bottle.dart';
import '../models/layer.dart';
import '../models/level.dart';
import '../models/objectives.dart';
import '../models/potion_color.dart';
import '../rules/move_rules.dart';

PotionBottle _b(
  int id,
  List<Essence> colors, {
  bool locked = false,
  Essence? target,
  bool crystalTop = false,
}) {
  final layers = colors.map((e) => PotionLayer(essence: e)).toList();
  if (crystalTop && layers.isNotEmpty) {
    layers.last.crystal = true;
  }
  return PotionBottle(
    id: id,
    capacity: 4,
    locked: locked,
    targetEssence: target,
    layers: layers,
  );
}

List<LevelDefinition> onboardLevels() {
  Essence e(int i) => playableEssences[i];
  return [
    LevelDefinition(
      id: 1,
      world: 1,
      name: 'First Pour',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(0), e(0)]),
        _b(1, [e(0)]),
        _b(2, []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 1,
      maxMoves: MoveRules.budget(1, id: 1),
      difficulty: DifficultyBand.easy,
      tutorial: 'Tap a vial, then tap another. Matching essence flows.',
      fingerprint: 'l1',
    ),
    LevelDefinition(
      id: 2,
      world: 1,
      name: 'Kindred Hues',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(1), e(0)]),
        _b(1, [e(1), e(0), e(1)]),
        _b(2, [e(0)]),
        _b(3, [e(1)]),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 6,
      maxMoves: MoveRules.budget(6, id: 2),
      difficulty: DifficultyBand.easy,
      tutorial:
          'Only the top color pours — and only onto a match or empty glass.',
      fingerprint: 'l2',
    ),
    LevelDefinition(
      id: 3,
      world: 1,
      name: 'Spare Glass',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(1), e(0), e(1)]),
        _b(1, [e(1), e(0), e(1), e(0)]),
        _b(2, []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 7,
      maxMoves: MoveRules.budget(7, id: 3),
      difficulty: DifficultyBand.easy,
      tutorial: 'Empty glass is a workbench. Park a color, free a path.',
      fingerprint: 'l3',
    ),
    LevelDefinition(
      id: 4,
      world: 1,
      name: 'Take It Back',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(1), e(2)]),
        _b(1, [e(2), e(0), e(1)]),
        _b(2, [e(1), e(2), e(0)]),
        _b(3, []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 7,
      maxMoves: MoveRules.budget(7, id: 4),
      difficulty: DifficultyBand.easy,
      tutorial: 'Rewind sits below. A pour is never permanent.',
      fingerprint: 'l4',
    ),
    LevelDefinition(
      id: 5,
      world: 1,
      name: 'Ember Tithe',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(0), e(1)]),
        _b(1, [e(1), e(0), e(0)]),
        _b(2, [e(1), e(1)]),
        _b(3, []),
      ],
      objectives: [
        LevelObjective(kind: ObjectiveKind.sortAll),
        LevelObjective(
          kind: ObjectiveKind.collectColor,
          essence: e(0),
          target: 4,
        ),
      ],
      estimatedMinMoves: 3,
      maxMoves: MoveRules.budget(3, id: 5),
      difficulty: DifficultyBand.easy,
      tutorial: 'Settle a full Ember vial to complete the extra goal.',
      fingerprint: 'l5',
    ),
    LevelDefinition(
      id: 6,
      world: 1,
      name: 'Quiet Coins',
      capacity: 4,
      bottles: [
        _b(0, [e(1), e(0), e(1), e(0)]),
        _b(1, [e(0), e(1), e(0), e(1)]),
        _b(2, []),
        _b(3, []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 7,
      maxMoves: MoveRules.budget(7, id: 6),
      difficulty: DifficultyBand.easy,
      tutorial:
          'Stars and coins follow a clean brew. Replay later for mastery.',
      fingerprint: 'l6',
    ),
    LevelDefinition(
      id: 7,
      world: 1,
      name: 'A Whisper',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(2), e(1)]),
        _b(1, [e(2), e(1), e(0)]),
        _b(2, [e(1), e(0), e(2)]),
        _b(3, []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 7,
      maxMoves: MoveRules.budget(7, id: 7),
      difficulty: DifficultyBand.easy,
      tutorial: 'Hint glows a useful pour — never a random one.',
      fingerprint: 'l7',
    ),
    LevelDefinition(
      id: 8,
      world: 1,
      name: 'First Knot',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(1), e(2), e(0)]),
        _b(1, [e(1), e(2), e(0), e(1)]),
        _b(2, [e(2), e(0), e(1), e(2)]),
        _b(3, []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 10,
      maxMoves: MoveRules.budget(10, id: 8),
      difficulty: DifficultyBand.normal,
      fingerprint: 'l8',
    ),
    LevelDefinition(
      id: 9,
      world: 1,
      name: 'Four Voices',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(3), e(1)]),
        _b(1, [e(1), e(0), e(3)]),
        _b(2, [e(3), e(1), e(0)]),
        _b(3, [e(0), e(1), e(3)]),
        _b(4, []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 9,
      maxMoves: MoveRules.budget(9, id: 9),
      difficulty: DifficultyBand.normal,
      fingerprint: 'l9',
    ),
    LevelDefinition(
      id: 10,
      world: 1,
      name: 'Grove Trial',
      capacity: 4,
      bottles: [
        _b(0, [e(0), e(1), e(2), e(3)]),
        _b(1, [e(3), e(2), e(1), e(0)]),
        _b(2, [e(1), e(0), e(3), e(2)]),
        _b(3, [e(2), e(3), e(0), e(1)]),
        _b(4, []),
        _b(5, []),
      ],
      objectives: [LevelObjective(kind: ObjectiveKind.sortAll)],
      estimatedMinMoves: 14,
      maxMoves: MoveRules.budget(14, id: 10),
      difficulty: DifficultyBand.normal,
      fingerprint: 'l10',
    ),
    ...List.generate(10, (i) {
      final id = 11 + i;
      final colorCount = id < 14 ? 3 : 4;
      final bottles = id == 16
          ? _crystalLesson()
          : _brew(id, colors: colorCount, empties: 2, mixes: 18 + i * 2);
      // Proven BFS par for this seed — not a runtime guess.
      const grovePar = [5, 7, 4, 6, 8, 4, 8, 8, 8, 6];
      final par = grovePar[i];
      return LevelDefinition(
        id: id,
        world: 1,
        name: id == 16
            ? 'Crystal Lesson'
            : id == 20
            ? 'Forest Gate'
            : 'Grove $id',
        capacity: 4,
        bottles: bottles,
        objectives: [
          LevelObjective(kind: ObjectiveKind.sortAll),
          if (PotionBottle.countEssenceIn(bottles, e(0)) >= 4)
            LevelObjective(
              kind: ObjectiveKind.collectColor,
              essence: e(0),
              target: 4,
            ),
          if (bottles.any((b) => b.layers.any((l) => l.crystal)))
            LevelObjective(kind: ObjectiveKind.breakCrystals, target: 1),
        ],
        estimatedMinMoves: par,
        maxMoves: MoveRules.budget(par, id: id),
        difficulty: id >= 18 ? DifficultyBand.normal : DifficultyBand.easy,
        tutorial: id == 16
            ? 'The marked lid is crystal — gather the rest of that color in another vial and it cracks.'
            : id == 12
            ? 'An extra vial can be summoned if you need workspace.'
            : null,
        fingerprint: 'l$id',
      );
    }),
  ];
}

/// Reverse-shuffle from solved vials so color counts stay exact.
List<PotionBottle> _brew(
  int id, {
  required int colors,
  required int empties,
  int mixes = 24,
}) {
  return BoardScrambler.fromSolved(
    colors: colors,
    empties: empties,
    capacity: 4,
    pours: mixes,
    seed: 44000 + id * 31,
  );
}

/// Crystal lesson: moss lid over sun drops. The other three moss sit on top
/// of their own vials — stack them and the lid cracks, freeing the yellow.
List<PotionBottle> _crystalLesson() {
  Essence e(int i) => playableEssences[i];
  return [
    _b(0, [e(3), e(3), e(2)], crystalTop: true),
    _b(1, [e(2)]),
    _b(2, [e(2)]),
    _b(3, [e(2)]),
    _b(4, [e(3), e(3)]),
    _b(5, []),
  ];
}
