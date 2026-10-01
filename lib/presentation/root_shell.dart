import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'home_screen.dart';
import 'lab_shop_events.dart';
import 'map_screen.dart';
import 'widgets/shell.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int tab = 0;

  static const _tabs = [
    (Icons.home_rounded, 'Home', CandyTheme.green),
    (Icons.map_rounded, 'Map', CandyTheme.blue),
    (Icons.science_rounded, 'Lab', CandyTheme.pink),
    (Icons.event_rounded, 'Events', CandyTheme.orange),
    (Icons.storefront_rounded, 'Shop', CandyTheme.gold),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onTab: (i) => setState(() => tab = i)),
      const MapScreen(),
      const LabScreen(),
      const EventsScreen(),
      const ShopScreen(),
    ];

    return Scaffold(
      backgroundColor: CandyTheme.grapeDeep,
      body: pages[tab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: CandyTheme.candy(
            CandyTheme.grape,
            CandyTheme.grapeDark,
            CandyTheme.grapeDeep,
          ),
          border: const Border(
            top: BorderSide(color: CandyTheme.goldDark, width: 3),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _navTab(
                    index: i,
                    icon: _tabs[i].$1,
                    label: _tabs[i].$2,
                    color: _tabs[i].$3,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTab({
    required int index,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final active = tab == index;
    void select() => setState(() => tab = index);
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: label,
      onTap: select,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: select,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 40,
                  decoration: active
                      ? CandyTheme.bevel(
                          gradient: CandyTheme.candyFor(color),
                          radius: 16,
                          depth: 3,
                          rimWidth: 2.5,
                        )
                      : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (active)
                        Positioned.fill(
                          child: CandyGloss(radius: 12, heightFactor: 0.44),
                        ),
                      Icon(
                        icon,
                        size: active ? 24 : 22,
                        color: active ? Colors.white : Colors.white60,
                        shadows: const [
                          Shadow(
                            color: CandyTheme.outline,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                CandyText(
                  label,
                  size: 10,
                  outlineWidth: 1.6,
                  dropShadow: false,
                  color: active ? Colors.white : Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SplashGate extends StatelessWidget {
  const SplashGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const CandyScaffold(
      showCurrency: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CandyMascot(size: 150),
            SizedBox(height: 6),
            CandyText(
              'POTION SORT',
              size: 34,
              outlineWidth: 4.5,
              letterSpacing: 1.6,
              color: CandyTheme.goldLight,
              height: 1.0,
            ),
            CandyText(
              'ADVENTURE',
              size: 16,
              outlineWidth: 3,
              letterSpacing: 5.5,
            ),
            SizedBox(height: 16),
            CandyText(
              'Lumen is lighting the burners…',
              size: 13,
              display: false,
              outlineWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
