import '../../core/config.dart';
import '../generator/level_generator.dart';
import '../models/level.dart';
import 'level_qa.dart';
import 'onboard_levels.dart';

class LevelCatalog {
  static final _generator = LevelGenerator();
  static final _onboard = {for (final l in onboardLevels()) l.id: l};

  static LevelDefinition load(int id) {
    final clamped = id.clamp(1, GameConfig.totalLevels);
    if (_onboard.containsKey(clamped)) {
      return LevelQa.certify(_onboard[clamped]!);
    }
    return _generator.generate(clamped);
  }

  static LevelDefinition? loadIfReady(int id) {
    final clamped = id.clamp(1, GameConfig.totalLevels);
    if (_onboard.containsKey(clamped) || _generator.isCached(clamped)) {
      return load(clamped);
    }
    return null;
  }

  static void adopt(LevelDefinition level) =>
      _generator.adopt(LevelQa.certify(level));

  static String worldName(int world) => GameConfig.worlds[world - 1].name;

  static int worldOf(int id) => ((id - 1) ~/ GameConfig.levelsPerWorld) + 1;
}
