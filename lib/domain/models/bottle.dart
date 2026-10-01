import 'layer.dart';
import 'potion_color.dart';

class PotionBottle {
  final int id;
  final int capacity;
  final List<PotionLayer> layers;
  bool locked;
  int? portalTwin;
  Essence? targetEssence;
  bool extra;

  PotionBottle({
    required this.id,
    required this.capacity,
    required this.layers,
    this.locked = false,
    this.portalTwin,
    this.targetEssence,
    this.extra = false,
  });

  bool get isEmpty => layers.isEmpty;
  bool get isFull => layers.length >= capacity;
  int get space => capacity - layers.length;

  PotionLayer? get top => layers.isEmpty ? null : layers.last;

  Essence? get topEssence {
    final t = top;
    if (t == null) return null;
    return t.visible;
  }

  int topRun() {
    if (layers.isEmpty) return 0;
    var n = 1;
    final color = layers.last.essence;
    for (var i = layers.length - 2; i >= 0; i--) {
      if (layers[i].essence == color &&
          !layers[i].blocked &&
          !layers.last.blocked) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  int countEssence(Essence e) {
    var n = 0;
    for (final l in layers) {
      if (l.essence == e) n++;
    }
    return n;
  }

  static int countEssenceIn(List<PotionBottle> bottles, Essence e) {
    var n = 0;
    for (final b in bottles) {
      n += b.countEssence(e);
    }
    return n;
  }

  bool get _isUniformPlayable {
    if (isEmpty) return false;
    if (layers.any((l) => l.blocked || l.hidden || l.essence.isSpecial)) {
      return false;
    }
    final c = layers.first.essence;
    return layers.every((l) => l.essence == c);
  }

  bool isSorted(List<PotionBottle> allBottles) {
    if (isEmpty) return true;
    if (layers.any((l) => l.blocked || l.hidden)) return false;
    final c = layers.first.essence;
    if (layers.any((l) => l.essence != c)) return false;
    if (c.isSpecial) {
      // Leftover wild/rainbow is not a finished brew. Poison may sit in its own vial.
      if (c == Essence.poison) {
        return layers.length == countEssenceIn(allBottles, c);
      }
      return false;
    }
    return isCompleteColor(allBottles);
  }

  /// Cork / sparkle state. A full vial must not cork while leftover drops
  /// of that color still sit in other vials (e.g. 5 red in 4-drop glass).
  /// A marked vial corks only with its target color; that color cannot cork elsewhere.
  /// Generated boards must not start in this state — LevelQa rejects it.
  bool isCompleteColor(List<PotionBottle> allBottles) {
    if (!_isUniformPlayable) return false;
    final c = layers.first.essence;
    if (targetEssence != null && c != targetEssence) return false;
    final homes = allBottles.where((b) => b.targetEssence == c);
    if (homes.isNotEmpty && targetEssence != c) return false;

    final total = countEssenceIn(allBottles, c);
    if (layers.length == total) return true;
    return isFull && total % capacity == 0;
  }

  PotionBottle copy() => PotionBottle(
    id: id,
    capacity: capacity,
    layers: layers.map((l) => l.copy()).toList(),
    locked: locked,
    portalTwin: portalTwin,
    targetEssence: targetEssence,
    extra: extra,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'cap': capacity,
    'layers': layers.map((l) => l.toJson()).toList(),
    'locked': locked,
    'portal': portalTwin,
    'target': targetEssence?.name,
    'extra': extra,
  };

  factory PotionBottle.fromJson(Map<String, dynamic> json) => PotionBottle(
    id: json['id'] as int,
    capacity: json['cap'] as int,
    layers: (json['layers'] as List)
        .map((e) => PotionLayer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    locked: json['locked'] == true,
    portalTwin: json['portal'] as int?,
    targetEssence: json['target'] == null
        ? null
        : Essence.values.byName(json['target'] as String),
    extra: json['extra'] == true,
  );
}
