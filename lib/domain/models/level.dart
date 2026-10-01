import '../rules/move_rules.dart';
import 'bottle.dart';
import 'objectives.dart';

enum DifficultyBand { easy, normal, hard, expert, master }

class LevelDefinition {
  final int id;
  final int world;
  final String name;
  final int capacity;
  final List<PotionBottle> bottles;
  final List<LevelObjective> objectives;
  final int? maxMoves;
  final int estimatedMinMoves;
  final DifficultyBand difficulty;
  final String? tutorial;
  final bool boss;
  final String fingerprint;

  const LevelDefinition({
    required this.id,
    required this.world,
    required this.name,
    required this.capacity,
    required this.bottles,
    required this.objectives,
    this.maxMoves,
    required this.estimatedMinMoves,
    required this.difficulty,
    this.tutorial,
    this.boss = false,
    required this.fingerprint,
  });

  int get threeStarMoves => MoveRules.threeStar(estimatedMinMoves);
  int get twoStarMoves => MoveRules.twoStar(estimatedMinMoves, cap: moveBudget);
  int get moveBudget => MoveRules.limitFor(
    maxMoves: maxMoves,
    estimatedMinMoves: estimatedMinMoves,
    id: id,
    boss: boss,
  );

  int starsFor(int moves) => MoveRules.starsFor(
    moves,
    estimatedMinMoves: estimatedMinMoves,
    cap: moveBudget,
  );

  LevelDefinition copyWithBottles(List<PotionBottle> next) => LevelDefinition(
    id: id,
    world: world,
    name: name,
    capacity: capacity,
    bottles: next,
    objectives: objectives.map((o) => o.copy()).toList(),
    maxMoves: maxMoves,
    estimatedMinMoves: estimatedMinMoves,
    difficulty: difficulty,
    tutorial: tutorial,
    boss: boss,
    fingerprint: fingerprint,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'world': world,
    'name': name,
    'cap': capacity,
    'bottles': bottles.map((b) => b.toJson()).toList(),
    'objectives': objectives.map((o) => o.toJson()).toList(),
    'maxMoves': maxMoves,
    'min': estimatedMinMoves,
    'diff': difficulty.name,
    'tutorial': tutorial,
    'boss': boss,
    'fp': fingerprint,
    'v': 1,
  };

  factory LevelDefinition.fromJson(Map<String, dynamic> json) =>
      LevelDefinition(
        id: json['id'] as int,
        world: json['world'] as int,
        name: json['name'] as String,
        capacity: json['cap'] as int,
        bottles: (json['bottles'] as List)
            .map(
              (e) => PotionBottle.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        objectives: (json['objectives'] as List)
            .map(
              (e) =>
                  LevelObjective.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        maxMoves: json['maxMoves'] as int?,
        estimatedMinMoves: json['min'] as int? ?? 8,
        difficulty: DifficultyBand.values.byName(
          json['diff'] as String? ?? 'normal',
        ),
        tutorial: json['tutorial'] as String?,
        boss: json['boss'] == true,
        fingerprint: json['fp'] as String? ?? '',
      );
}
