import 'potion_color.dart';

enum ObjectiveKind {
  sortAll,
  collectColor,
  breakCrystals,
  limitedMoves,
  createSpecials,
  breakFreeze,
  targetBottle,
  rainbow,
}

class LevelObjective {
  final ObjectiveKind kind;
  final Essence? essence;
  final int target;
  int progress;

  LevelObjective({
    required this.kind,
    this.essence,
    this.target = 1,
    this.progress = 0,
  });

  bool get done {
    if (kind == ObjectiveKind.limitedMoves) return true;
    return progress >= target;
  }

  String get label {
    switch (kind) {
      case ObjectiveKind.sortAll:
        return 'Brew every vial';
      case ObjectiveKind.collectColor:
        return 'Settle ${essence?.label ?? 'essence'} ×$target';
      case ObjectiveKind.breakCrystals:
        return 'Crack $target crystals';
      case ObjectiveKind.limitedMoves:
        return 'Finish in $target pours';
      case ObjectiveKind.createSpecials:
        return 'Forge $target spark elixirs';
      case ObjectiveKind.breakFreeze:
        return 'Thaw $target frost layers';
      case ObjectiveKind.targetBottle:
        return 'Fill the marked vial with ${essence?.label ?? 'essence'}';
      case ObjectiveKind.rainbow:
        return 'Weave $target prism drops';
    }
  }

  LevelObjective copy() => LevelObjective(
    kind: kind,
    essence: essence,
    target: target,
    progress: progress,
  );

  Map<String, dynamic> toJson() => {
    'k': kind.name,
    'e': essence?.name,
    't': target,
    'p': progress,
  };

  factory LevelObjective.fromJson(Map<String, dynamic> json) => LevelObjective(
    kind: ObjectiveKind.values.byName(json['k'] as String),
    essence: json['e'] == null
        ? null
        : Essence.values.byName(json['e'] as String),
    target: json['t'] as int? ?? 1,
    progress: json['p'] as int? ?? 0,
  );
}
