import '../models/bottle.dart';
import '../models/layer.dart';
import '../models/level.dart';
import '../models/objectives.dart';
import '../models/potion_color.dart';
import '../rules/blocker_rules.dart';
import '../rules/pour_rules.dart';
import '../rules/win_rules.dart';

enum EnginePhase { idle, selectingSource, pouring, levelComplete, levelFailed }

class PourMove {
  final int from;
  final int to;
  final int count;
  final Essence essence;
  PourMove(this.from, this.to, this.count, this.essence);
}

class PuzzleSnapshot {
  final List<PotionBottle> bottles;
  final List<LevelObjective> objectives;
  final int moves;
  final int combo;
  final int specialsForged;
  final int crystalsBroken;
  final int frostThawed;
  final int collected;
  final int rainbows;
  PuzzleSnapshot({
    required this.bottles,
    required this.objectives,
    required this.moves,
    required this.combo,
    required this.specialsForged,
    required this.crystalsBroken,
    required this.frostThawed,
    required this.collected,
    required this.rainbows,
  });
}

class PuzzleEngine {
  LevelDefinition level;
  late List<PotionBottle> bottles;
  late List<LevelObjective> objectives;
  EnginePhase phase = EnginePhase.idle;
  int? selected;
  int moves = 0;
  int combo = 0;
  int specialsForged = 0;
  int crystalsBroken = 0;
  int frostThawed = 0;
  int collected = 0;
  int rainbows = 0;
  String? failReason;
  final List<PuzzleSnapshot> _undo = [];

  PuzzleEngine(this.level) {
    reset();
  }

  void reset() {
    bottles = level.bottles.map((b) => b.copy()).toList();
    objectives = level.objectives.map((o) => o.copy()).toList();
    phase = EnginePhase.idle;
    selected = null;
    moves = 0;
    combo = 0;
    specialsForged = 0;
    crystalsBroken = 0;
    frostThawed = 0;
    collected = 0;
    rainbows = 0;
    failReason = null;
    _undo.clear();
    _revealTops();
  }

  PotionBottle bottle(int i) => bottles[i];

  bool get isWon =>
      phase == EnginePhase.levelComplete ||
      WinRules.meetsWin(bottles, objectives);

  PourMove? tap(int index) {
    if (phase == EnginePhase.levelComplete ||
        phase == EnginePhase.levelFailed) {
      return null;
    }
    if (index < 0 || index >= bottles.length) return null;
    if (bottles[index].locked) return null;

    if (selected == null) {
      if (bottles[index].isEmpty || bottles[index].top?.blocked == true) {
        return null;
      }
      if (bottles[index].isCompleteColor(bottles)) return null;
      selected = index;
      phase = EnginePhase.selectingSource;
      return null;
    }
    if (selected == index) {
      selected = null;
      phase = EnginePhase.idle;
      return null;
    }
    final from = selected!;
    if (!canPour(from, index)) {
      if (!bottles[index].isEmpty && bottles[index].top?.blocked != true) {
        selected = index;
      }
      return null;
    }
    return applyPour(from, index);
  }

  bool canPour(int from, int to) => PourRules.canPour(bottles, from, to);

  PourMove? applyPour(int from, int to) {
    if (!canPour(from, to)) return null;
    _pushUndo();
    final destIndex = PourRules.resolveDest(bottles, to);
    final color = bottles[from].top!.essence;
    final moving = PourRules.pour(bottles, from, to);
    if (moving <= 0) {
      _undo.removeLast();
      return null;
    }
    moves += 1;
    selected = null;
    phase = EnginePhase.idle;
    _afterPour(from, destIndex, moving, color);
    _checkEnd();
    return PourMove(from, destIndex, moving, color);
  }

  List<int>? hintMove() {
    for (var i = 0; i < bottles.length; i++) {
      for (var j = 0; j < bottles.length; j++) {
        if (!canPour(i, j)) continue;
        final a = bottles[i];
        final b = bottles[j];
        if (b.isEmpty && a.topRun() == a.layers.length) continue;
        if (!b.isEmpty && a.topEssence == b.topEssence) return [i, j];
      }
    }
    for (var i = 0; i < bottles.length; i++) {
      for (var j = 0; j < bottles.length; j++) {
        if (canPour(i, j)) return [i, j];
      }
    }
    return null;
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final snap = _undo.removeLast();
    bottles = snap.bottles;
    objectives = snap.objectives;
    moves = snap.moves;
    combo = snap.combo;
    specialsForged = snap.specialsForged;
    crystalsBroken = snap.crystalsBroken;
    frostThawed = snap.frostThawed;
    collected = snap.collected;
    rainbows = snap.rainbows;
    selected = null;
    phase = EnginePhase.idle;
    failReason = null;
    return true;
  }

  void addExtraBottle() {
    _pushUndo();
    final id = bottles.fold<int>(0, (m, b) => b.id > m ? b.id : m) + 1;
    bottles.add(
      PotionBottle(id: id, capacity: level.capacity, layers: [], extra: true),
    );
  }

  void clearBottle(int index) {
    if (index < 0 || index >= bottles.length) return;
    _pushUndo();
    bottles[index].layers.clear();
    bottles[index].locked = false;
    _refreshObjectives();
    _checkEnd();
  }

  void colorBlast(Essence color) {
    _pushUndo();
    for (final b in bottles) {
      while (b.top != null && !b.top!.blocked && b.top!.essence == color) {
        b.layers.removeLast();
        collected += 1;
      }
    }
    _revealTops();
    _refreshObjectives();
    _checkEnd();
  }

  bool addRainbow() {
    final empty = bottles.indexWhere((b) => !b.isFull && !b.locked);
    if (empty < 0) return false;
    _pushUndo();
    bottles[empty].layers.add(PotionLayer(essence: Essence.rainbow));
    rainbows += 1;
    _refreshObjectives();
    return true;
  }

  void activateBomb(int index) {
    if (index < 0 || index >= bottles.length) return;
    _pushUndo();
    bottles[index].layers.clear();
    specialsForged += 1;
    _refreshObjectives();
    _checkEnd();
  }

  void lightning(Essence color) => colorBlast(color);

  void _afterPour(int from, int to, int count, Essence color) {
    if (color != Essence.poison && !color.isSpecial) collected += count;
    final cleared = BlockerRules.afterPour(bottles);
    crystalsBroken += cleared.crystals;
    frostThawed += cleared.frost;
    var progressed = false;
    if (bottles[to].isCompleteColor(bottles)) {
      progressed = true;
      combo += 1;
      if (count >= 3) {
        specialsForged += 1;
      }
    } else {
      combo = 0;
    }
    if (progressed || count > 0) _refreshObjectives();
  }

  void _revealTops() {
    BlockerRules.revealTops(bottles);
  }

  void _refreshObjectives() {
    for (final o in objectives) {
      o.progress = WinRules.progressFor(
        bottles,
        o,
        moves: moves,
        specialsForged: specialsForged,
        rainbows: rainbows,
      );
    }
  }

  void _checkEnd() {
    _refreshObjectives();
    if (WinRules.meetsWin(bottles, objectives)) {
      phase = EnginePhase.levelComplete;
      return;
    }
    if (moves >= level.moveBudget) {
      phase = EnginePhase.levelFailed;
      failReason = 'Out of pours — a fresh brew will help.';
    }
  }

  void _pushUndo() {
    _undo.add(
      PuzzleSnapshot(
        bottles: bottles.map((b) => b.copy()).toList(),
        objectives: objectives.map((o) => o.copy()).toList(),
        moves: moves,
        combo: combo,
        specialsForged: specialsForged,
        crystalsBroken: crystalsBroken,
        frostThawed: frostThawed,
        collected: collected,
        rainbows: rainbows,
      ),
    );
    if (_undo.length > 40) _undo.removeAt(0);
  }
}
