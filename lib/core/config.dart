/// Central balance and product configuration.
/// Do not scatter economy numbers through widgets.
class GameConfig {
  static const appName = 'Potion Sort Adventure';
  static const mascotName = 'Lumen';
  static const totalWorlds = 6;
  static const levelsPerWorld = 50;
  static const totalLevels = totalWorlds * levelsPerWorld;

  static const bottleCapacity = 4;
  static const solveNodeLimit = 8000;

  /// Bump when generated-vial JSON shape or ship rules change.
  static const catalogVersion = 6;

  /// Tutorial vials may be one pour. Generated vials must be a real puzzle.
  static int minPlayableMoves(int id) {
    if (id <= 1) return 1;
    if (id <= 8) return 2;
    return 3;
  }

  static const startingCoins = 200;
  static const startingGems = 10;
  static const startingHints = 3;
  static const startingUndos = 5;
  static const startingExtraBottles = 2;
  static const startingColorBlasts = 1;
  static const startingClears = 1;
  static const startingRainbows = 1;

  static const coinsPerLevel = 40;
  static const coinsPerStar = 15;
  static const coinsComboBonus = 8;
  static const gemsBossReward = 5;
  static const coinsBossReward = 200;

  static const boosterCoinCost = 80;
  static const boosterGemCost = 4;
  static const extraBottleGemCost = 3;
  static const hintCoinCost = 50;

  static const interstitialEveryNLevels = 4;
  static const removeAdsPriceLabel = '\$3.99';
  static const starterPackPriceLabel = '\$2.99';

  static const dailyStreakRewards = [40, 50, 1, 8, 1, 1, 25];
  static const dailyStreakKinds = [
    'coins',
    'coins',
    'hint',
    'gems',
    'blast',
    'cosmetic',
    'gems',
  ];

  static const worlds = [
    WorldInfo(1, 'Enchanted Forest', 'Moss lanterns and quiet glass.'),
    WorldInfo(2, 'Magic Castle', 'Locks, crystals, and royal hues.'),
    WorldInfo(3, 'Dragon Volcano', 'Heat, bombs, and tight pours.'),
    WorldInfo(4, 'Frozen Kingdom', 'Ice layers that refuse to flow.'),
    WorldInfo(5, 'Underwater Lab', 'Portals and hidden tides.'),
    WorldInfo(6, 'Cosmic Lab', 'Rainbows, wilds, and starlight.'),
  ];
}

class WorldInfo {
  final int id;
  final String name;
  final String blurb;
  const WorldInfo(this.id, this.name, this.blurb);

  int get firstLevel => (id - 1) * GameConfig.levelsPerWorld + 1;
  int get lastLevel => id * GameConfig.levelsPerWorld;
  bool isBoss(int levelId) =>
      levelId == lastLevel || levelId == firstLevel + 24;
}
