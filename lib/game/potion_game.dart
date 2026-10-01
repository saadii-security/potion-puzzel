import 'dart:math' as math;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;

import '../core/theme.dart';
import '../data/progress_store.dart';
import '../domain/engine/puzzle_engine.dart';
import '../domain/models/bottle.dart';
import '../domain/models/potion_color.dart';
import '../services/haptics.dart';
import '../services/sfx.dart';
import 'bottle_board_layout.dart';

class PotionGame extends FlameGame with TapCallbacks {
  PotionGame(this.engine, {this.onChanged}) {
    _refreshComplete();
  }

  PuzzleEngine engine;
  VoidCallback? onChanged;
  _Pour? _pour;
  List<int>? hintPair;

  /// Bumped each time a vial is finished *after* the liquid lands, so praise
  /// popups fire with the pour instead of on the tap that started it.
  int comboEvents = 0;
  int comboTier = 0;

  bool get isAnimating => _pour != null;

  // Sparkles for juice when a bottle is completed
  final List<_Sparkle> _sparkles = [];

  // Bubbles state for each bottle to make them look alive
  final Map<int, List<_Bubble>> _bubblesMap = {};

  /// Surface wobble per vial, so the potion reads as liquid rather than paint.
  final Map<int, _Slosh> _slosh = {};
  final math.Random _random = math.Random();

  Size _layoutSize = Size.zero;
  int _layoutCount = -1;
  List<Rect> _cachedLayout = const [];
  final Map<int, Path> _glass = {};
  final Set<int> _complete = {};
  final List<Offset> _streamLeft = [];
  final List<Offset> _streamRight = [];
  final Path _streamRibbon = Path();
  final Path _streamGlint = Path();
  final Path _surfaceBand = Path();
  final Path _detailPath = Path();
  final Map<Essence, TextPainter> _glyphPainters = {};
  late final TextPainter _lockPainter = TextPainter(
    text: const TextSpan(
      text: '🔒',
      style: TextStyle(
        fontSize: 22,
        shadows: [
          Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  late final TextPainter _portalPainter = TextPainter(
    text: const TextSpan(
      text: '🌀',
      style: TextStyle(
        fontSize: 16,
        shadows: [
          Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final _paint = Paint();
  final _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  Color backgroundColor() => const Color(0x00000000);

  void bind(PuzzleEngine next) {
    Sfx.stopPour();
    engine = next;
    hintPair = null;
    _pour = null;
    _sparkles.clear();
    _bubblesMap.clear();
    _slosh.clear();
    _glass.clear();
    _cachedLayout = const [];
    _layoutCount = -1;
    _refreshComplete();
    resumeEngine();
  }

  void _refreshComplete() {
    _complete.clear();
    for (var i = 0; i < engine.bottles.length; i++) {
      if (engine.bottles[i].isCompleteColor(engine.bottles)) {
        _complete.add(i);
      }
    }
  }

  void flashHint(List<int>? pair) {
    hintPair = pair;
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update pouring animation
    final pour = _pour;
    if (pour != null) {
      pour.t += dt / pour.duration;
      if (pour.isFlowing) {
        if (!pour.flowKicked) {
          pour.flowKicked = true;
          _sloshFor(pour.to).kick(2.4);
        }
        _spawnSplash(pour, dt);
      }
      if (pour.t >= 1) _finishPour();
    }

    for (final s in _slosh.values) {
      s.update(dt);
    }

    // Update sparkles
    for (var i = _sparkles.length - 1; i >= 0; i--) {
      final s = _sparkles[i];
      s.life -= dt;
      if (s.life <= 0) {
        _sparkles.removeAt(i);
      } else {
        // Apply gravity
        s.velocity = Offset(s.velocity.dx, s.velocity.dy + s.gravity * dt);
        s.position = s.position + s.velocity * dt;
      }
    }

    // Update bubbles
    for (var i = 0; i < engine.bottles.length; i++) {
      final bottle = engine.bottles[i];
      if (bottle.layers.isEmpty) continue;

      if (!_bubblesMap.containsKey(i)) {
        _bubblesMap[i] = List.generate(3, (_) => _Bubble(_random));
      }

      final bubbles = _bubblesMap[i]!;
      for (final b in bubbles) {
        b.update(
          dt,
          bottle.layers.length * 25.0,
        ); // limit bubble height to liquid level
      }
    }

    if (_pour == null &&
        _sparkles.isEmpty &&
        !_slosh.values.any((slosh) => slosh.isMoving)) {
      pauseEngine();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    // A paused Flame game still receives pointer events. Wake it so this
    // interaction gets painted, then update() sleeps it again once still.
    resumeEngine();
    final i = _hit(event.canvasPosition);
    if (i == null) return;

    // A tap during a pour must not orphan the one in flight: land it first so
    // its sparkles, combo and sound still fire.
    if (_pour != null) _finishPour();

    final move = engine.tap(i);
    if (move != null) {
      _refreshComplete();
      final destination = engine.bottles[move.to];
      _pour = _Pour(
        from: move.from,
        to: move.to,
        count: move.count,
        essence: move.essence,
        fromBefore: engine.bottles[move.from].layers.length + move.count,
        toBefore: destination.layers.length - move.count,
      );
      _sloshFor(move.from).kick(1.8);
      Haptics.pour();
      Sfx.pour();
    } else if (engine.selected != null) {
      _sloshFor(i).kick(1.5);
      Haptics.tap();
      Sfx.tap();
    } else {
      Haptics.nope();
      Sfx.nope();
    }
    hintPair = null;
    onChanged?.call();
  }

  /// Settles the in-flight pour and fires everything that waits on the liquid
  /// actually landing.
  void _finishPour() {
    final pour = _pour;
    if (pour == null) return;
    _pour = null;
    Sfx.stopPour();
    _sloshFor(pour.to).kick(3.0);

    final dest = pour.to;
    if (dest >= 0 && dest < engine.bottles.length && _complete.contains(dest)) {
      _triggerSparkleBurst(dest);
      if (engine.phase != EnginePhase.levelComplete) {
        Haptics.vialDone();
      }
      comboEvents += 1;
      comboTier = engine.combo;
      if (comboTier >= 2) {
        Sfx.combo(comboTier);
      } else {
        Sfx.vialDone();
      }
    }
    onChanged?.call();
  }

  _Slosh _sloshFor(int index) =>
      _slosh.putIfAbsent(index, () => _Slosh(_random));

  /// Droplets kicked up where the stream hits the surface.
  void _spawnSplash(_Pour pour, double dt) {
    pour.splashDebt += dt;
    if (pour.splashDebt < 0.09) return;
    pour.splashDebt = 0;

    final layout = _layout();
    if (pour.to >= layout.length) return;
    final rect = layout[pour.to];
    final impact = Offset(
      rect.center.dx,
      _surfaceY(rect, engine.bottles[pour.to], pour.targetLayers),
    );

    _sparkles.add(
      _Sparkle(
        position: impact,
        velocity: Offset(
          (_random.nextDouble() * 2 - 1) * 55,
          -30 - _random.nextDouble() * 55,
        ),
        color: pour.essence.tint,
        maxLife: 0.22 + _random.nextDouble() * 0.18,
        gravity: 520,
        droplet: true,
      ),
    );
  }

  int? _hit(Vector2 p) {
    final layout = _layout();
    for (var i = 0; i < layout.length; i++) {
      if (layout[i].contains(Offset(p.x, p.y))) return i;
    }
    return null;
  }

  List<Rect> _layout() {
    if (!hasLayout) return const [];
    final canvas = Size(size.x, size.y);
    final count = engine.bottles.length;
    if (_cachedLayout.length == count &&
        _layoutSize == canvas &&
        _layoutCount == count) {
      return _cachedLayout;
    }
    _layoutSize = canvas;
    _layoutCount = count;
    _glass.clear();
    _cachedLayout = BottleBoardLayout.of(count: count, canvas: canvas);
    return _cachedLayout;
  }

  Path _glassPath(Rect r) =>
      _glass.putIfAbsent(_glassKey(r), () => _buildGlass(r));

  int _glassKey(Rect r) => Object.hash(
    r.left.round(),
    r.top.round(),
    r.width.round(),
    r.height.round(),
  );

  Path _buildGlass(Rect r) {
    final w = r.width;
    final h = r.height;
    final neck = w * 16 / 68;
    final wall = math.max(1.0, w * 4 / 68);
    final bulge = w * 24 / 68;
    final baseDip = h * 4 / 160;
    return Path()
      ..moveTo(r.left + neck, r.top + h * 20 / 160)
      ..lineTo(r.left + neck, r.top + h * 32 / 160)
      ..cubicTo(
        r.left + neck,
        r.top + h * 45 / 160,
        r.left + wall,
        r.top + h * 55 / 160,
        r.left + wall,
        r.top + h * 70 / 160,
      )
      ..lineTo(r.left + wall, r.bottom - h * 16 / 160)
      ..quadraticBezierTo(
        r.left + wall,
        r.bottom + baseDip,
        r.left + bulge,
        r.bottom + baseDip,
      )
      ..lineTo(r.right - bulge, r.bottom + baseDip)
      ..quadraticBezierTo(
        r.right - wall,
        r.bottom + baseDip,
        r.right - wall,
        r.bottom - h * 16 / 160,
      )
      ..lineTo(r.right - wall, r.top + h * 70 / 160)
      ..cubicTo(
        r.right - wall,
        r.top + h * 55 / 160,
        r.right - neck,
        r.top + h * 45 / 160,
        r.right - neck,
        r.top + h * 32 / 160,
      )
      ..lineTo(r.right - neck, r.top + h * 20 / 160)
      ..close();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!hasLayout) return;
    final layout = _layout();
    if (layout.length != engine.bottles.length) return;

    final pour = _pour;
    final pouring =
        pour != null && pour.from < layout.length && pour.to < layout.length;

    // 1. Every vial except the one in the air. The target draws a rising
    // column so the liquid arrives instead of appearing.
    for (var i = 0; i < engine.bottles.length; i++) {
      if (pouring && i == pour.from) continue;
      _drawBottle(
        canvas,
        layout[i],
        engine.bottles[i],
        i,
        fillLayers: pouring && i == pour.to ? pour.targetLayers : null,
      );
    }

    // 2. The stream, then the tilted vial over it so the liquid reads as
    // leaving the spout from behind the glass.
    if (pouring) {
      final frame = _pourFrame(layout[pour.from], layout[pour.to], pour);
      if (pour.isFlowing) {
        _drawStream(canvas, pour, layout[pour.from], layout[pour.to], frame);
      }
      _drawBottle(
        canvas,
        layout[pour.from],
        engine.bottles[pour.from],
        pour.from,
        frame: frame,
        fillLayers: pour.sourceLayers,
        phantom: pour.essence,
      );
    }

    // 3. Draw sparkles and splash droplets
    for (final s in _sparkles) {
      final pct = s.life / s.maxLife;
      if (s.droplet) {
        canvas.drawCircle(
          s.position,
          2.6 * pct + 0.8,
          _paint
            ..style = PaintingStyle.fill
            ..color = s.color.withValues(alpha: pct * 0.95),
        );
        continue;
      }
      canvas.drawCircle(
        s.position,
        3.5 * pct,
        _paint
          ..style = PaintingStyle.fill
          ..color = s.color.withValues(alpha: pct),
      );
      // Draw inner white core
      canvas.drawCircle(
        s.position,
        1.5 * pct,
        _paint..color = Colors.white.withValues(alpha: pct),
      );
    }
  }

  /// Liquid box geometry, shared by the column renderer and the pour stream so
  /// the surface height they compute can never drift apart.
  ({double layerH, double floor, double pad}) _liquidMetrics(
    Rect r,
    PotionBottle bottle,
  ) {
    final cap = math.max(1, bottle.capacity);
    final totalLiquidHeight = math.max(8.0, r.height - r.height * 0.34);
    return (
      layerH: totalLiquidHeight / cap,
      floor: math.max(4.0, r.height * 12 / 160),
      pad: math.max(2.0, r.width * 7 / 68),
    );
  }

  /// Height of the liquid surface for a (possibly fractional) column.
  double _surfaceY(Rect r, PotionBottle bottle, double layers) {
    final m = _liquidMetrics(r, bottle);
    return r.bottom - m.floor - layers * m.layerH;
  }

  /// Where a pouring vial sits: lifted toward its target and tilted so the
  /// spout hangs over the mouth.
  _PourFrame _pourFrame(Rect source, Rect target, _Pour pour) {
    final tilt = pour.tilt;
    final toward = target.center.dx > source.center.dx ? 1.0 : -1.0;
    return _PourFrame(
      // Less rotation, more travel: the vial leans over its target rather than
      // turning on its side, which keeps the potion inside it believable.
      offset: Offset(
        (target.center.dx - source.center.dx) * tilt * 0.54,
        (target.center.dy - source.center.dy - source.height * 0.82) *
            tilt *
            0.62,
      ),
      // Tilting about the spout keeps the mouth over the target vial.
      pivot: Offset(source.center.dx, source.top + source.height * 0.10),
      angle: toward * tilt * (math.pi / 4.9),
    );
  }

  /// Falling liquid: a tapered ribbon from the spout to the rising surface,
  /// widest where it leaves the vial and thinning as it speeds up.
  void _drawStream(
    Canvas canvas,
    _Pour pour,
    Rect source,
    Rect target,
    _PourFrame frame,
  ) {
    final w = source.width;
    final neck = w * 16 / 68;
    final toward = target.center.dx > source.center.dx ? 1.0 : -1.0;

    // Lip corner on the side the vial is tilted toward.
    final spout = frame.apply(
      Offset(
        toward > 0 ? source.right - neck + 2 : source.left + neck - 2,
        source.top + source.height * 0.10,
      ),
    );
    final landing = Offset(
      target.center.dx,
      _surfaceY(target, engine.bottles[pour.to], pour.targetLayers),
    );
    if (landing.dy <= spout.dy + 4) return;

    // Arc out of the spout, then fall.
    final c1 = Offset(spout.dx + (landing.dx - spout.dx) * 0.42, spout.dy + 14);
    final c2 = Offset(landing.dx, spout.dy + (landing.dy - spout.dy) * 0.55);

    Offset at(double t) {
      final u = 1 - t;
      return spout * (u * u * u) +
          c1 * (3 * u * u * t) +
          c2 * (3 * u * t * t) +
          landing * (t * t * t);
    }

    // Grow in and taper out so the stream never pops on or off.
    final envelope =
        math.min(1.0, pour.flow * 7) * math.min(1.0, (1 - pour.flow) * 7);
    final wobble = pour.t * 26;

    const steps = 10;
    _streamLeft.clear();
    _streamRight.clear();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final p = at(t);
      final next = at(math.min(1.0, t + 0.04));
      final prev = at(math.max(0.0, t - 0.04));
      final dir = next - prev;
      final len = dir.distance;
      if (len < 0.001) continue;
      final normal = Offset(-dir.dy / len, dir.dx / len);

      final half =
          (5.2 - 2.0 * t) * envelope +
          math.sin(wobble + t * 7) * 0.55 * envelope;
      _streamLeft.add(p + normal * half);
      _streamRight.add(p - normal * half);
    }
    if (_streamLeft.length < 2) return;

    _streamRibbon
      ..reset()
      ..moveTo(_streamLeft.first.dx, _streamLeft.first.dy);
    for (var i = 1; i < _streamLeft.length; i++) {
      final p = _streamLeft[i];
      _streamRibbon.lineTo(p.dx, p.dy);
    }
    for (var i = _streamRight.length - 1; i >= 0; i--) {
      final p = _streamRight[i];
      _streamRibbon.lineTo(p.dx, p.dy);
    }
    _streamRibbon.close();

    _stroke
      ..color = CandyTheme.grapeDeep.withValues(alpha: 0.45 * envelope)
      ..strokeWidth = 2.6
      ..shader = null;
    canvas.drawPath(_streamRibbon, _stroke);
    _paint
      ..color = pour.essence.tint.withValues(alpha: 0.95)
      ..shader = null;
    canvas.drawPath(_streamRibbon, _paint);

    _stroke
      ..color = Colors.white.withValues(alpha: 0.55 * envelope)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    _streamGlint
      ..reset()
      ..moveTo(_streamLeft.first.dx, _streamLeft.first.dy);
    for (var i = 1; i < _streamLeft.length; i++) {
      final p = _streamLeft[i];
      _streamGlint.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(_streamGlint, _stroke);

    canvas.drawOval(
      Rect.fromCenter(
        center: landing,
        width: 22 * envelope,
        height: 7 * envelope,
      ),
      _stroke
        ..color = pour.essence.tint.withValues(alpha: 0.75 * envelope)
        ..strokeWidth = 2,
    );
  }

  /// Draws one vial.
  ///
  /// [fillLayers] overrides the column height with a fractional layer count so
  /// liquid can drain and fill continuously; indices above the vial's real
  /// layers are painted in [phantom], which is how the source keeps showing
  /// the potion that has not left the glass yet.
  void _drawBottle(
    Canvas canvas,
    Rect rect,
    PotionBottle bottle,
    int index, {
    _PourFrame? frame,
    double? fillLayers,
    Essence? phantom,
  }) {
    final isPouring = frame != null;
    final selected = engine.selected == index;
    final hinted = hintPair != null && hintPair!.contains(index);

    canvas.save();

    // Apply translation and rotation if pouring.
    // ponytail: the potion rides the glass instead of staying level, which the
    // ~53° tilt cap keeps believable; a level surface would need the columns
    // re-projected per frame.
    Rect r = rect;
    if (frame != null) {
      canvas.translate(frame.offset.dx, frame.offset.dy);
      canvas.translate(frame.pivot.dx, frame.pivot.dy);
      canvas.rotate(frame.angle);
      canvas.translate(-frame.pivot.dx, -frame.pivot.dy);
    } else {
      // Normal selection lift
      final lift = selected ? -12.0 : 0.0;
      r = rect.translate(0, lift);
    }

    // Hint halo — soft candy glow rather than a hard frame.
    if (hinted) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.inflate(9), const Radius.circular(24)),
        _paint
          ..style = PaintingStyle.fill
          ..color = CandyTheme.goldLight.withValues(alpha: 0.28),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.inflate(7), const Radius.circular(22)),
        _stroke
          ..color = CandyTheme.gold
          ..strokeWidth = 3,
      );
    }

    // Selection halo.
    if (selected && !isPouring) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.inflate(8), const Radius.circular(22)),
        _paint
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: 0.22),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.inflate(5), const Radius.circular(20)),
        _stroke
          ..color = CandyTheme.goldLight
          ..strokeWidth = 3.5,
      );
    }

    final w = r.width;
    final h = r.height;
    if (w < 8 || h < 16) {
      canvas.restore();
      return;
    }
    final neck = w * 16 / 68;
    final wall = math.max(1.0, w * 4 / 68);
    final glass = _glassPath(r);

    // Contact shadow under the vial.
    if (!isPouring) {
      _paint
        ..color = CandyTheme.grapeDeep.withValues(alpha: 0.35)
        ..shader = null;
      canvas.drawOval(
        Rect.fromLTRB(r.left + 7, r.bottom + 5, r.right - 7, r.bottom + 13),
        _paint,
      );
    }

    _paint
      ..color = Colors.white.withValues(alpha: 0.20)
      ..shader = null;
    canvas.drawPath(glass, _paint);

    // Draw Liquid Layers
    final cap = math.max(1, bottle.capacity);
    final metrics = _liquidMetrics(r, bottle);
    final layerH = metrics.layerH;
    final floor = metrics.floor;
    final liquidPad = metrics.pad;
    final topR = math.min(8.0, layerH / 2);
    final botR = math.min(16.0, layerH / 2);

    // A pour drains or fills by fractions of a layer; everything else shows
    // whole layers.
    final filled = (fillLayers ?? bottle.layers.length.toDouble()).clamp(
      0.0,
      cap.toDouble(),
    );
    final columns = filled.ceil();
    final topFraction = filled - filled.floor();
    final slosh = _sloshFor(index);

    // Potion stays level while the glass tips: the columns are drawn with the
    // tilt undone, pooled at the lowest corner of the tilted vial and clipped
    // to it. The extra height makes up for how narrow that corner is.
    var pool = Rect.fromLTRB(
      r.left + liquidPad,
      r.top,
      r.right - liquidPad,
      r.bottom - floor,
    );
    var poolLayerH = layerH;
    if (frame != null) {
      // Anchored to the tilted glass itself, not the upright liquid box, so
      // the potion also fills the neck it is running out of.
      final inner = Rect.fromLTRB(
        r.left + wall,
        r.top + h * 20 / 160,
        r.right - wall,
        r.bottom,
      );
      final bottomLeft = frame.rotate(inner.bottomLeft);
      final bottomRight = frame.rotate(inner.bottomRight);
      final topLeft = frame.rotate(inner.topLeft);
      final topRight = frame.rotate(inner.topRight);
      pool = Rect.fromLTRB(
        math.min(
          math.min(bottomLeft.dx, bottomRight.dx),
          math.min(topLeft.dx, topRight.dx),
        ),
        math.min(
          math.min(bottomLeft.dy, bottomRight.dy),
          math.min(topLeft.dy, topRight.dy),
        ),
        math.max(
          math.max(bottomLeft.dx, bottomRight.dx),
          math.max(topLeft.dx, topRight.dx),
        ),
        math.max(
          math.max(bottomLeft.dy, bottomRight.dy),
          math.max(topLeft.dy, topRight.dy),
        ),
      );
      poolLayerH = layerH / math.max(0.45, math.cos(frame.angle));

      canvas.save();
      canvas.clipPath(glass);
      canvas.translate(frame.pivot.dx, frame.pivot.dy);
      canvas.rotate(-frame.angle);
      canvas.translate(-frame.pivot.dx, -frame.pivot.dy);
    }

    for (var i = 0; i < columns; i++) {
      final isTop = i == columns - 1;
      final fraction = isTop && topFraction > 0.001 ? topFraction : 1.0;
      final layer = i < bottle.layers.length ? bottle.layers[i] : null;
      final essence = layer?.visible ?? phantom;
      if (essence == null) continue;
      final color = ProgressStore.instance.colorblind
          ? essence.tint.withValues(alpha: 0.85)
          : essence.tint;

      final lb = pool.bottom - i * poolLayerH;
      final lr = Rect.fromLTRB(
        pool.left,
        lb - poolLayerH * fraction,
        pool.right,
        lb + 1.5,
      );
      if (lr.width <= 0 || lr.height <= 0) continue;

      // The surface rides a wave, so the flat top of the column is pushed down
      // under the band that paints it.
      final wave = isTop ? math.min(slosh.amp, lr.height * 0.34) : 0.0;
      final body = Rect.fromLTRB(lr.left, lr.top + wave, lr.right, lr.bottom);

      // Draw liquid block with rounded corners
      final liquidRRect = RRect.fromRectAndCorners(
        body,
        topLeft: isTop ? Radius.circular(topR) : Radius.zero,
        topRight: isTop ? Radius.circular(topR) : Radius.zero,
        bottomLeft: i == 0 ? Radius.circular(botR) : Radius.zero,
        bottomRight: i == 0 ? Radius.circular(botR) : Radius.zero,
      );

      // Solid fill plus a sheen — a new LinearGradient shader every layer
      // every frame is what made the board hitch on mid-range phones.
      _paint
        ..color = color
        ..shader = null;
      canvas.drawRRect(liquidRRect, _paint);

      // Vertical sheen down the shoulder of the column.
      final sheen = Rect.fromLTWH(
        body.left + body.width * 0.13,
        body.top + 1.5,
        math.max(2.0, body.width * 0.15),
        math.max(2.0, body.height - 4),
      );
      _paint.color = Colors.white.withValues(alpha: 0.20);
      canvas.drawRRect(
        RRect.fromRectAndRadius(sheen, Radius.circular(sheen.width / 2)),
        _paint,
      );

      _stroke
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 1.2
        ..shader = null;
      canvas.drawRRect(liquidRRect, _stroke);

      // Living surface on the top layer: a wave band instead of a flat cap.
      if (isTop) {
        final light = Color.lerp(color, Colors.white, 0.35)!;
        if (wave > 1.15) {
          _drawSurface(canvas, lr, wave, light, slosh);
        } else {
          final capH = math.min(9.0, math.max(3.0, lr.height * 0.42));
          final cap = Rect.fromLTRB(
            lr.left + 1.5,
            lr.top - 1,
            lr.right - 1.5,
            lr.top + capH,
          );
          _paint.color = light.withValues(alpha: 0.95);
          canvas.drawOval(cap, _paint);
          _paint.color = Colors.white.withValues(alpha: 0.45);
          canvas.drawOval(
            Rect.fromLTRB(
              cap.left + cap.width * 0.18,
              cap.top + capH * 0.22,
              cap.left + cap.width * 0.52,
              cap.top + capH * 0.72,
            ),
            _paint,
          );
        }
      }

      // Draw Colorblind Glyph
      if (ProgressStore.instance.colorblind && layer != null) {
        final tp = _glyphPainters.putIfAbsent(
          layer.visible,
          () => TextPainter(
            text: TextSpan(
              text: layer.visible.glyph,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
        );
        tp.paint(
          canvas,
          Offset(lr.center.dx - tp.width / 2, lr.center.dy - tp.height / 2),
        );
      }

      // Draw Crystal lid — ice/gem overlay, not a "forbidden" slash.
      if (layer != null && layer.crystal) {
        canvas.drawRRect(
          liquidRRect,
          _paint
            ..style = PaintingStyle.fill
            ..color = const Color(0x99D7EEFF),
        );
        _detailPath
          ..reset()
          ..moveTo(lr.center.dx, lr.top + 4)
          ..lineTo(lr.right - 10, lr.center.dy)
          ..lineTo(lr.center.dx, lr.bottom - 4)
          ..lineTo(lr.left + 10, lr.center.dy)
          ..close();
        canvas.drawPath(
          _detailPath,
          _stroke
            ..color = Colors.white.withValues(alpha: 0.85)
            ..strokeWidth = 2,
        );
        canvas.drawPath(_detailPath, _paint..color = const Color(0x55B8E0FF));
        canvas.drawCircle(
          Offset(lr.center.dx - 6, lr.center.dy - 4),
          1.6,
          _paint..color = Colors.white,
        );
      }

      // Draw Frozen Blocker
      if (layer != null && layer.frozen) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(lr, const Radius.circular(4)),
          _paint
            ..style = PaintingStyle.fill
            ..color = const Color(0x77A5F2F3),
        );
        // Draw ice sparkles
        _stroke
          ..color = Colors.white
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(lr.left + 10, lr.top + 4),
          Offset(lr.left + 14, lr.top + 10),
          _stroke,
        );
        canvas.drawLine(
          Offset(lr.right - 10, lr.bottom - 4),
          Offset(lr.right - 14, lr.bottom - 10),
          _stroke,
        );
      }
    }

    if (frame != null) canvas.restore();

    // Draw Bubbles
    if (!isPouring &&
        _bubblesMap.containsKey(index) &&
        bottle.layers.isNotEmpty) {
      final bubbles = _bubblesMap[index]!;
      final maxLiquidY = r.bottom - floor - (bottle.layers.length * layerH);
      for (final b in bubbles) {
        final bx = r.left + 12 + b.x * (r.width - 24);
        final by = r.bottom - 16 - b.y;
        // Only draw bubble if it is inside the liquid
        if (by > maxLiquidY) {
          _paint
            ..color = Colors.white.withValues(alpha: b.opacity)
            ..shader = null;
          canvas.drawCircle(Offset(bx, by), b.size, _paint);
        }
      }
    }

    _stroke
      ..color = CandyTheme.grapeDeep
      ..strokeWidth = selected ? 6.5 : 5.0
      ..shader = null
      ..strokeCap = StrokeCap.butt;
    canvas.drawPath(glass, _stroke);
    _stroke
      ..color = selected
          ? CandyTheme.goldLight
          : Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = selected ? 3.4 : 2.6;
    canvas.drawPath(glass, _stroke);

    _stroke
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = math.max(2.0, w * 0.06)
      ..strokeCap = StrokeCap.round;
    _detailPath
      ..reset()
      ..moveTo(r.left + w * 0.16, r.top + h * 0.46)
      ..lineTo(r.left + w * 0.16, r.bottom - h * 0.14)
      ..quadraticBezierTo(
        r.left + w * 0.16,
        r.bottom - h * 0.06,
        r.left + w * 0.30,
        r.bottom - h * 0.04,
      );
    canvas.drawPath(_detailPath, _stroke);

    final rimRect = Rect.fromLTRB(
      r.left + neck - 2,
      r.top + h * 0.07,
      r.right - neck + 2,
      r.top + h * 0.13,
    );
    _paint
      ..color = Colors.white.withValues(alpha: 0.55)
      ..shader = null;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, const Radius.circular(5)),
      _paint,
    );
    _stroke
      ..color = CandyTheme.grapeDeep
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.butt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, const Radius.circular(5)),
      _stroke,
    );

    // Cork only a vial that actually holds a finished brew — never a full
    // vial that still has leftover drops of the same color elsewhere, and not
    // before the liquid that finishes it has landed.
    if (!isPouring && fillLayers == null && _complete.contains(index)) {
      final corkRect = Rect.fromLTRB(
        r.left + neck,
        r.top + h * 0.01,
        r.right - neck,
        r.top + h * 0.085,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(corkRect, const Radius.circular(4)),
        _paint
          ..color = CandyTheme.gold
          ..shader = null,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(corkRect, const Radius.circular(4)),
        _stroke
          ..color = CandyTheme.grapeDeep
          ..strokeWidth = 2.2,
      );
    }

    // Draw Lock Icon
    if (bottle.locked) {
      _lockPainter.paint(canvas, Offset(r.center.dx - 11, r.center.dy - 12));
    }

    // Draw Portal Connection Icon
    if (bottle.portalTwin != null) {
      _portalPainter.paint(canvas, Offset(r.center.dx - 8, r.top - 6));
    }

    // Draw Target Essence Indicator
    if (bottle.targetEssence != null) {
      final targetColor = bottle.targetEssence!.tint;
      canvas.drawCircle(
        Offset(r.center.dx, r.bottom + 12),
        6,
        _paint
          ..color = targetColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(r.center.dx, r.bottom + 12),
        8,
        _stroke
          ..color = Colors.white.withValues(alpha: 0.8)
          ..strokeWidth = 1.5,
      );
    }

    canvas.restore();
  }

  /// The liquid surface: a travelling wave capped with a glossy meniscus.
  /// [wave] is the amplitude the column top was pushed down by, so the band
  /// always covers the flat edge underneath it.
  void _drawSurface(
    Canvas canvas,
    Rect lr,
    double wave,
    Color light,
    _Slosh slosh,
  ) {
    if (lr.width <= 2) return;
    const steps = 14;
    final crest = lr.top + wave;
    _surfaceBand.reset();

    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final x = lr.left + lr.width * f;
      // Two frequencies so the surface never looks like a clean sine.
      final y =
          crest +
          wave * math.sin(slosh.phase + f * math.pi * 2.1) * 0.7 +
          wave * math.sin(slosh.phase * 1.7 + f * math.pi * 3.4) * 0.3;
      if (i == 0) {
        _surfaceBand.moveTo(x, y);
      } else {
        _surfaceBand.lineTo(x, y);
      }
    }
    final skirt = crest + math.max(2.5, wave * 2.4);
    _surfaceBand
      ..lineTo(lr.right, skirt)
      ..lineTo(lr.left, skirt)
      ..close();

    canvas.drawPath(
      _surfaceBand,
      _paint
        ..color = light.withValues(alpha: 0.95)
        ..shader = null,
    );

    final glintX = lr.left + lr.width * (0.3 + 0.12 * math.sin(slosh.phase));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(glintX, crest + math.max(1.5, wave * 0.9)),
        width: math.max(4.0, lr.width * 0.3),
        height: math.max(2.0, wave * 1.6 + 1.5),
      ),
      _paint..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  void _triggerSparkleBurst(int bottleIndex) {
    final layout = _layout();
    if (bottleIndex < 0 || bottleIndex >= layout.length) return;
    final rect = layout[bottleIndex];
    final mouth = Offset(rect.center.dx, rect.top + 15);
    final color = engine.bottles[bottleIndex].layers.isNotEmpty
        ? engine.bottles[bottleIndex].layers.last.visible.tint
        : const Color(0xFFFFD166);

    for (var i = 0; i < 12; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 50.0 + _random.nextDouble() * 70.0;
      _sparkles.add(
        _Sparkle(
          position: mouth,
          velocity: Offset(
            math.cos(angle) * speed,
            math.sin(angle) * speed - 40.0,
          ), // bias upwards
          color: color,
          maxLife: 0.5 + _random.nextDouble() * 0.4,
        ),
      );
    }
  }
}

// Helper class for rendering completed bottle sparkles and splash droplets
class _Sparkle {
  Offset position;
  Offset velocity;
  final Color color;
  final double maxLife;
  final double gravity;
  final bool droplet;
  double life;
  _Sparkle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.maxLife,
    this.gravity = 150,
    this.droplet = false,
  }) : life = maxLife;
}

/// One pour in flight.
///
/// The engine moves the layers the instant a vial is tapped, so this records
/// what left and what arrived and replays it over [duration]: the source
/// drains, the target fills, and a stream joins the two.
class _Pour {
  _Pour({
    required this.from,
    required this.to,
    required this.count,
    required this.essence,
    required this.fromBefore,
    required this.toBefore,
  }) : duration = ProgressStore.instance.reduceMotion
           ? 0.18
           : 0.34 + 0.085 * count;

  final int from;
  final int to;
  final int count;
  final Essence essence;
  final int fromBefore;
  final int toBefore;
  final double duration;

  double t = 0;
  double splashDebt = 0;
  bool flowKicked = false;

  // Tilt up, pour, tilt back.
  static const _flowStart = 0.24;
  static const _flowEnd = 0.84;

  double get tilt {
    if (t <= _flowStart) {
      return Curves.easeOutCubic.transform((t / _flowStart).clamp(0.0, 1.0));
    }
    if (t >= _flowEnd) {
      return 1 -
          Curves.easeInCubic.transform(
            ((t - _flowEnd) / (1 - _flowEnd)).clamp(0.0, 1.0),
          );
    }
    return 1;
  }

  bool get isFlowing => t > _flowStart && t < _flowEnd;

  /// How much of the pour has left the spout.
  double get flow =>
      ((t - _flowStart) / (_flowEnd - _flowStart)).clamp(0.0, 1.0);

  double get sourceLayers => fromBefore - count * flow;

  /// The target fills a beat behind the source, the time the liquid spends
  /// falling.
  double get targetLayers =>
      toBefore + count * ((flow - 0.14) / 0.86).clamp(0.0, 1.0);
}

/// Position and tilt of a vial mid-pour. Shared by the vial renderer and the
/// stream so the liquid always leaves the spout exactly where it is drawn.
class _PourFrame {
  _PourFrame({required this.offset, required this.pivot, required this.angle});

  final Offset offset;
  final Offset pivot;
  final double angle;

  /// Tilt only, without the travel — the frame a canvas is left in after the
  /// rotation is undone.
  Offset rotate(Offset p) {
    final v = p - pivot;
    final c = math.cos(angle);
    final s = math.sin(angle);
    return pivot + Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  Offset apply(Offset p) => rotate(p) + offset;
}

/// Surface wobble for one vial: kicked when the potion is disturbed, settling
/// back to a faint idle ripple.
class _Slosh {
  _Slosh(math.Random rand)
    : phase = rand.nextDouble() * math.pi * 2,
      speed = 5.6 + rand.nextDouble() * 1.8;

  static const idle = 0.8;

  double phase;
  final double speed;
  double amp = idle;

  bool get isMoving {
    final rest = ProgressStore.instance.reduceMotion ? 0.0 : idle;
    return amp > rest + 0.05;
  }

  void update(double dt) {
    final rest = ProgressStore.instance.reduceMotion ? 0.0 : idle;
    if (amp <= rest + 0.05) {
      amp = rest;
      return;
    }
    phase += speed * dt;
    amp = rest + (amp - rest) * math.exp(-4.2 * dt);
  }

  void kick(double strength) {
    if (ProgressStore.instance.reduceMotion) return;
    if (strength > amp) amp = strength;
  }
}

// Helper class for rendering floating bubbles
class _Bubble {
  _Bubble(this.rand) {
    reset(true);
  }

  final math.Random rand;
  late double x;
  late double y;
  late double speed;
  late double size;
  late double opacity;

  void reset(bool randomY) {
    x = rand.nextDouble();
    y = randomY ? rand.nextDouble() * 100.0 : 0.0;
    speed = 15.0 + rand.nextDouble() * 25.0;
    size = 1.0 + rand.nextDouble() * 2.5;
    opacity = 0.15 + rand.nextDouble() * 0.35;
  }

  void update(double dt, double maxHeight) {
    y += speed * dt;
    if (y > maxHeight || maxHeight == 0) {
      reset(false);
    }
  }
}
