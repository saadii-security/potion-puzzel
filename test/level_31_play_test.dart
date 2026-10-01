import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide EnginePhase;
import 'package:potion_sort/domain/engine/puzzle_engine.dart';
import 'package:potion_sort/domain/levels/level_catalog.dart';
import 'package:potion_sort/domain/rules/pour_rules.dart';
import 'package:potion_sort/game/bottle_board_layout.dart';
import 'package:potion_sort/game/potion_game.dart';
import 'package:potion_sort/presentation/play_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nine-vial boards fit a phone playfield', () {
    const phone = Size(360, 400);
    final rects = BottleBoardLayout.of(count: 9, canvas: phone);
    expect(rects, hasLength(9));
    final bounds = rects.reduce((a, b) => a.expandToInclude(b));
    expect(bounds.left, greaterThanOrEqualTo(-0.01));
    expect(bounds.top, greaterThanOrEqualTo(-0.01));
    expect(bounds.right, lessThanOrEqualTo(phone.width + 0.01));
    expect(bounds.bottom, lessThanOrEqualTo(phone.height + 0.01));
  });

  test('level 31 engine accepts every legal first pour', () {
    final level = LevelCatalog.load(31);
    expect(level.bottles.length, greaterThan(8));
    var firstPours = 0;
    for (var i = 0; i < level.bottles.length; i++) {
      for (var j = 0; j < level.bottles.length; j++) {
        if (!PourRules.canPour(level.bottles, i, j)) continue;
        firstPours++;
        final trial = PuzzleEngine(level);
        expect(trial.applyPour(i, j), isNotNull);
      }
    }
    expect(firstPours, greaterThan(0));
  });

  testWidgets(
    'level 31 play screen survives load, pour, and frames',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      LevelCatalog.load(31);
      await tester.pumpWidget(const MaterialApp(home: PlayScreen(levelId: 31)));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        final engine =
            (tester.state(find.byType(PlayScreen)) as dynamic).engine;
        if (engine != null) break;
        await tester.pump(const Duration(milliseconds: 50));
      }
      final engine =
          (tester.state(find.byType(PlayScreen)) as dynamic).engine
              as PuzzleEngine;
      expect(engine.level.id, 31);

      PourMove? move;
      for (var i = 0; i < engine.bottles.length && move == null; i++) {
        for (var j = 0; j < engine.bottles.length && move == null; j++) {
          move = engine.applyPour(i, j);
        }
      }
      expect(move, isNotNull);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('potion board sleeps when idle and wakes for a pour', (
    tester,
  ) async {
    final engine = PuzzleEngine(LevelCatalog.load(1));
    final game = PotionGame(engine);
    final gameWidget = GameWidget(game: game);
    const canvas = Size(360, 400);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: canvas.width,
            height: canvas.height,
            child: gameWidget,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.paused, isTrue);

    final bottles = BottleBoardLayout.of(
      count: engine.bottles.length,
      canvas: canvas,
    );
    final board = tester.getRect(find.byWidget(gameWidget));
    await tester.tapAt(board.topLeft + bottles[1].center);
    await tester.tapAt(board.topLeft + bottles[0].center);
    expect(engine.moves, 1);
    expect(game.paused, isFalse);

    for (var i = 0; i < 80 && !game.paused; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.paused, isTrue);
    expect(engine.phase, EnginePhase.levelComplete);
  });

  testWidgets(
    'next vial stays on the same play screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: PlayScreen(levelId: 1)));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        final engine =
            (tester.state(find.byType(PlayScreen)) as dynamic).engine;
        if (engine != null) break;
        await tester.pump(const Duration(milliseconds: 50));
      }
      final engine =
          (tester.state(find.byType(PlayScreen)) as dynamic).engine
              as PuzzleEngine;
      expect(engine.applyPour(1, 0), isNotNull);
      (tester.state(find.byType(PlayScreen)) as dynamic).game.onChanged();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('NEXT LEVEL').evaluate().isNotEmpty) break;
      }
      expect(find.text('NEXT LEVEL'), findsOneWidget);
      await tester.tap(find.text('NEXT LEVEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PlayScreen), findsOneWidget);
      expect(find.textContaining('Lumen is brewing'), findsNothing);
      final next =
          (tester.state(find.byType(PlayScreen)) as dynamic).engine
              as PuzzleEngine;
      expect(next.level.id, 2);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
