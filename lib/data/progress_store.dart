import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../services/analytics.dart';

class ProgressStore extends ChangeNotifier {
  ProgressStore._();
  static final ProgressStore instance = ProgressStore._();

  static const _key = 'psa_progress_v1';
  Future<void>? _pendingPersist;
  int _persistRevision = 0;
  int _savedRevision = 0;

  int currentLevel = 1;
  int unlockedLevel = 1;
  int coins = GameConfig.startingCoins;
  int gems = GameConfig.startingGems;
  int starsTotal = 0;
  int hints = GameConfig.startingHints;
  int undos = GameConfig.startingUndos;
  int extraBottles = GameConfig.startingExtraBottles;
  int colorBlasts = GameConfig.startingColorBlasts;
  int bottleClears = GameConfig.startingClears;
  int rainbows = GameConfig.startingRainbows;
  int streak = 0;
  String? lastStreakDay;
  bool adsRemoved = false;
  bool starterPack = false;
  String bottleSkin = 'glass';
  String potionTheme = 'forest';
  int labTier = 0;
  bool colorblind = false;
  bool reduceMotion = false;
  bool music = true;
  bool sfx = true;
  bool haptics = true;
  int levelsSinceAd = 0;
  final Map<int, int> bestStars = {};
  final Map<int, int> bestMoves = {};
  final Set<String> cosmetics = {'glass', 'forest'};
  final Set<String> achievements = {};
  int dailyBestMoves = 0;
  String? dailyDate;
  bool offlineBanner = false;
  SharedPreferences? _prefs;

  Future<void> load() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final m = Map<String, dynamic>.from(decoded);
      int integer(String key, int fallback) =>
          m[key] is int ? m[key] as int : fallback;
      String string(String key, String fallback) =>
          m[key] is String ? m[key] as String : fallback;
      Map<int, int> integerMap(String key) {
        final source = m[key];
        if (source is! Map) return {};
        final result = <int, int>{};
        for (final entry in source.entries) {
          final id = int.tryParse('${entry.key}');
          if (id != null && entry.value is int) {
            result[id] = entry.value as int;
          }
        }
        return result;
      }

      final loadedStars = integerMap('bestStars');
      final loadedMoves = integerMap('bestMoves');
      final loadedCosmetics =
          (m['cosmetics'] as List?)?.whereType<String>().toSet() ??
          {'glass', 'forest'};
      final loadedAchievements =
          (m['achievements'] as List?)?.whereType<String>().toSet() ??
          <String>{};

      currentLevel = integer(
        'currentLevel',
        1,
      ).clamp(1, GameConfig.totalLevels);
      unlockedLevel = integer(
        'unlockedLevel',
        1,
      ).clamp(1, GameConfig.totalLevels);
      coins = integer('coins', coins).clamp(0, 999999);
      gems = integer('gems', gems).clamp(0, 999999);
      starsTotal = integer('starsTotal', 0).clamp(0, 999999);
      hints = integer('hints', hints).clamp(0, 999999);
      undos = integer('undos', undos).clamp(0, 999999);
      extraBottles = integer('extraBottles', extraBottles).clamp(0, 999999);
      colorBlasts = integer('colorBlasts', colorBlasts).clamp(0, 999999);
      bottleClears = integer('bottleClears', bottleClears).clamp(0, 999999);
      rainbows = integer('rainbows', rainbows).clamp(0, 999999);
      streak = integer('streak', 0).clamp(0, 999999);
      lastStreakDay = m['lastStreakDay'] is String
          ? m['lastStreakDay'] as String
          : null;
      adsRemoved = m['adsRemoved'] == true;
      starterPack = m['starterPack'] == true;
      bottleSkin = string('bottleSkin', 'glass');
      potionTheme = string('potionTheme', 'forest');
      labTier = integer('labTier', 0).clamp(0, 3);
      colorblind = m['colorblind'] == true;
      reduceMotion = m['reduceMotion'] == true;
      music = m['music'] != false;
      sfx = m['sfx'] != false;
      haptics = m['haptics'] != false;
      levelsSinceAd = integer('levelsSinceAd', 0).clamp(0, 999999);
      dailyBestMoves = integer('dailyBestMoves', 0).clamp(0, 999999);
      dailyDate = m['dailyDate'] is String ? m['dailyDate'] as String : null;
      bestStars
        ..clear()
        ..addAll(loadedStars);
      bestMoves
        ..clear()
        ..addAll(loadedMoves);
      cosmetics
        ..clear()
        ..addAll(loadedCosmetics);
      achievements
        ..clear()
        ..addAll(loadedAchievements);
    } catch (_) {
      // Corrupted save: keep defaults rather than crash.
    }
    notifyListeners();
  }

  Future<void> persist() {
    _persistRevision++;
    return _pendingPersist ??= _drainPersist();
  }

  Future<void> _drainPersist() async {
    try {
      // One short window collapses rapid booster taps into one JSON write.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      while (_savedRevision < _persistRevision) {
        final savingRevision = _persistRevision;
        await _persistNow();
        _savedRevision = savingRevision;
      }
    } finally {
      _pendingPersist = null;
    }
  }

  Future<void> _persistNow() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'currentLevel': currentLevel,
        'unlockedLevel': unlockedLevel,
        'coins': coins,
        'gems': gems,
        'starsTotal': starsTotal,
        'hints': hints,
        'undos': undos,
        'extraBottles': extraBottles,
        'colorBlasts': colorBlasts,
        'bottleClears': bottleClears,
        'rainbows': rainbows,
        'streak': streak,
        'lastStreakDay': lastStreakDay,
        'adsRemoved': adsRemoved,
        'starterPack': starterPack,
        'bottleSkin': bottleSkin,
        'potionTheme': potionTheme,
        'labTier': labTier,
        'colorblind': colorblind,
        'reduceMotion': reduceMotion,
        'music': music,
        'sfx': sfx,
        'haptics': haptics,
        'levelsSinceAd': levelsSinceAd,
        'dailyBestMoves': dailyBestMoves,
        'dailyDate': dailyDate,
        'bestStars': bestStars.map((k, v) => MapEntry('$k', v)),
        'bestMoves': bestMoves.map((k, v) => MapEntry('$k', v)),
        'cosmetics': cosmetics.toList(),
        'achievements': achievements.toList(),
      }),
    );
  }

  Future<void> completeLevel({
    required int id,
    required int moves,
    required int stars,
    required bool boss,
  }) async {
    final prev = bestStars[id] ?? 0;
    if (stars > prev) {
      starsTotal += stars - prev;
      bestStars[id] = stars;
    }
    final prevMoves = bestMoves[id];
    if (prevMoves == null || moves < prevMoves) bestMoves[id] = moves;
    if (id + 1 > unlockedLevel && id < GameConfig.totalLevels) {
      unlockedLevel = id + 1;
    }
    currentLevel = unlockedLevel.clamp(1, GameConfig.totalLevels);
    coins += GameConfig.coinsPerLevel + stars * GameConfig.coinsPerStar;
    if (boss) {
      coins += GameConfig.coinsBossReward;
      gems += GameConfig.gemsBossReward;
    }
    if (id >= 25) labTier = labTier < 1 ? 1 : labTier;
    if (id >= 50) labTier = labTier < 2 ? 2 : labTier;
    if (id >= 100) labTier = labTier < 3 ? 3 : labTier;
    if (id == 1) achievements.add('first_pour');
    if (stars == 3) achievements.add('perfect_brew');
    if (id == 20) achievements.add('forest_gate');
    levelsSinceAd += 1;
    Analytics.log('level_completed', {
      'id': id,
      'stars': stars,
      'moves': moves,
    });
    notifyListeners();
    await persist();
  }

  Future<bool> tryPurchase({
    int coinCost = 0,
    int gemCost = 0,
    required String booster,
  }) async {
    if (coins < coinCost || gems < gemCost) return false;
    coins -= coinCost;
    gems -= gemCost;
    switch (booster) {
      case 'hint':
        hints += 1;
      case 'undo':
        undos += 1;
      case 'extra':
        extraBottles += 1;
      case 'blast':
        colorBlasts += 1;
      case 'clear':
        bottleClears += 1;
      case 'rainbow':
        rainbows += 1;
    }
    await persist();
    notifyListeners();
    return true;
  }

  Future<void> claimStreakIfNeeded() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastStreakDay == today) return;
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    streak = lastStreakDay == yesterday ? streak + 1 : 1;
    lastStreakDay = today;
    final idx = (streak - 1) % 7;
    final kind = GameConfig.dailyStreakKinds[idx];
    final amount = GameConfig.dailyStreakRewards[idx];
    if (kind == 'coins') {
      coins += amount;
    } else if (kind == 'gems') {
      gems += amount;
    } else if (kind == 'hint') {
      hints += amount;
    } else if (kind == 'blast') {
      colorBlasts += amount;
    } else {
      cosmetics.add('streak_fragment_$streak');
    }
    await persist();
    notifyListeners();
  }

  bool get shouldOfferInterstitial =>
      !adsRemoved && levelsSinceAd >= GameConfig.interstitialEveryNLevels;

  void markAdShown() {
    levelsSinceAd = 0;
    unawaited(persist());
  }

  bool isUnlocked(int id) => id <= unlockedLevel;

  Future<void> update(void Function() fn) async {
    fn();
    await persist();
    notifyListeners();
  }
}
