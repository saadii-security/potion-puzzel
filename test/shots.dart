// Throwaway harness: renders each screen to test/goldens/*.png so the UI can be
// eyeballed without a device. Run: flutter test test/shots_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potion_sort/core/theme.dart';
import 'package:potion_sort/data/progress_store.dart';
import 'package:potion_sort/domain/engine/puzzle_engine.dart';
import 'package:potion_sort/domain/rules/pour_rules.dart';
import 'package:potion_sort/game/bottle_board_layout.dart';
import 'package:potion_sort/presentation/home_screen.dart';
import 'package:potion_sort/presentation/lab_shop_events.dart';
import 'package:potion_sort/presentation/map_screen.dart';
import 'package:potion_sort/presentation/play_screen.dart';
import 'package:potion_sort/presentation/root_shell.dart';
import 'package:potion_sort/presentation/widgets/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registers every bundled family (ours plus MaterialIcons) so the shots look
/// like the shipped app instead of tofu boxes.
Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((font as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
  }
}

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(
          image.image,
          tester.element(find.byType(Image).first),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _shoot(WidgetTester tester, Widget body, String name) async {
  tester.view.physicalSize = const Size(880, 1900);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  // Tickers off: the mascot bob and level pulse would otherwise keep requesting
  // frames while runAsync drives the real event loop for image decoding.
  await tester.pumpWidget(
    MaterialApp(
      theme: CandyTheme.light(),
      debugShowCheckedModeBanner: false,
      home: TickerMode(enabled: false, child: body),
    ),
  );
  await tester.pump();
  await _settleImages(tester);
  await tester.pump(const Duration(milliseconds: 700));

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressStore.instance.load();
  });

  testWidgets('home', (tester) async {
    await _loadFonts();
    ProgressStore.instance.currentLevel = 12;
    ProgressStore.instance.starsTotal = 26;
    await _shoot(tester, HomeScreen(onTab: (_) {}), 'home');
  });

  testWidgets('map', (tester) async {
    await _loadFonts();
    ProgressStore.instance.currentLevel = 4;
    ProgressStore.instance.unlockedLevel = 4;
    ProgressStore.instance.bestStars.addAll({1: 3, 2: 2, 3: 3});
    await _shoot(tester, const MapScreen(), 'map');
  });

  testWidgets('play', (tester) async {
    await _loadFonts();
    await _shoot(tester, const PlayScreen(levelId: 9), 'play');
  });

  testWidgets('shop', (tester) async {
    await _loadFonts();
    await _shoot(tester, const ShopScreen(), 'shop');
  });

  testWidgets('splash', (tester) async {
    await _loadFonts();
    await _shoot(tester, const SplashGate(), 'splash');
  });

  // Liquid mid-transfer: tapped for real so the game builds the pour itself.
  testWidgets('pour', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(880, 1900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: CandyTheme.light(),
        debugShowCheckedModeBanner: false,
        home: const PlayScreen(levelId: 9),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      if ((tester.state(find.byType(PlayScreen)) as dynamic).engine != null) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _settleImages(tester);

    final engine =
        (tester.state(find.byType(PlayScreen)) as dynamic).engine
            as PuzzleEngine;
    final bottles = engine.bottles;

    // Prefer emptying into an empty vial: the rising column is easiest to read.
    var from = -1;
    var to = -1;
    for (var i = 0; i < bottles.length; i++) {
      for (var j = 0; j < bottles.length; j++) {
        if (!PourRules.canPour(bottles, i, j)) continue;
        if (from < 0 || bottles[j].isEmpty) {
          from = i;
          to = j;
        }
        if (bottles[to].isEmpty) break;
      }
    }
    expect(
      from,
      greaterThanOrEqualTo(0),
      reason: 'level 9 has no legal opening pour',
    );

    final board = tester.getRect(find.byKey(const ValueKey('potion-board')));
    final layout = BottleBoardLayout.of(
      count: bottles.length,
      canvas: board.size,
    );

    await tester.tapAt(board.topLeft + layout[from].center);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(board.topLeft + layout[to].center);

    // Land roughly halfway through the flow phase.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pour.png'),
    );

    // Late in the flow: source drained, target risen.
    await tester.pump(const Duration(milliseconds: 130));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pour_late.png'),
    );
    await tester.pump(const Duration(milliseconds: 600));
  });

  // Toast rides in an Overlay, so it has to be caught mid-animation.
  testWidgets('toast', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(880, 1900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: CandyTheme.light(),
        debugShowCheckedModeBanner: false,
        home: const ShopScreen(),
      ),
    );
    await tester.pump();
    await _settleImages(tester);

    await tester.tap(find.widgetWithText(CandyButton, '50'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await _settleImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/toast.png'),
    );

    // Let the toast retire; its dismissal timer would outlive the test.
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
  });

  // Praise popup, driven through the real board fields the game bumps.
  testWidgets('combo', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(880, 1900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PlayScreen(levelId: 31),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      if ((tester.state(find.byType(PlayScreen)) as dynamic).engine != null) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _settleImages(tester);

    final dynamic state = tester.state(find.byType(PlayScreen));
    state.game.comboEvents = 1;
    state.game.comboTier = 4;
    state.game.onChanged();

    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/combo.png'),
    );
  });

  // Win card needs live tickers: the star pops and sunburst are driven by
  // implicit animations that a muted TickerMode would freeze at zero scale.
  testWidgets('win', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(880, 1900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PlayScreen(levelId: 1),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      if ((tester.state(find.byType(PlayScreen)) as dynamic).engine != null) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }

    final dynamic state = tester.state(find.byType(PlayScreen));
    state.engine.applyPour(1, 0);
    state.game.onChanged();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('NEXT LEVEL').evaluate().isNotEmpty) break;
    }

    await _settleImages(tester);
    await tester.pump(const Duration(milliseconds: 1400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/win.png'),
    );
  });
}
