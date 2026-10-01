import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../domain/generator/level_generator.dart';
import '../domain/levels/level_catalog.dart';
import '../domain/models/level.dart';

/// Opens a vial without stalling the UI isolate.
/// Memory first, then disk, then a background generate+QA.
class LevelStore {
  static final _inFlight = <int, Future<LevelDefinition>>{};

  static String _key(int id) => 'psa_vial_v${GameConfig.catalogVersion}_$id';

  static Future<LevelDefinition> open(int id) async {
    final safeId = id.clamp(1, GameConfig.totalLevels);
    final level = await _readOrGenerate(safeId);
    final next = safeId + 1;
    if (next <= GameConfig.totalLevels) {
      unawaited(_preload(next));
    }
    return level;
  }

  static Future<LevelDefinition> _readOrGenerate(int id) async {
    final ready = LevelCatalog.loadIfReady(id);
    if (ready != null) return ready;

    final pending = _inFlight[id];
    if (pending != null) return pending;
    late final Future<LevelDefinition> load;
    load = _load(id).whenComplete(() {
      if (identical(_inFlight[id], load)) _inFlight.remove(id);
    });
    _inFlight[id] = load;
    return load;
  }

  static Future<void> _preload(int id) async {
    try {
      await _readOrGenerate(id);
    } catch (_) {
      // Prefetch is opportunistic; opening the level will retry visibly.
    }
  }

  static Future<LevelDefinition> _load(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(id));
    if (raw != null) {
      try {
        final level = LevelDefinition.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        LevelCatalog.adopt(level);
        return level;
      } catch (_) {
        // Stale or corrupt cache — generate a fresh certified vial.
      }
    }

    final json = await Isolate.run(() => generateLevelJson(id));
    final level = LevelDefinition.fromJson(Map<String, dynamic>.from(json));
    LevelCatalog.adopt(level);
    await prefs.setString(_key(id), jsonEncode(json));
    return level;
  }
}
