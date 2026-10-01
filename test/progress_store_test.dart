import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:potion_sort/core/config.dart';
import 'package:potion_sort/data/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt save fields are filtered and bounded atomically', () async {
    SharedPreferences.setMockInitialValues({
      'psa_progress_v1': jsonEncode({
        'currentLevel': 9999,
        'unlockedLevel': -4,
        'coins': -50,
        'bestStars': {'bad': 3, '2': 2},
        'cosmetics': ['glass', 12],
      }),
    });

    final progress = ProgressStore.instance;
    await progress.load();

    expect(progress.currentLevel, GameConfig.totalLevels);
    expect(progress.unlockedLevel, 1);
    expect(progress.coins, 0);
    expect(progress.bestStars, {2: 2});
    expect(progress.cosmetics, {'glass'});
  });

  test('concurrent purchases cannot spend the same balance twice', () async {
    final progress = ProgressStore.instance;
    progress.coins = GameConfig.hintCoinCost;
    progress.hints = 0;

    final bought = await Future.wait([
      progress.tryPurchase(coinCost: GameConfig.hintCoinCost, booster: 'hint'),
      progress.tryPurchase(coinCost: GameConfig.hintCoinCost, booster: 'hint'),
    ]);

    expect(bought.where((success) => success), hasLength(1));
    expect(progress.coins, 0);
    expect(progress.hints, 1);
  });
}
