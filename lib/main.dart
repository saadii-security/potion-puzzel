import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'data/progress_store.dart';
import 'presentation/root_shell.dart';
import 'services/analytics.dart';
import 'services/sfx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await ProgressStore.instance.load();
  await ProgressStore.instance.claimStreakIfNeeded();
  await Sfx.warm();
  Analytics.log('session_started');
  runApp(const PotionSortApp());
}

class PotionSortApp extends StatelessWidget {
  const PotionSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Potion Sort Adventure',
      debugShowCheckedModeBanner: false,
      theme: CandyTheme.light(),
      home: const RootShell(),
    );
  }
}
