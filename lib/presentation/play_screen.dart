import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/level_store.dart';
import '../data/progress_store.dart';
import '../domain/engine/puzzle_engine.dart';
import '../domain/models/level.dart';
import '../domain/models/objectives.dart';
import '../domain/models/potion_color.dart';
import '../game/potion_game.dart';
import '../services/analytics.dart';
import '../services/haptics.dart';
import '../services/monetization.dart';
import '../services/sfx.dart';
import 'widgets/shell.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.levelId, this.daily = false});
  final int levelId;
  final bool daily;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  PuzzleEngine? engine;
  PotionGame? game;
  bool boosters = false;
  bool _ended = false;
  bool _advancing = false;
  bool _loadFailed = false;
  late int _levelId;
  late AnimationController _boosterController;
  late Animation<double> _boosterHeightFactor;

  @override
  void initState() {
    super.initState();
    _levelId = widget.levelId;
    _boosterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _boosterHeightFactor = CurvedAnimation(
      parent: _boosterController,
      curve: Curves.easeInOut,
    );
    _openLevel();
  }

  Future<void> _openLevel() async {
    try {
      final level = await LevelStore.open(_levelId);
      if (!mounted) return;
      _bind(level, first: true);
    } catch (error) {
      Analytics.log('level_load_failed', {
        'id': _levelId,
        'error': error.runtimeType.toString(),
      });
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _bind(LevelDefinition level, {bool first = false}) {
    _levelId = level.id;
    _ended = false;
    _advancing = false;
    _loadFailed = false;
    engine = PuzzleEngine(level);
    if (first || game == null) {
      game = PotionGame(engine!, onChanged: _onChanged);
    } else {
      game!.bind(engine!);
    }
    setState(() {});
    Analytics.log('level_started', {'id': _levelId});
  }

  @override
  void dispose() {
    Sfx.stopPour();
    game?.onChanged = null;
    _boosterController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final game = this.game;
    final engine = this.engine;
    if (game == null || engine == null) return;
    setState(() {});
    if (_ended || game.isAnimating) return;
    if (engine.phase != EnginePhase.levelComplete &&
        engine.phase != EnginePhase.levelFailed) {
      return;
    }
    _ended = true;
    final won = engine.phase == EnginePhase.levelComplete;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (won) {
        _win();
      } else {
        _fail();
      }
    });
  }

  Future<void> _win() async {
    final engine = this.engine;
    if (engine == null) return;
    Haptics.win();
    Sfx.win();
    if (!widget.daily && _levelId < GameConfig.totalLevels) {
      unawaited(LevelStore.open(_levelId + 1));
    }
    final stars = engine.level.starsFor(engine.moves);
    if (widget.daily) {
      final p = ProgressStore.instance;
      final day = DateTime.now().toIso8601String().substring(0, 10);
      if (p.dailyDate != day ||
          p.dailyBestMoves == 0 ||
          engine.moves < p.dailyBestMoves) {
        p.dailyDate = day;
        p.dailyBestMoves = engine.moves;
        unawaited(
          p.persist().catchError(
            (error) => Analytics.log('progress_save_failed', {
              'error': error.runtimeType.toString(),
            }),
          ),
        );
      }
    } else {
      unawaited(
        ProgressStore.instance
            .completeLevel(
              id: _levelId,
              moves: engine.moves,
              stars: stars,
              boss: engine.level.boss,
            )
            .catchError(
              (error) => Analytics.log('progress_save_failed', {
                'error': error.runtimeType.toString(),
              }),
            ),
      );
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ResultCard(
        title: engine.level.boss ? 'BOSS CRUSHED!' : 'SUGAR SORTED!',
        stars: stars,
        moves: engine.moves,
        coins: GameConfig.coinsPerLevel + stars * GameConfig.coinsPerStar,
        onNext: () => _advanceFromWin(dialogContext),
        onReplay: () {
          Navigator.pop(dialogContext);
          _restart();
        },
        onMap: () {
          Navigator.pop(dialogContext);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _advanceFromWin(BuildContext dialogContext) async {
    if (_advancing) return;
    if (widget.daily) {
      Navigator.pop(dialogContext);
      Navigator.pop(context);
      return;
    }
    final next = (_levelId + 1).clamp(1, GameConfig.totalLevels);
    if (next == _levelId) {
      Navigator.pop(dialogContext);
      Navigator.pop(context);
      return;
    }
    _advancing = true;
    try {
      final level = await LevelStore.open(next);
      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      _bind(level);
    } catch (error) {
      _advancing = false;
      Analytics.log('level_load_failed', {
        'id': next,
        'error': error.runtimeType.toString(),
      });
      if (!mounted || !dialogContext.mounted) return;
      CandyToast.show(
        dialogContext,
        'That vial did not brew. Please try again.',
        icon: Icons.refresh_rounded,
        color: CandyTheme.orange,
        good: false,
      );
    }
  }

  void _restart() {
    final engine = this.engine;
    final game = this.game;
    if (engine == null || game == null) return;
    _ended = false;
    engine.reset();
    game.bind(engine);
    setState(() {});
  }

  Future<void> _fail() async {
    final engine = this.engine;
    if (engine == null) return;
    Sfx.fail();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultCard(
        title: (engine.failReason ?? '').contains('pours')
            ? 'OUT OF POURS!'
            : 'OUT OF LUCK!',
        subtitle: engine.failReason ?? 'A tangled brew. You can sort this.',
        stars: 0,
        moves: engine.moves,
        coins: 0,
        fail: true,
        onNext: () {
          Navigator.pop(context);
          _restart();
        },
        onReplay: () {
          Navigator.pop(context);
          _restart();
        },
        onMap: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = this.engine;
    final game = this.game;
    if (engine == null || game == null) {
      return CandyScaffold(
        title: 'Vial $_levelId',
        onBack: () => Navigator.pop(context),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CandyMascot(size: 120),
              const SizedBox(height: 8),
              CandyText(
                _loadFailed
                    ? 'This vial needs another brew.'
                    : 'Lumen is brewing this vial…',
                size: 14,
                outlineWidth: 2.4,
              ),
              if (_loadFailed) ...[
                const SizedBox(height: 16),
                CandyButton(
                  label: 'TRY AGAIN',
                  wide: false,
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    setState(() => _loadFailed = false);
                    _openLevel();
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    final p = ProgressStore.instance;
    final left = (engine.level.moveBudget - engine.moves).clamp(0, 99);
    final pourGradient = left <= 1
        ? CandyTheme.pinkCandy
        : left == 2
        ? CandyTheme.orangeCandy
        : CandyTheme.blueCandy;

    final movesBadge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CandyStars(filled: engine.level.starsFor(engine.moves), size: 13),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: CandyTheme.bevel(
            gradient: pourGradient,
            radius: 20,
            depth: 4,
            rimWidth: 2.5,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CandyGloss(radius: 14, heightFactor: 0.44),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.swap_vert_rounded,
                    color: Colors.white,
                    size: 16,
                    shadows: [
                      Shadow(color: CandyTheme.outline, offset: Offset(0, 2)),
                    ],
                  ),
                  const SizedBox(width: 5),
                  CandyText('$left LEFT', size: 13, outlineWidth: 2.2),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return CandyScaffold(
      title: engine.level.boss ? engine.level.name : 'Vial ${engine.level.id}',
      onBack: () => Navigator.pop(context),
      trailing: movesBadge,
      bottom: _toolbar(p),
      dim: 0.3,
      child: Column(
        children: [
          if (engine.objectives.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final o in engine.objectives)
                    if (o.kind != ObjectiveKind.limitedMoves) _objectiveChip(o),
                ],
              ),
            ),

          if (engine.level.tutorial != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: CandyPanel(
                gradient: CandyTheme.creamCandy,
                radius: 18,
                depth: 4,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_rounded,
                      color: CandyTheme.orangeDark,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CandyText(
                        engine.level.tutorial!,
                        size: 12,
                        display: false,
                        color: CandyTheme.grapeDark,
                        outlineWidth: 0,
                        dropShadow: false,
                        align: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Board tray — a sunken candy dish so the glass vials read clearly
          // against the painted landscape. Combo rides as an overlay so the
          // Flame canvas never resizes mid-pour.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CandyTheme.grapeDeep.withValues(alpha: 0.82),
                      CandyTheme.grapeDark.withValues(alpha: 0.74),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 3,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: RepaintBoundary(
                          child: GameWidget(
                            key: const ValueKey('potion-board'),
                            game: game,
                          ),
                        ),
                      ),
                    ),
                    // Clipped to the dish so the sunburst never bleeds over
                    // the HUD or the toolbar.
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: ComboBurst(
                          pulse: game.comboEvents,
                          tier: game.comboTier,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _objectiveChip(dynamic o) {
    final done = o.done as bool;
    final pct = o.target > 0 ? (o.progress / o.target).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: 172,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: CandyTheme.bevel(
        gradient: done ? CandyTheme.greenCandy : CandyTheme.grapeCandy,
        radius: 18,
        depth: 4,
        rimWidth: 2.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.science_rounded,
                size: 16,
                color: done ? Colors.white : CandyTheme.goldLight,
                shadows: const [
                  Shadow(color: CandyTheme.outline, offset: Offset(0, 1)),
                ],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CandyText(
                  o.label as String,
                  size: 11,
                  display: false,
                  outlineWidth: 1.8,
                  dropShadow: false,
                  align: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CandyText(
                '${o.progress}/${o.target}',
                size: 11,
                outlineWidth: 1.8,
                dropShadow: false,
              ),
            ],
          ),
          const SizedBox(height: 6),
          CandyProgressBar(
            value: pct.toDouble(),
            height: 9,
            color: done ? CandyTheme.gold : CandyTheme.blue,
          ),
        ],
      ),
    );
  }

  Widget _toolbar(ProgressStore p) {
    final engine = this.engine;
    final game = this.game;
    if (engine == null || game == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizeTransition(
          sizeFactor: _boosterHeightFactor,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              gradient: CandyTheme.candy(
                CandyTheme.grape,
                CandyTheme.grapeDark,
                CandyTheme.grapeDeep,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              border: Border(
                top: BorderSide(color: CandyTheme.goldDark, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CandyRibbon(label: 'SWEET BOOSTERS', size: 11),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _booster(
                        asset: CandyIcons.vial,
                        label: 'Extra Vial',
                        count: p.extraBottles,
                        color: CandyTheme.blue,
                        onTap: () {
                          if (p.extraBottles <= 0) return;
                          engine.addExtraBottle();
                          p.extraBottles -= 1;
                          p.persist();
                          game.bind(engine);
                          setState(() {});
                        },
                      ),
                      _booster(
                        asset: CandyIcons.blast,
                        label: 'Color Blast',
                        count: p.colorBlasts,
                        color: CandyTheme.pink,
                        onTap: () async {
                          if (p.colorBlasts <= 0) return;
                          final color = await _pickColor();
                          if (!mounted || color == null || p.colorBlasts <= 0) {
                            return;
                          }
                          engine.colorBlast(color);
                          p.colorBlasts -= 1;
                          p.persist();
                          game.bind(engine);
                          setState(() {});
                        },
                      ),
                      _booster(
                        asset: CandyIcons.clear,
                        label: 'Clear Vial',
                        count: p.bottleClears,
                        color: CandyTheme.green,
                        onTap: () {
                          if (p.bottleClears <= 0 || engine.selected == null) {
                            CandyToast.show(
                              context,
                              'Tap a vial first, then clear it!',
                              icon: Icons.touch_app_rounded,
                              color: CandyTheme.orange,
                              good: false,
                            );
                            return;
                          }
                          engine.clearBottle(engine.selected!);
                          p.bottleClears -= 1;
                          p.persist();
                          game.bind(engine);
                          setState(() {});
                        },
                      ),
                      _booster(
                        asset: CandyIcons.prism,
                        label: 'Prism',
                        count: p.rainbows,
                        color: CandyTheme.orange,
                        onTap: () {
                          if (p.rainbows <= 0) return;
                          if (!engine.addRainbow()) {
                            CandyToast.show(
                              context,
                              'Every vial is full!',
                              icon: Icons.science_rounded,
                              color: CandyTheme.orange,
                              good: false,
                            );
                            return;
                          }
                          p.rainbows -= 1;
                          p.persist();
                          game.bind(engine);
                          setState(() {});
                        },
                      ),
                      _booster(
                        asset: CandyIcons.shuffle,
                        label: 'Shuffle',
                        count: 99, // Unlimited local shuffles as reset
                        color: CandyTheme.gold,
                        onTap: () => _restart(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: CandyTheme.candy(
              CandyTheme.grapeDark,
              CandyTheme.grapeDeep,
              const Color(0xFF1E0838),
            ),
            border: Border(
              top: BorderSide(color: CandyTheme.goldDark, width: 3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _tool(
                asset: CandyIcons.undo,
                label: 'Undo',
                count: p.undos,
                color: CandyTheme.grape,
                onTap: () {
                  if (p.undos <= 0) return;
                  if (engine.undo()) {
                    p.undos -= 1;
                    p.persist();
                    Analytics.log('undo_used');
                    game.bind(engine);
                    setState(() {});
                  }
                },
              ),
              _tool(
                asset: CandyIcons.hint,
                label: 'Hint',
                count: p.hints,
                color: CandyTheme.grape,
                onTap: () {
                  if (p.hints <= 0) return;
                  final move = engine.hintMove();
                  if (move != null) {
                    p.hints -= 1;
                    p.persist();
                    game.flashHint(move);
                    Analytics.log('hint_used');
                    setState(() {});
                  }
                },
              ),
              _tool(
                asset: CandyIcons.boosters,
                label: 'Boosters',
                color: boosters ? CandyTheme.gold : CandyTheme.grape,
                onTap: () {
                  setState(() {
                    boosters = !boosters;
                    if (boosters) {
                      _boosterController.forward();
                    } else {
                      _boosterController.reverse();
                    }
                  });
                },
              ),
              _tool(
                asset: CandyIcons.reset,
                label: 'Reset',
                color: CandyTheme.grape,
                onTap: () {
                  Analytics.log('level_restarted', {'id': _levelId});
                  _restart();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tool({
    required String asset,
    required String label,
    required Color color,
    int? count,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CandyIconButton(
          asset: asset,
          semanticLabel: label,
          onTap: onTap,
          color: color,
          size: 50,
          iconSize: 24,
          count: count,
        ),
        const SizedBox(height: 5),
        CandyText(label, size: 10, outlineWidth: 1.8, dropShadow: false),
      ],
    );
  }

  Widget _booster({
    required String asset,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CandyIconButton(
            asset: asset,
            semanticLabel: label,
            onTap: onTap,
            color: color,
            size: 56,
            iconSize: 26,
            count: count,
            badgeColor: CandyTheme.gold,
          ),
          const SizedBox(height: 6),
          CandyText(label, size: 10, outlineWidth: 1.8, dropShadow: false),
        ],
      ),
    );
  }

  Future<Essence?> _pickColor() async {
    return showModalBottomSheet<Essence>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          gradient: CandyTheme.candy(
            CandyTheme.grape,
            CandyTheme.grapeDark,
            CandyTheme.grapeDeep,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: CandyTheme.goldDark, width: 3)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CandyRibbon(label: 'CHOOSE A COLOR TO BLAST', size: 11),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in playableEssences)
                  Semantics(
                    container: true,
                    button: true,
                    label: 'Blast ${e.label}',
                    onTap: () => Navigator.pop(context, e),
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: CandyTheme.bevel(
                            gradient: CandyTheme.candyFor(e.tint),
                            radius: 18,
                            depth: 4,
                            rimWidth: 2.5,
                          ),
                          child: CandyText(
                            e.label,
                            size: 13,
                            outlineWidth: 2.2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Win / lose card: sunburst, popping stars, and glossy actions.
class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.title,
    required this.stars,
    required this.moves,
    required this.coins,
    required this.onNext,
    required this.onReplay,
    required this.onMap,
    this.subtitle,
    this.fail = false,
  });

  final String title;
  final String? subtitle;
  final int stars;
  final int moves;
  final int coins;
  final bool fail;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onMap;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  final _tings = <Timer>[];

  @override
  void initState() {
    super.initState();
    // One ting per earned star, landing with each star's pop animation.
    if (!widget.fail) {
      for (var s = 1; s <= widget.stars; s++) {
        _tings.add(Timer(Duration(milliseconds: 180 + s * 190), Sfx.star));
      }
    }
  }

  @override
  void dispose() {
    for (final t in _tings) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final subtitle = widget.subtitle;
    final stars = widget.stars;
    final moves = widget.moves;
    final coins = widget.coins;
    final fail = widget.fail;
    final onNext = widget.onNext;
    final onReplay = widget.onReplay;
    final onMap = widget.onMap;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: SingleChildScrollView(
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            if (!fail)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 5000),
                  builder: (_, t, _) =>
                      CustomPaint(painter: CandySunburst(turns: t)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 46),
              child: CandyPanel(
                radius: 30,
                depth: 8,
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CandyText(
                      title,
                      size: 27,
                      outlineWidth: 4,
                      letterSpacing: 0.8,
                      color: fail ? Colors.white : CandyTheme.goldLight,
                    ),
                    const SizedBox(height: 14),
                    if (!fail)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int s = 1; s <= 3; s++)
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 260 + s * 170),
                              curve: Curves.elasticOut,
                              builder: (context, value, _) => Transform.scale(
                                scale: s <= stars ? value : 1.0,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: s == 2 ? 0 : 10,
                                  ),
                                  child: CandyStars(
                                    filled: s <= stars ? 1 : 0,
                                    total: 1,
                                    size: s == 2 ? 56 : 44,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      const Icon(
                        Icons.sentiment_dissatisfied_rounded,
                        size: 62,
                        color: CandyTheme.goldLight,
                        shadows: [
                          Shadow(
                            color: CandyTheme.outline,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    if (subtitle != null)
                      CandyText(
                        subtitle,
                        size: 13,
                        display: false,
                        outlineWidth: 2,
                        dropShadow: false,
                      ),
                    const SizedBox(height: 14),
                    CandyPanel(
                      gradient: CandyTheme.candy(
                        CandyTheme.grapeDark,
                        CandyTheme.grapeDeep,
                        const Color(0xFF1E0838),
                      ),
                      radius: 20,
                      depth: 4,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          _statRow(
                            Icons.swap_vert_rounded,
                            'Total Pours',
                            '$moves',
                          ),
                          if (coins > 0) ...[
                            const SizedBox(height: 8),
                            _statRow(
                              Icons.monetization_on_rounded,
                              'Coins Earned',
                              '+$coins',
                              accent: CandyTheme.goldLight,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (Monetization.rewardedAvailable && !fail) ...[
                      CandyButton(
                        label: 'DOUBLE REWARD',
                        icon: Icons.card_giftcard_rounded,
                        color: CandyTheme.blue,
                        fontSize: 16,
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: CandyButton(
                            label: 'MAP',
                            color: CandyTheme.pink,
                            fontSize: 15,
                            onTap: onMap,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CandyButton(
                            label: 'REPLAY',
                            color: CandyTheme.orange,
                            fontSize: 15,
                            onTap: onReplay,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CandyButton(
                      label: fail ? 'TRY AGAIN' : 'NEXT LEVEL',
                      color: CandyTheme.green,
                      fontSize: 20,
                      onTap: onNext,
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(top: 0, child: CandyMascot(size: 104)),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
    IconData icon,
    String label,
    String value, {
    Color accent = Colors.white,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: CandyText(
            label,
            size: 12,
            display: false,
            outlineWidth: 1.6,
            dropShadow: false,
            align: TextAlign.left,
          ),
        ),
        CandyText(
          value,
          size: 14,
          outlineWidth: 2,
          color: accent,
          dropShadow: false,
        ),
      ],
    );
  }
}
