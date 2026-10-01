import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/progress_store.dart';
import '../services/monetization.dart';
import '../services/sfx.dart';
import 'map_screen.dart';
import 'play_screen.dart';
import 'privacy_policy_screen.dart';
import 'widgets/shell.dart';

Widget _sectionHeader(String title) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Align(
    alignment: Alignment.centerLeft,
    child: CandyRibbon(label: title),
  ),
);

class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressStore.instance;
    final pieces = [
      if (p.labTier >= 0) 'A sunlit workbench and one stubborn kettle.',
      if (p.labTier >= 1) 'Bookshelf, potion rack, and a moss lantern.',
      if (p.labTier >= 2) 'A humming cauldron and crystal shelf.',
      if (p.labTier >= 3) 'The dragon artifact watches the glass.',
    ];

    return CandyScaffold(
      title: "Lumen's Lab",
      onSettings: () => SettingsScreen.open(context),
      child: AnimatedBuilder(
        animation: p,
        builder: (_, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const BouncingScrollPhysics(),
          children: [
            CandyPanel(
              gradient: CandyTheme.candy(
                CandyTheme.pinkLight,
                CandyTheme.pink,
                CandyTheme.pinkDark,
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  const CandyMascot(size: 104),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CandyText(
                          'THE GRAND CAULDRON',
                          size: 16,
                          outlineWidth: 3,
                          align: TextAlign.left,
                          letterSpacing: 0.6,
                        ),
                        const SizedBox(height: 6),
                        CandyText(
                          'Atelier Tier ${p.labTier + 1}',
                          size: 12,
                          display: false,
                          outlineWidth: 2,
                          dropShadow: false,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 8),
                        CandyRibbon(
                          label: '${p.starsTotal} ★ COLLECTED',
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _sectionHeader('WORKSHOP STATUS'),
            CandyPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in pieces)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: CandyTheme.goldLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CandyText(
                              line,
                              size: 12,
                              display: false,
                              outlineWidth: 1.6,
                              dropShadow: false,
                              align: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _sectionHeader('VIAL SKINS'),
            CandyPanel(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final skin in [
                    'glass',
                    'crystal',
                    'wizard',
                    'ancient',
                    'galaxy',
                  ])
                    _cosmeticChip(
                      label: skin.toUpperCase(),
                      selected: p.bottleSkin == skin,
                      unlocked: p.cosmetics.contains(skin) || skin == 'glass',
                      onTap: () {
                        p.update(() {
                          p.bottleSkin = skin;
                          p.cosmetics.add(skin);
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _sectionHeader('ESSENCE THEMES'),
            CandyPanel(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final theme in [
                    'forest',
                    'ocean',
                    'candy',
                    'lava',
                    'ice',
                  ])
                    _cosmeticChip(
                      label: theme.toUpperCase(),
                      selected: p.potionTheme == theme,
                      unlocked: true, // all themes unlocked for now
                      onTap: () {
                        p.update(() {
                          p.potionTheme = theme;
                          p.cosmetics.add(theme);
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Center(
              child: CandyText(
                'Collection: ${p.cosmetics.length} curios unlocked',
                size: 11,
                display: false,
                outlineWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cosmeticChip({
    required String label,
    required bool selected,
    required bool unlocked,
    required VoidCallback onTap,
  }) {
    final activate = unlocked ? onTap : null;
    return Semantics(
      container: true,
      button: true,
      enabled: unlocked,
      selected: selected,
      label: label,
      onTap: activate,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: activate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: CandyTheme.bevel(
              gradient: selected
                  ? CandyTheme.goldCandy
                  : unlocked
                  ? CandyTheme.blueCandy
                  : CandyTheme.candy(
                      CandyTheme.stone,
                      const Color(0xFF7A6C88),
                      const Color(0xFF4E4360),
                    ),
              radius: 18,
              depth: 4,
              rimWidth: 2.5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unlocked
                      ? (selected
                            ? Icons.check_circle_rounded
                            : Icons.science_rounded)
                      : Icons.lock_rounded,
                  size: 14,
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: CandyTheme.outline, offset: Offset(0, 1)),
                  ],
                ),
                const SizedBox(width: 6),
                CandyText(
                  label,
                  size: 11,
                  outlineWidth: 2,
                  dropShadow: false,
                  letterSpacing: 0.6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressStore.instance;
    return CandyScaffold(
      title: 'Apothecary',
      onSettings: () => SettingsScreen.open(context),
      child: AnimatedBuilder(
        animation: p,
        builder: (_, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const BouncingScrollPhysics(),
          children: [
            CandyPanel(
              gradient: CandyTheme.orangeCandy,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    size: 46,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: CandyTheme.outline, offset: Offset(0, 3)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CandyText(
                          'STARTER BUNDLE',
                          size: 18,
                          outlineWidth: 3,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 2),
                        const CandyText(
                          'Gems, coins, boosters & exclusive glass!',
                          size: 11,
                          display: false,
                          outlineWidth: 1.6,
                          dropShadow: false,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 10),
                        CandyButton(
                          label: p.starterPack
                              ? 'OWNED'
                              : 'BUY ${GameConfig.starterPackPriceLabel}',
                          color: p.starterPack
                              ? CandyTheme.stone
                              : CandyTheme.green,
                          fontSize: 14,
                          wide: false,
                          depth: 5,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            _sectionHeader('BOOSTER OFFERS'),
            _shopOffer(
              title: 'Magical Hint',
              subtitle: 'Reveals one perfect move',
              price: '${GameConfig.hintCoinCost}',
              priceAsset: CandyIcons.coin,
              asset: CandyIcons.hint,
              color: CandyTheme.orange,
              onBuy: () async {
                if (await p.tryPurchase(
                  coinCost: GameConfig.hintCoinCost,
                  booster: 'hint',
                )) {
                  if (!context.mounted) return;
                  _toast(context, 'Purchased 1 Hint!', CandyTheme.green);
                } else {
                  if (!context.mounted) return;
                  _toast(context, 'Not enough coins!', CandyTheme.pinkDark);
                }
              },
            ),
            const SizedBox(height: 12),
            _shopOffer(
              title: 'Rewind Pack',
              subtitle: 'Adds 1 Undo charge',
              price: '${GameConfig.boosterCoinCost}',
              priceAsset: CandyIcons.coin,
              asset: CandyIcons.undo,
              color: CandyTheme.blue,
              onBuy: () async {
                if (await p.tryPurchase(
                  coinCost: GameConfig.boosterCoinCost,
                  booster: 'undo',
                )) {
                  if (!context.mounted) return;
                  _toast(context, 'Purchased 1 Undo!', CandyTheme.green);
                } else {
                  if (!context.mounted) return;
                  _toast(context, 'Not enough coins!', CandyTheme.pinkDark);
                }
              },
            ),
            const SizedBox(height: 12),
            _shopOffer(
              title: 'Extra Vial',
              subtitle: 'Adds an extra empty bottle',
              price: '${GameConfig.extraBottleGemCost}',
              priceAsset: CandyIcons.gem,
              asset: CandyIcons.vial,
              color: CandyTheme.green,
              onBuy: () async {
                if (await p.tryPurchase(
                  gemCost: GameConfig.extraBottleGemCost,
                  booster: 'extra',
                )) {
                  if (!context.mounted) return;
                  _toast(context, 'Purchased 1 Extra Vial!', CandyTheme.green);
                } else {
                  if (!context.mounted) return;
                  _toast(context, 'Not enough gems!', CandyTheme.pinkDark);
                }
              },
            ),
            const SizedBox(height: 12),
            _shopOffer(
              title: 'Color Blast',
              subtitle: 'Clears all layers of one color',
              price: '${GameConfig.boosterGemCost}',
              priceAsset: CandyIcons.gem,
              asset: CandyIcons.blast,
              color: CandyTheme.pink,
              onBuy: () async {
                if (await p.tryPurchase(
                  gemCost: GameConfig.boosterGemCost,
                  booster: 'blast',
                )) {
                  if (!context.mounted) return;
                  _toast(context, 'Purchased 1 Color Blast!', CandyTheme.green);
                } else {
                  if (!context.mounted) return;
                  _toast(context, 'Not enough gems!', CandyTheme.pinkDark);
                }
              },
            ),
            const SizedBox(height: 22),

            _sectionHeader('PREMIUM UPGRADES'),
            CandyPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CandyText(
                          'Remove Forced Ads',
                          size: 15,
                          outlineWidth: 2.4,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 2),
                        CandyText(
                          Monetization.iapAvailable
                              ? 'No more forced interstitial ads'
                              : 'Store offline — play is fully free.',
                          size: 11,
                          display: false,
                          outlineWidth: 1.6,
                          dropShadow: false,
                          align: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CandyButton(
                    label: p.adsRemoved
                        ? 'OWNED'
                        : GameConfig.removeAdsPriceLabel,
                    color: p.adsRemoved ? CandyTheme.stone : CandyTheme.gold,
                    fontSize: 13,
                    wide: false,
                    depth: 5,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg, Color color) {
    final good = color != CandyTheme.pinkDark;
    CandyToast.show(
      context,
      msg,
      icon: good
          ? Icons.shopping_bag_rounded
          : Icons.report_gmailerrorred_rounded,
      color: good ? CandyTheme.green : CandyTheme.pink,
      good: good,
    );
  }

  Widget _shopOffer({
    required String title,
    required String subtitle,
    required String price,
    required String priceAsset,
    required String asset,
    required Color color,
    required VoidCallback onBuy,
  }) {
    return CandyPanel(
      padding: const EdgeInsets.all(12),
      radius: 22,
      depth: 5,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: CandyTheme.bevel(
              gradient: CandyTheme.candyFor(color),
              radius: 50,
              depth: 3,
              rimWidth: 2.5,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CandyGloss(radius: 50, heightFactor: 0.44),
                ),
                CandyIcon(asset: asset, size: 24),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CandyText(
                  title,
                  size: 15,
                  outlineWidth: 2.4,
                  align: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                CandyText(
                  subtitle,
                  size: 10,
                  display: false,
                  outlineWidth: 1.6,
                  dropShadow: false,
                  color: Colors.white70,
                  align: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CandyButton(
            label: price,
            asset: priceAsset,
            color: CandyTheme.green,
            fontSize: 13,
            wide: false,
            depth: 5,
            onTap: onBuy,
          ),
        ],
      ),
    );
  }
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressStore.instance;
    return CandyScaffold(
      title: 'Calendar',
      onSettings: () => SettingsScreen.open(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        physics: const BouncingScrollPhysics(),
        children: [
          _eventCard(
            title: 'Daily Distill',
            subtitle: 'Puzzle #${DailyEntry.puzzleNumber()}',
            body:
                'Everyone shares this brew today. Compete for the best moves!',
            badge: 'LIVE',
            badgeColor: CandyTheme.pink,
            icon: Icons.local_drink_rounded,
            gradient: CandyTheme.pinkCandy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PlayScreen(levelId: DailyEntry.levelId(), daily: true),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _eventCard(
            title: 'Daily Streak: Day ${p.streak}',
            subtitle: 'Consecutive alchemical visits',
            body:
                'Return tomorrow for your next gift. Missing a day resets the count.',
            badge: 'CLAIM',
            badgeColor: CandyTheme.gold,
            icon: Icons.calendar_month_rounded,
            gradient: CandyTheme.orangeCandy,
            onTap: () {
              p.claimStreakIfNeeded();
              CandyToast.show(
                context,
                'Streak claimed! Return tomorrow for more.',
                icon: Icons.calendar_month_rounded,
                color: CandyTheme.gold,
              );
            },
          ),
          const SizedBox(height: 12),
          _eventCard(
            title: 'Grove Week',
            subtitle: 'Enchanted Forest challenge',
            body:
                'Complete 10 vials in the Enchanted Forest to unlock cosmetic bonuses.',
            badge: 'ACTIVE',
            badgeColor: CandyTheme.green,
            icon: Icons.park_rounded,
            gradient: CandyTheme.greenCandy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            ),
          ),
          const SizedBox(height: 22),

          _sectionHeader('ACHIEVEMENTS'),
          CandyPanel(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in ['first_pour', 'perfect_brew', 'forest_gate'])
                  _achievementChip(
                    label: a.replaceAll('_', ' ').toUpperCase(),
                    unlocked: p.achievements.contains(a),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementChip({required String label, required bool unlocked}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: CandyTheme.bevel(
        gradient: unlocked
            ? CandyTheme.goldCandy
            : CandyTheme.candy(
                CandyTheme.stone,
                const Color(0xFF7A6C88),
                const Color(0xFF4E4360),
              ),
        radius: 16,
        depth: 4,
        rimWidth: 2.5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
            size: 14,
            color: Colors.white,
            shadows: const [
              Shadow(color: CandyTheme.outline, offset: Offset(0, 1)),
            ],
          ),
          const SizedBox(width: 6),
          CandyText(
            label,
            size: 10,
            outlineWidth: 1.8,
            dropShadow: false,
            letterSpacing: 0.5,
          ),
        ],
      ),
    );
  }

  Widget _eventCard({
    required String title,
    required String subtitle,
    required String body,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return CandyPanel(
      onTap: onTap,
      gradient: gradient,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: CandyTheme.bevel(
              gradient: CandyTheme.creamCandy,
              radius: 16,
              depth: 3,
              rimWidth: 2.5,
            ),
            child: Icon(icon, size: 26, color: CandyTheme.grapeDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CandyText(
                        title,
                        size: 16,
                        outlineWidth: 2.6,
                        align: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    CandyRibbon(label: badge, color: badgeColor, size: 9),
                  ],
                ),
                CandyText(
                  subtitle,
                  size: 11,
                  display: false,
                  outlineWidth: 1.8,
                  dropShadow: false,
                  color: CandyTheme.goldLight,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 6),
                CandyText(
                  body,
                  size: 11,
                  display: false,
                  outlineWidth: 1.6,
                  dropShadow: false,
                  align: TextAlign.left,
                  height: 1.35,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressStore.instance;
    return CandyScaffold(
      title: 'Settings',
      onBack: () => Navigator.pop(context),
      child: AnimatedBuilder(
        animation: p,
        builder: (_, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const BouncingScrollPhysics(),
          children: [
            _sectionHeader('AUDIO & FEEDBACK'),
            _switchTile(
              title: 'Music',
              subtitle: 'Ambient magical melodies',
              value: p.music,
              icon: Icons.music_note_rounded,
              color: CandyTheme.pink,
              onChanged: (v) {
                p.update(() => p.music = v);
                Sfx.music(v);
              },
            ),
            const SizedBox(height: 10),
            _switchTile(
              title: 'Sound Effects',
              subtitle: 'Pouring & sorting feedback',
              value: p.sfx,
              icon: Icons.volume_up_rounded,
              color: CandyTheme.blue,
              onChanged: (v) {
                p.update(() => p.sfx = v);
                if (!v) Sfx.stopPour();
              },
            ),
            const SizedBox(height: 10),
            _switchTile(
              title: 'Haptic Feedback',
              subtitle: 'Tactile vibration responses',
              value: p.haptics,
              icon: Icons.vibration_rounded,
              color: CandyTheme.orange,
              onChanged: (v) => p.update(() => p.haptics = v),
            ),
            const SizedBox(height: 20),

            _sectionHeader('ACCESSIBILITY & GRAPHICS'),
            _switchTile(
              title: 'Colorblind Marks',
              subtitle:
                  'Puts a unique shape on each potion color so they stay distinct',
              value: p.colorblind,
              icon: Icons.remove_red_eye_rounded,
              color: CandyTheme.green,
              onChanged: (v) => p.update(() => p.colorblind = v),
            ),
            const SizedBox(height: 10),
            _switchTile(
              title: 'Reduce Motion',
              subtitle: 'Shortens pours and freezes the liquid wobble',
              value: p.reduceMotion,
              icon: Icons.motion_photos_off_rounded,
              color: CandyTheme.gold,
              onChanged: (v) => p.update(() => p.reduceMotion = v),
            ),
            const SizedBox(height: 20),
            _sectionHeader('LEGAL & INFO'),
            _actionTile(
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              icon: Icons.privacy_tip_rounded,
              color: CandyTheme.pink,
              onTap: () => PrivacyPolicyScreen.open(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      container: true,
      label: title,
      value: subtitle,
      onTap: onTap,
      child: ExcludeSemantics(
        child: CandyPanel(
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          radius: 22,
          depth: 5,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: CandyTheme.bevel(
                        gradient: CandyTheme.candyFor(color),
                        radius: 44,
                        depth: 3,
                        rimWidth: 2.5,
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CandyText(
                            title,
                            size: 14,
                            outlineWidth: 2.2,
                            align: TextAlign.left,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          CandyText(
                            subtitle,
                            size: 10,
                            display: false,
                            outlineWidth: 1.6,
                            dropShadow: false,
                            color: Colors.white70,
                            align: TextAlign.left,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 24,
                shadows: [
                  Shadow(color: CandyTheme.outline, offset: Offset(0, 2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      container: true,
      toggled: value,
      label: title,
      value: subtitle,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: CandyPanel(
          padding: const EdgeInsets.all(12),
          radius: 22,
          depth: 5,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(!value),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: CandyTheme.bevel(
                          gradient: CandyTheme.candyFor(color),
                          radius: 44,
                          depth: 3,
                          rimWidth: 2.5,
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CandyText(
                              title,
                              size: 14,
                              outlineWidth: 2.2,
                              align: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            CandyText(
                              subtitle,
                              size: 10,
                              display: false,
                              outlineWidth: 1.6,
                              dropShadow: false,
                              color: Colors.white70,
                              align: TextAlign.left,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? CandyTheme.green
                      : CandyTheme.grapeDeep,
                ),
                trackOutlineColor: const WidgetStatePropertyAll(
                  CandyTheme.outline,
                ),
                trackOutlineWidth: const WidgetStatePropertyAll(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
