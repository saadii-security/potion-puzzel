import '../models/bottle.dart';
import '../models/layer.dart';
import '../models/potion_color.dart';

/// Legal pours. Engine and solver call this — never fork a second pour path.
class PourRules {
  static int resolveDest(List<PotionBottle> bottles, int to) {
    if (to < 0 || to >= bottles.length) return to;
    final b = bottles[to];
    if (b.portalTwin == null) return to;
    final twin = bottles.indexWhere((x) => x.id == b.portalTwin);
    return twin >= 0 ? twin : to;
  }

  static bool canPour(List<PotionBottle> bottles, int from, int to) {
    if (from == to) return false;
    if (from < 0 || to < 0 || from >= bottles.length || to >= bottles.length) {
      return false;
    }
    final a = bottles[from];
    final b = bottles[resolveDest(bottles, to)];
    if (a.locked || b.locked || a.isEmpty || b.isFull) return false;
    if (a.isCompleteColor(bottles)) return false;
    final top = a.top;
    if (top == null || top.blocked) return false;

    if (b.targetEssence != null) {
      final incoming = top.essence;
      if (incoming.isSpecial) {
        if (b.isEmpty || b.topEssence != b.targetEssence) return false;
      } else if (incoming != b.targetEssence) {
        return false;
      }
    }

    if (b.isEmpty) return true;
    if (b.top!.blocked) return false;
    return top.essence.matches(b.top!.essence);
  }

  static int pour(List<PotionBottle> bottles, int from, int to) {
    final dest = resolveDest(bottles, to);
    final a = bottles[from];
    final b = bottles[dest];
    var n = a.topRun();
    if (n > b.space) n = b.space;
    if (n <= 0) return 0;
    final color = a.top!.essence;
    final chunk = <PotionLayer>[];
    for (var i = 0; i < n; i++) {
      chunk.add(a.layers.removeLast());
    }
    if ((color == Essence.wild || color == Essence.rainbow) &&
        b.top != null &&
        !b.top!.essence.isSpecial) {
      for (final layer in chunk) {
        layer.essence = b.top!.essence;
      }
    }
    b.layers.addAll(chunk.reversed);
    return n;
  }
}
