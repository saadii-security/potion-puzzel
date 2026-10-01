import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/progress_store.dart';
import 'lab_shop_events.dart';
import 'play_screen.dart';
import 'widgets/shell.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late ScrollController _scrollController;

  static const double rowHeight = 120.0;
  static const double bannerHeight = 160.0;
  static const double topPadding = 60.0;

  @override
  void initState() {
    super.initState();
    final p = ProgressStore.instance;
    final currentY = _getYForLevel(p.currentLevel);

    // Start slightly higher up, then smoothly slide down to centre on the
    // current level so the player sees the trail they have already walked.
    _scrollController = ScrollController(
      initialScrollOffset: math.max(0.0, currentY - 550.0),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          math.max(0.0, currentY - 300.0),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _getYForLevel(int id) {
    final worldIndex = (id - 1) ~/ GameConfig.levelsPerWorld;
    // Each world reserves a banner slot *above* its own levels, so the first
    // node of a world never lands under its banner.
    return topPadding +
        ((worldIndex + 1) * bannerHeight) +
        (id - 1) * rowHeight;
  }

  double _getXForLevel(int id, double screenWidth) {
    final centerX = screenWidth / 2;
    return centerX + math.sin(id * 0.7) * (screenWidth * 0.22);
  }

  double _getYForWorldBanner(int worldIndex) {
    return topPadding +
        (worldIndex * bannerHeight) +
        (worldIndex * GameConfig.levelsPerWorld * rowHeight);
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressStore.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    final totalHeight =
        topPadding +
        (GameConfig.totalWorlds * bannerHeight) +
        (GameConfig.totalLevels * rowHeight) +
        100.0;

    return CandyScaffold(
      title: 'Candy Atlas',
      onSettings: () => SettingsScreen.open(context),
      child: AnimatedBuilder(
        animation: p,
        builder: (context, _) {
          return SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              height: totalHeight,
              width: screenWidth,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(screenWidth, totalHeight),
                    painter: MapPathPainter(
                      totalLevels: GameConfig.totalLevels,
                      currentLevel: p.currentLevel,
                      getX: (id) => _getXForLevel(id, screenWidth),
                      getY: (id) => _getYForLevel(id),
                    ),
                  ),
                  for (int wi = 0; wi < GameConfig.totalWorlds; wi++)
                    Positioned(
                      top: _getYForWorldBanner(wi),
                      left: 16,
                      right: 16,
                      child: _worldBanner(GameConfig.worlds[wi]),
                    ),
                  for (int id = 1; id <= GameConfig.totalLevels; id++)
                    Positioned(
                      left: _getXForLevel(id, screenWidth) - 44,
                      top: _getYForLevel(id) - 44,
                      width: 88,
                      child: Center(child: _levelNode(context, p, id)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _worldBanner(WorldInfo world) {
    return CandyPanel(
      gradient: CandyTheme.candy(
        CandyTheme.pinkLight,
        CandyTheme.pink,
        CandyTheme.pinkDark,
      ),
      radius: 24,
      depth: 6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: CandyTheme.bevel(
              gradient: CandyTheme.goldCandy,
              radius: 46,
              depth: 3,
              rimWidth: 2.5,
            ),
            child: Center(
              child: CandyText('${world.id}', size: 20, outlineWidth: 2.4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CandyText(
                  world.name.toUpperCase(),
                  size: 18,
                  outlineWidth: 3,
                  letterSpacing: 0.6,
                  align: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                CandyText(
                  world.blurb,
                  size: 11,
                  display: false,
                  outlineWidth: 1.6,
                  dropShadow: false,
                  color: Colors.white,
                  align: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelNode(BuildContext context, ProgressStore p, int id) {
    final locked = !p.isUnlocked(id);
    final worldIndex = (id - 1) ~/ GameConfig.levelsPerWorld;
    final boss = GameConfig.worlds[worldIndex].isBoss(id);

    return _LevelNode(
      id: id,
      locked: locked,
      boss: boss,
      current: id == p.currentLevel,
      stars: p.bestStars[id] ?? 0,
      onTap: locked
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlayScreen(levelId: id)),
            ),
    );
  }
}

/// One candy button on the trail. Only the current level animates.
class _LevelNode extends StatefulWidget {
  const _LevelNode({
    required this.id,
    required this.locked,
    required this.boss,
    required this.current,
    required this.stars,
    required this.onTap,
  });

  final int id;
  final bool locked;
  final bool boss;
  final bool current;
  final int stars;
  final VoidCallback? onTap;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_LevelNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) _syncPulse();
  }

  void _syncPulse() {
    _pulse?.dispose();
    _pulse = widget.current
        ? (AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1100),
          )..repeat(reverse: true))
        : null;
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.current ? 74.0 : 62.0;

    final gradient = widget.locked
        ? CandyTheme.candy(
            CandyTheme.stone,
            const Color(0xFF7A6C88),
            const Color(0xFF4E4360),
          )
        : widget.boss
        ? CandyTheme.candy(
            const Color(0xFFFF8A8A),
            const Color(0xFFE53935),
            const Color(0xFF8E0000),
          )
        : widget.current
        ? CandyTheme.orangeCandy
        : CandyTheme.greenCandy;

    Widget face = Container(
      width: size,
      height: size,
      decoration: CandyTheme.bevel(
        gradient: gradient,
        radius: size,
        depth: widget.locked ? 3 : 5,
        rim: widget.current ? CandyTheme.goldDark : CandyTheme.outline,
        rimWidth: widget.current ? 3.5 : 3,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CandyGloss(radius: size, heightFactor: 0.46)),
          if (widget.locked)
            const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 24,
              shadows: [
                Shadow(color: CandyTheme.outline, offset: Offset(0, 2)),
              ],
            )
          else if (widget.boss)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: CandyTheme.goldLight,
                  size: 20,
                  shadows: [
                    Shadow(color: CandyTheme.outline, offset: Offset(0, 2)),
                  ],
                ),
                CandyText(
                  '${widget.id}',
                  size: 15,
                  outlineWidth: 2.2,
                  dropShadow: false,
                ),
              ],
            )
          else
            CandyText(
              '${widget.id}',
              size: widget.current ? 26 : 22,
              outlineWidth: 3,
            ),
        ],
      ),
    );

    if (widget.current && _pulse != null) {
      face = AnimatedBuilder(
        animation: _pulse!,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size + 14 + 10 * _pulse!.value,
              height: size + 14 + 10 * _pulse!.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CandyTheme.goldLight.withValues(
                  alpha: 0.30 * (1 - _pulse!.value),
                ),
              ),
            ),
            child!,
          ],
        ),
        child: face,
      );
    }

    final status = widget.locked
        ? 'locked'
        : widget.current
        ? 'current'
        : widget.boss
        ? 'boss'
        : 'unlocked';
    return Semantics(
      container: true,
      button: true,
      enabled: widget.onTap != null,
      label: 'Level ${widget.id}, $status, ${widget.stars} stars',
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              face,
              const SizedBox(height: 4),
              if (!widget.locked)
                CandyStars(filled: widget.stars, size: 13)
              else
                const SizedBox(height: 13),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dotted candy trail linking the level buttons.
class MapPathPainter extends CustomPainter {
  MapPathPainter({
    required this.totalLevels,
    required this.currentLevel,
    required this.getX,
    required this.getY,
  });

  final int totalLevels;
  final int currentLevel;
  final double Function(int) getX;
  final double Function(int) getY;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 1; i < totalLevels; i++) {
      final p1 = Offset(getX(i), getY(i));
      final p2 = Offset(getX(i + 1), getY(i + 1));
      final controlY = (p1.dy + p2.dy) / 2;
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(p1.dx, controlY, p2.dx, controlY, p2.dx, p2.dy);

      _drawCandyDots(canvas, path, walked: i < currentLevel);
    }
  }

  /// Trail of small bevelled sweets: gold where the player has been,
  /// translucent white ahead of them.
  void _drawCandyDots(Canvas canvas, Path path, {required bool walked}) {
    final fill = Paint()
      ..color = walked ? CandyTheme.gold : Colors.white.withValues(alpha: 0.55);
    final rim = Paint()
      ..color = walked
          ? CandyTheme.goldDark
          : CandyTheme.outline.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: walked ? 0.85 : 0.5);

    for (final metric in path.computeMetrics()) {
      // Skip the ends so dots do not tuck under the level buttons.
      for (double d = 26; d < metric.length - 26; d += 17) {
        final pos = metric.getTangentForOffset(d)?.position;
        if (pos == null) continue;
        canvas.drawCircle(pos, 5.0, fill);
        canvas.drawCircle(pos, 5.0, rim);
        canvas.drawCircle(pos.translate(-1.4, -1.6), 1.7, shine);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MapPathPainter oldDelegate) {
    return oldDelegate.currentLevel != currentLevel;
  }
}

class DailyEntry {
  static int puzzleNumber() {
    final epoch = DateTime.utc(2026, 1, 1);
    return DateTime.now().toUtc().difference(epoch).inDays + 1;
  }

  static int levelId() => 21 + (puzzleNumber() % 80);
}
