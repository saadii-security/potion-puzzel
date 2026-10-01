import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/progress_store.dart';
import '../domain/levels/level_catalog.dart';
import 'play_screen.dart';
import 'lab_shop_events.dart';
import 'widgets/shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onTab});
  final void Function(int) onTab;

  @override
  Widget build(BuildContext context) {
    final p = ProgressStore.instance;
    return CandyScaffold(
      onSettings: () => SettingsScreen.open(context),
      child: AnimatedBuilder(
        animation: p,
        builder: (_, _) {
          final world = LevelCatalog.worldOf(p.currentLevel);
          final worldName = LevelCatalog.worldName(world);
          final firstLevel = (world - 1) * GameConfig.levelsPerWorld + 1;
          final lastLevel = world * GameConfig.levelsPerWorld;
          final worldProgress =
              (p.currentLevel - firstLevel) / GameConfig.levelsPerWorld;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            physics: const BouncingScrollPhysics(),
            children: [
              _logo(),
              const SizedBox(height: 14),
              _greeting(worldName),
              const SizedBox(height: 16),
              _campaign(
                context,
                p: p,
                worldName: worldName,
                firstLevel: firstLevel,
                lastLevel: lastLevel,
                progress: worldProgress,
              ),
              const SizedBox(height: 22),
              const Align(
                alignment: Alignment.centerLeft,
                child: CandyRibbon(label: 'ACTIVITIES'),
              ),
              const SizedBox(height: 12),
              _activity(
                title: 'Daily Distill',
                subtitle: 'One shared brew every day',
                icon: Icons.local_drink_rounded,
                color: CandyTheme.pink,
                onTap: () => onTab(3),
              ),
              const SizedBox(height: 12),
              _activity(
                title: 'Open the Atlas',
                subtitle: 'Walk the candy world path',
                icon: Icons.map_rounded,
                color: CandyTheme.blue,
                onTap: () => onTab(1),
              ),
              const SizedBox(height: 12),
              _activity(
                title: 'Visit the Lab',
                subtitle: "Decorate Lumen's workshop",
                icon: Icons.science_rounded,
                color: CandyTheme.green,
                onTap: () => onTab(2),
              ),
              if (p.offlineBanner) ...[
                const SizedBox(height: 18),
                CandyPanel(
                  gradient: CandyTheme.candy(
                    CandyTheme.grapeLight,
                    CandyTheme.grapeDark,
                    CandyTheme.grapeDeep,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  radius: 18,
                  depth: 4,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: CandyText(
                          'Offline — progress is saved on this device.',
                          size: 11,
                          display: false,
                          outlineWidth: 0,
                          dropShadow: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Image.asset(
          'assets/candy_emblem.png',
          height: 96,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(height: 2),
        const CandyText(
          'POTION SORT',
          size: 30,
          outlineWidth: 4,
          letterSpacing: 1.4,
          color: CandyTheme.goldLight,
          height: 1.0,
        ),
        const CandyText(
          'ADVENTURE',
          size: 15,
          outlineWidth: 3,
          letterSpacing: 5.0,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _greeting(String worldName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CandyMascot(size: 86),
        const SizedBox(width: 4),
        Expanded(
          child: CandyPanel(
            gradient: CandyTheme.creamCandy,
            radius: 20,
            depth: 4,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CandyText(
                  'Greetings, Alchemist!',
                  size: 16,
                  color: CandyTheme.grapeDark,
                  outlineWidth: 0,
                  dropShadow: false,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 2),
                CandyText(
                  'Lumen is waiting in the $worldName.',
                  size: 12,
                  display: false,
                  color: CandyTheme.outlineSoft,
                  outlineWidth: 0,
                  dropShadow: false,
                  align: TextAlign.left,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _campaign(
    BuildContext context, {
    required ProgressStore p,
    required String worldName,
    required int firstLevel,
    required int lastLevel,
    required double progress,
  }) {
    return CandyPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CandyRibbon(label: worldName.toUpperCase(), size: 11),
              ),
              const SizedBox(width: 10),
              CandyStars(filled: 3, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CandyText(
                'VIAL ${p.currentLevel}',
                size: 38,
                outlineWidth: 4,
                color: CandyTheme.goldLight,
                height: 1.0,
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: CandyText(
                  'of $lastLevel',
                  size: 13,
                  display: false,
                  outlineWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CandyProgressBar(value: progress, color: CandyTheme.blue),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CandyText(
                'World ${(progress * 100).toInt()}% done',
                size: 11,
                display: false,
                outlineWidth: 1.6,
                dropShadow: false,
              ),
              CandyText(
                'Vials $firstLevel–$lastLevel',
                size: 11,
                display: false,
                outlineWidth: 1.6,
                dropShadow: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          CandyButton(
            label: 'CONTINUE',
            icon: Icons.play_arrow_rounded,
            color: CandyTheme.green,
            fontSize: 22,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayScreen(levelId: p.currentLevel),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _activity({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CandyPanel(
      onTap: onTap,
      radius: 22,
      depth: 5,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: CandyTheme.bevel(
              gradient: CandyTheme.candyFor(color),
              radius: 52,
              depth: 3,
              rimWidth: 2.5,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CandyGloss(radius: 52, heightFactor: 0.44),
                ),
                Icon(icon, color: Colors.white, size: 26),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CandyText(
                  title,
                  size: 17,
                  outlineWidth: 2.6,
                  align: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                CandyText(
                  subtitle,
                  size: 11,
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
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 26,
            shadows: [Shadow(color: CandyTheme.outline, offset: Offset(0, 2))],
          ),
        ],
      ),
    );
  }
}
