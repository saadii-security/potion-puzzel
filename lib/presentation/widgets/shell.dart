import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/progress_store.dart';
import '../../services/sfx.dart';

/// Rounded display text with a thick candy outline and a soft drop shadow.
///
/// The outline is a ring of hard shadows rather than a second stroked layer, so
/// each label stays a single [Text] in the tree (cheaper, and finders still see
/// exactly one widget per label).
class CandyText extends StatelessWidget {
  const CandyText(
    this.text, {
    super.key,
    this.size = 18,
    this.color = Colors.white,
    this.outlineColor = CandyTheme.outline,
    this.outlineWidth = 2.5,
    this.letterSpacing = 0.5,
    this.align = TextAlign.center,
    this.maxLines,
    this.overflow,
    this.height,
    this.display = true,
    this.dropShadow = true,
  });

  final String text;
  final double size;
  final Color color;
  final Color outlineColor;
  final double outlineWidth;
  final double letterSpacing;
  final TextAlign align;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? height;

  /// Rounded poster face for headings; the body face for dense copy.
  final bool display;
  final bool dropShadow;

  static final _shadowCache = <(Color, double, bool), List<Shadow>>{};

  static List<Shadow> _shadows(
    Color outlineColor,
    double outlineWidth,
    bool dropShadow,
  ) {
    final key = (outlineColor, outlineWidth, dropShadow);
    return _shadowCache.putIfAbsent(key, () {
      final shadows = <Shadow>[];
      if (outlineWidth > 0) {
        const steps = 12;
        for (var i = 0; i < steps; i++) {
          final a = i * (2 * math.pi / steps);
          shadows.add(
            Shadow(
              color: outlineColor,
              offset: Offset(
                math.cos(a) * outlineWidth,
                math.sin(a) * outlineWidth,
              ),
            ),
          );
        }
      }
      if (dropShadow) {
        shadows.add(
          Shadow(
            color: CandyTheme.outline.withValues(alpha: 0.45),
            offset: Offset(0, outlineWidth + 2),
            blurRadius: 3,
          ),
        );
      }
      return List.unmodifiable(shadows);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontFamily: display ? 'Candy' : 'CandyBody',
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: _shadows(outlineColor, outlineWidth, dropShadow),
      ),
    );
  }
}

/// The specular sheen that sits on the top half of every candy surface.
class CandyGloss extends StatelessWidget {
  const CandyGloss({
    super.key,
    this.radius = 20,
    this.heightFactor = 0.46,
    this.strength = 0.55,
  });

  final double radius;
  final double heightFactor;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            widthFactor: 0.94,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: strength),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big glossy pill button that physically presses into its own shadow.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = CandyTheme.green,
    this.wide = true,
    this.icon,
    this.asset,
    this.fontSize = 20,
    this.radius = 26,
    this.depth = 6,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool wide;
  final IconData? icon;

  /// Painted icon that replaces [icon] when supplied.
  final String? asset;
  final double fontSize;
  final double radius;
  final double depth;
  final bool enabled;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _down = false;

  void _activate() {
    Sfx.button();
    widget.onTap();
  }

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final gradient = enabled
        ? CandyTheme.candyFor(widget.color)
        : CandyTheme.candy(
            CandyTheme.stone,
            const Color(0xFF7A6C88),
            const Color(0xFF5A4E68),
          );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? _activate : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled
              ? (_) {
                  _set(false);
                  _activate();
                }
              : null,
          onTapCancel: () => _set(false),
          child: Transform.translate(
            offset: Offset(0, _down ? widget.depth : 0),
            child: Container(
              width: widget.wide ? double.infinity : null,
              decoration: CandyTheme.bevel(
                gradient: gradient,
                radius: widget.radius,
                depth: _down ? 0 : widget.depth,
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: CandyGloss(radius: widget.radius - 6)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.wide ? 20 : 24,
                      vertical: 13,
                    ),
                    child: Row(
                      mainAxisSize: widget.wide
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null || widget.asset != null) ...[
                          CandyIcon(
                            asset: widget.asset,
                            icon: widget.icon,
                            size: widget.fontSize + 4,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: CandyText(
                            widget.label,
                            size: widget.fontSize,
                            outlineWidth: 2.6,
                            letterSpacing: 1.0,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Painted candy icon, falling back to a Material glyph when there is no art.
///
/// The art files carry their own outline and ~12% padding, so they render
/// larger than the equivalent glyph to land on the same optical size.
class CandyIcon extends StatelessWidget {
  const CandyIcon({
    super.key,
    required this.size,
    this.asset,
    this.icon,
    this.color = Colors.white,
  });

  final double size;
  final String? asset;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final art = asset;
    if (art != null) {
      return Image.asset(
        art,
        width: size * 1.5,
        height: size * 1.5,
        fit: BoxFit.contain,
      );
    }
    if (icon == null) return const SizedBox.shrink();
    return Icon(
      icon,
      size: size,
      color: color,
      shadows: const [
        Shadow(color: CandyTheme.outline, offset: Offset(0, 2), blurRadius: 2),
      ],
    );
  }
}

/// Round glossy button used for tools, nav and the back arrow.
class CandyIconButton extends StatefulWidget {
  const CandyIconButton({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    this.icon,
    this.asset,
    this.color = CandyTheme.grape,
    this.size = 52,
    this.iconSize = 24,
    this.count,
    this.badgeColor = CandyTheme.pink,
    this.enabled = true,
  });

  final IconData? icon;
  final VoidCallback onTap;
  final String semanticLabel;

  /// Painted icon that replaces [icon] when supplied.
  final String? asset;
  final Color color;
  final double size;
  final double iconSize;
  final int? count;
  final Color badgeColor;
  final bool enabled;

  @override
  State<CandyIconButton> createState() => _CandyIconButtonState();
}

class _CandyIconButtonState extends State<CandyIconButton> {
  bool _down = false;

  void _activate() {
    Sfx.button();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.enabled
        ? CandyTheme.candyFor(widget.color)
        : CandyTheme.candy(
            CandyTheme.stone,
            const Color(0xFF7A6C88),
            const Color(0xFF5A4E68),
          );

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      value: widget.count == null ? null : '${widget.count} remaining',
      onTap: widget.enabled ? _activate : null,
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTapDown: widget.enabled
                  ? (_) => setState(() => _down = true)
                  : null,
              onTapUp: widget.enabled
                  ? (_) {
                      setState(() => _down = false);
                      _activate();
                    }
                  : null,
              onTapCancel: () => setState(() => _down = false),
              child: Transform.translate(
                offset: Offset(0, _down ? 4 : 0),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: CandyTheme.bevel(
                    gradient: gradient,
                    radius: widget.size,
                    depth: _down ? 0 : 4,
                    rimWidth: 2.5,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CandyGloss(
                          radius: widget.size,
                          heightFactor: 0.44,
                        ),
                      ),
                      CandyIcon(
                        asset: widget.asset,
                        icon: widget.icon,
                        size: widget.iconSize,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.count != null)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 22),
                  decoration: BoxDecoration(
                    gradient: CandyTheme.candyFor(widget.badgeColor),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: CandyTheme.outline,
                        offset: Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: CandyText(
                    '${widget.count}',
                    size: 11,
                    outlineWidth: 1.6,
                    dropShadow: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chunky grape panel with a bright inner rim — the app's default container.
class CandyPanel extends StatelessWidget {
  const CandyPanel({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(16),
    this.radius = 26,
    this.depth = 6,
    this.onTap,
  });

  final Widget child;
  final Gradient? gradient;
  final EdgeInsets padding;
  final double radius;
  final double depth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: CandyTheme.bevel(
        gradient: gradient ?? CandyTheme.grapeCandy,
        radius: radius,
        depth: depth,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CandyGloss(
              radius: radius - 6,
              heightFactor: 0.4,
              strength: 0.22,
            ),
          ),
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius - 6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.26),
                width: 2,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

/// Gold-rimmed currency readout: round candy token, dark pill, bold count.
class CandyCounter extends StatelessWidget {
  const CandyCounter({super.key, required this.value, required this.asset});

  final String value;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 7),
      padding: const EdgeInsets.only(left: 2, right: 9),
      decoration: BoxDecoration(
        color: CandyTheme.grapeDeep.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CandyTheme.outline, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: 28, height: 28, fit: BoxFit.contain),
          const SizedBox(width: 4),
          CandyText(value, size: 13, outlineWidth: 1.8, dropShadow: false),
        ],
      ),
    );
  }
}

class CurrencyBar extends StatelessWidget {
  const CurrencyBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressStore.instance;
    return AnimatedBuilder(
      animation: p,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CandyCounter(asset: CandyIcons.star, value: '${p.starsTotal}'),
          CandyCounter(asset: CandyIcons.coin, value: '${p.coins}'),
          CandyCounter(asset: CandyIcons.gem, value: '${p.gems}'),
        ],
      ),
    );
  }
}

/// Painted icon set. One place to rename or re-cut art.
class CandyIcons {
  static const coin = 'assets/icons/icon_coin.png';
  static const gem = 'assets/icons/icon_gem.png';
  static const star = 'assets/icons/icon_star.png';
  static const shuffle = 'assets/icons/icon_shuffle.png';
  static const undo = 'assets/icons/icon_undo.png';
  static const hint = 'assets/icons/icon_hint.png';
  static const boosters = 'assets/icons/icon_boosters.png';
  static const reset = 'assets/icons/icon_reset.png';
  static const vial = 'assets/icons/icon_vial.png';
  static const blast = 'assets/icons/icon_blast.png';
  static const clear = 'assets/icons/icon_clear.png';
  static const prism = 'assets/icons/icon_prism.png';
}

/// Star row used for level scores. Unearned stars are the same art dimmed, so
/// filled and empty always share a silhouette.
class CandyStars extends StatelessWidget {
  const CandyStars({
    super.key,
    required this.filled,
    this.size = 22,
    this.total = 3,
  });

  final int filled;
  final double size;
  final int total;

  @override
  Widget build(BuildContext context) {
    final art = size * 1.3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= total; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.02),
            child: i <= filled
                ? Image.asset(CandyIcons.star, width: art, height: art)
                : ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      CandyTheme.grapeDeep.withValues(alpha: 0.82),
                      BlendMode.srcATop,
                    ),
                    child: Image.asset(
                      CandyIcons.star,
                      width: art,
                      height: art,
                    ),
                  ),
          ),
      ],
    );
  }
}

/// Sunken track with a glossy candy fill.
class CandyProgressBar extends StatelessWidget {
  const CandyProgressBar({
    super.key,
    required this.value,
    this.height = 16,
    this.color = CandyTheme.blue,
  });

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: CandyTheme.grapeDeep,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: CandyTheme.outline, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: CandyTheme.candyFor(color),
                borderRadius: BorderRadius.circular(height),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.45,
                  widthFactor: 0.96,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small heading ribbon: dark plate, gold rim, outlined caps.
class CandyRibbon extends StatelessWidget {
  const CandyRibbon({
    super.key,
    required this.label,
    this.color = CandyTheme.gold,
    this.size = 13,
  });

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: CandyTheme.grapeDeep.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 2),
        boxShadow: const [
          BoxShadow(
            color: CandyTheme.outline,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: CandyText(
        label,
        size: size,
        letterSpacing: 1.4,
        outlineWidth: 1.8,
        dropShadow: false,
      ),
    );
  }
}

/// Painted candy world behind every screen, with the shared top bar.
class CandyScaffold extends StatelessWidget {
  const CandyScaffold({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.bottom,
    this.onBack,
    this.onSettings,
    this.dim = 0.18,
    this.showCurrency = true,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final Widget? bottom;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;

  /// Extra darkening over the artwork. Gameplay uses a heavier dim so the
  /// vials read clearly against the candy landscape.
  final double dim;
  final bool showCurrency;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CandyTheme.grapeDeep,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/candy_background.png', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CandyTheme.grapeDeep.withValues(alpha: 0.55 + dim),
                  CandyTheme.grapeDark.withValues(alpha: 0.10 + dim),
                  CandyTheme.grapeDeep.withValues(alpha: 0.60 + dim),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      if (onBack != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: CandyIconButton(
                            icon: Icons.arrow_back_rounded,
                            semanticLabel: 'Back',
                            onTap: onBack!,
                            color: CandyTheme.pink,
                            size: 42,
                            iconSize: 20,
                          ),
                        ),
                      if (title != null)
                        Expanded(
                          child: CandyText(
                            title!,
                            size: 22,
                            outlineWidth: 3.2,
                            letterSpacing: 0.4,
                            align: TextAlign.left,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                      // Scale down rather than overflow when a long title and
                      // fat currency totals compete for the same row.
                      if (trailing != null || showCurrency)
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: trailing ?? const CurrencyBar(),
                          ),
                        ),
                      if (onSettings != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: CandyIconButton(
                            icon: Icons.settings_rounded,
                            semanticLabel: 'Settings',
                            onTap: onSettings!,
                            color: CandyTheme.gold,
                            size: 42,
                            iconSize: 20,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: child),
                ?bottom,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rotating light rays. Sits behind praise popups and the win card.
class CandySunburst extends CustomPainter {
  CandySunburst({
    required this.turns,
    this.color = CandyTheme.goldLight,
    this.alpha = 0.14,
    this.center,
  });

  final double turns;
  final Color color;
  final double alpha;
  final Alignment? center;

  @override
  void paint(Canvas canvas, Size size) {
    final anchor = center ?? const Alignment(0, -0.64);
    final origin = Offset(
      size.width / 2 * (1 + anchor.x),
      size.height / 2 * (1 + anchor.y),
    );
    final radius = size.longestSide;
    final paint = Paint()..color = color.withValues(alpha: alpha);
    final path = Path();
    const rays = 16;
    final spin = turns * 2 * math.pi / rays;

    for (var i = 0; i < rays; i++) {
      final a = spin + i * (2 * math.pi / rays);
      path
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(
          origin.dx + math.cos(a) * radius,
          origin.dy + math.sin(a) * radius,
        )
        ..lineTo(
          origin.dx + math.cos(a + 0.16) * radius,
          origin.dy + math.sin(a + 0.16) * radius,
        )
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CandySunburst old) =>
      old.turns != turns || old.alpha != alpha || old.color != color;
}

/// Escalating praise popup: the moment the game sells itself.
///
/// [pulse] is a counter the board bumps once per finished vial; the burst
/// replays whenever it grows, so repeated combos at the same tier still pop.
class ComboBurst extends StatefulWidget {
  const ComboBurst({super.key, required this.pulse, required this.tier});

  final int pulse;
  final int tier;

  static const praise = <String>[
    'NICE!',
    'SWEET!',
    'TASTY!',
    'YUMMY!',
    'DIVINE!',
    'DELICIOUS!',
    'SCRUMPTIOUS!',
    'SUGAR RUSH!',
    'MARVELOUS!',
    'SENSATIONAL!',
    'LEGENDARY!',
    'CANDY STORM!',
    'SUGAR BLAST!',
    'UNBELIEVABLE!',
    'SWEET LEGEND!',
  ];

  static const _glow = <Color>[
    CandyTheme.blue,
    CandyTheme.gold,
    CandyTheme.orange,
    CandyTheme.green,
    CandyTheme.pink,
    CandyTheme.grapeLight,
    CandyTheme.goldLight,
    CandyTheme.pink,
    CandyTheme.orange,
    CandyTheme.blue,
    CandyTheme.green,
    CandyTheme.gold,
    CandyTheme.pink,
    CandyTheme.grapeLight,
    CandyTheme.goldLight,
  ];

  /// Stays on the last word after ×15 — never wraps back to NICE.
  static String wordFor(int tier) =>
      praise[(tier - 1).clamp(0, praise.length - 1)];

  @override
  State<ComboBurst> createState() => _ComboBurstState();
}

class _ComboBurstState extends State<ComboBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  int _tier = 1;

  late final Animation<double> _pop = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.34, curve: Curves.elasticOut),
  );
  late final Animation<double> _exit = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.72, 1.0, curve: Curves.easeIn),
  );

  @override
  void didUpdateWidget(ComboBurst old) {
    super.didUpdateWidget(old);
    if (widget.pulse > old.pulse) {
      _tier = widget.tier <= 0 ? 1 : widget.tier;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _wordSize(int tier) {
    final n = ComboBurst.wordFor(tier).length;
    if (n > 13) return 28;
    if (n > 10) return 32;
    return tier >= 5 ? 38 : 36;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.isDismissed) return const SizedBox.shrink();

          final glow = ComboBurst
              ._glow[(_tier - 1).clamp(0, ComboBurst._glow.length - 1)];
          final scale = 0.55 + 0.45 * _pop.value;
          final fade = 1.0 - _exit.value;

          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -46 * _exit.value),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CandySunburst(
                        turns: _c.value * 0.35,
                        color: glow,
                        alpha: 0.20 * fade,
                        center: Alignment.center,
                      ),
                    ),
                  ),
                  Container(
                    width: 300,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glow.withValues(alpha: 0.55 * fade),
                          glow.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CandyText(
                          ComboBurst.wordFor(_tier),
                          size: _wordSize(_tier),
                          outlineWidth: 5,
                          letterSpacing: 1.2,
                          color: CandyTheme.goldLight,
                        ),
                        if (_tier >= 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: CandyTheme.bevel(
                                gradient: CandyTheme.candyFor(glow),
                                radius: 16,
                                depth: 3,
                                rimWidth: 2.5,
                              ),
                              child: CandyText(
                                'COMBO ×$_tier',
                                size: 14,
                                outlineWidth: 2.4,
                                letterSpacing: 1.0,
                                dropShadow: false,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Candy replacement for Material snackbars: drops in from the top, pops, and
/// leaves. Use for every player-facing notice so nothing breaks the theme.
class CandyToast {
  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.auto_awesome_rounded,
    Color color = CandyTheme.grape,
    bool good = true,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    if (good) {
      Sfx.coin();
    } else {
      Sfx.nope();
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastCard(
        message: message,
        icon: icon,
        color: color,
        onDone: entry.remove,
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.icon,
    required this.color,
    required this.onDone,
  });

  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDone;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _in = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    await _c.reverse();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Opacity(
                opacity: _c.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -70 * (1 - _in.value)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 58, 20, 0),
                child: CandyPanel(
                  gradient: CandyTheme.candyFor(widget.color),
                  radius: 22,
                  depth: 5,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 22,
                        shadows: const [
                          Shadow(
                            color: CandyTheme.outline,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: CandyText(
                          widget.message,
                          size: 13,
                          display: false,
                          outlineWidth: 2,
                          dropShadow: false,
                          align: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lumen, the mascot. Bobs gently so the screens feel alive.
class CandyMascot extends StatefulWidget {
  const CandyMascot({super.key, this.size = 96, this.flip = false});

  final double size;
  final bool flip;

  @override
  State<CandyMascot> createState() => _CandyMascotState();
}

class _CandyMascotState extends State<CandyMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    ProgressStore.instance.addListener(_syncMotion);
    _syncMotion();
  }

  void _syncMotion() {
    if (!mounted) return;
    if (ProgressStore.instance.reduceMotion) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    ProgressStore.instance.removeListener(_syncMotion);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(
      'assets/candy_mascot.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Transform.translate(
        offset: Offset(0, -5 + 10 * Curves.easeInOut.transform(_c.value)),
        child: widget.flip ? Transform.flip(flipX: true, child: art) : art,
      ),
    );
  }
}
