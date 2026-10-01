/// How many pours a vial allows, and how those pours turn into stars.
///
/// Candy Crush at scale: the editor (our solver) finds par, the level file
/// stores the fail ceiling, live play only counts down that integer.
///
/// 3★ = par (no wasted pour).
/// 2★ = used some of the spare, but not the last pour.
/// 1★ = finished on the last pour.
/// 0  = over the ceiling (the engine fails the vial).
class MoveRules {
  static int threeStar(int par) => par.clamp(1, 99);

  /// Spare pours beyond par. One mistake in a sort puzzle costs ~2 pours;
  /// more than that is a loose clock, not tension.
  static int waste(int par, {required int id, bool boss = false}) {
    if (id <= 1) return 0;
    if (id <= 3) return 1;
    if (boss) return 1;
    if (id <= 8) return 2;
    return par <= 8 ? 1 : 2;
  }

  static int twoStar(int par, {required int cap}) {
    if (cap <= par + 1) return par;
    return par + 1;
  }

  /// Fail ceiling baked into [LevelDefinition.maxMoves] at authoring.
  static int budget(int par, {required int id, bool boss = false}) {
    final p = par.clamp(1, 99);
    return (p + waste(p, id: id, boss: boss)).clamp(p, 99);
  }

  static int limitFor({
    int? maxMoves,
    required int estimatedMinMoves,
    required int id,
    bool boss = false,
  }) => maxMoves ?? budget(estimatedMinMoves, id: id, boss: boss);

  static int remaining(int moves, int cap) => (cap - moves).clamp(0, 99);

  static int starsFor(
    int moves, {
    required int estimatedMinMoves,
    required int cap,
  }) {
    if (moves > cap) return 0;
    if (moves <= threeStar(estimatedMinMoves)) return 3;
    if (moves < cap) return 2;
    return 1;
  }
}
