import 'package:flutter/services.dart';

import '../data/progress_store.dart';

class Haptics {
  static void tap() => _fire(HapticFeedback.selectionClick);
  static void pour() => _fire(HapticFeedback.lightImpact);
  static void vialDone() => _fire(HapticFeedback.mediumImpact);
  static void win() => _fire(HapticFeedback.mediumImpact);
  static void nope() => _fire(HapticFeedback.heavyImpact);

  static void _fire(Future<void> Function() fn) {
    if (!ProgressStore.instance.haptics) return;
    // Don't await: waiting on the haptic channel delayed the pour SFX.
    fn();
  }
}
