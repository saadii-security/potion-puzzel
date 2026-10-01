import 'potion_color.dart';

class PotionLayer {
  Essence essence;
  bool frozen;
  bool crystal;
  bool hidden;
  bool bomb;
  bool lightning;

  PotionLayer({
    required this.essence,
    this.frozen = false,
    this.crystal = false,
    this.hidden = false,
    this.bomb = false,
    this.lightning = false,
  });

  Essence get visible => hidden ? Essence.mystery : essence;

  bool get blocked => frozen || crystal;

  PotionLayer copy() => PotionLayer(
    essence: essence,
    frozen: frozen,
    crystal: crystal,
    hidden: hidden,
    bomb: bomb,
    lightning: lightning,
  );

  Map<String, dynamic> toJson() => {
    'e': essence.name,
    'f': frozen,
    'c': crystal,
    'h': hidden,
    'b': bomb,
    'l': lightning,
  };

  factory PotionLayer.fromJson(Map<String, dynamic> json) => PotionLayer(
    essence: Essence.values.byName(json['e'] as String),
    frozen: json['f'] == true,
    crystal: json['c'] == true,
    hidden: json['h'] == true,
    bomb: json['b'] == true,
    lightning: json['l'] == true,
  );
}
