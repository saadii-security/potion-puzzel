import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:potion_sort/presentation/widgets/shell.dart';
import 'package:potion_sort/services/sfx.dart';

/// Audio never runs under a test binding, so nothing else would notice a clip
/// that was renamed, dropped, or written empty by tool/make_sfx.dart.
void main() {
  test('every sound effect ships as a real wav', () {
    for (final clip in Sfx.clips) {
      final file = File('assets/audio/$clip');
      expect(
        file.existsSync(),
        isTrue,
        reason: '$clip is missing from assets/audio',
      );
      expect(
        file.lengthSync(),
        greaterThan(1000),
        reason: '$clip is suspiciously small',
      );
    }
    expect(
      File('assets/audio/music.wav').existsSync(),
      isTrue,
      reason: 'looping theme is missing',
    );
  });

  test('combo praise stays on the last word after 15', () {
    expect(ComboBurst.praise, hasLength(15));
    expect(ComboBurst.wordFor(1), 'NICE!');
    expect(ComboBurst.wordFor(15), 'SWEET LEGEND!');
    expect(ComboBurst.wordFor(99), ComboBurst.wordFor(15));
    expect(ComboBurst.wordFor(7), isNot(ComboBurst.wordFor(1)));
  });
}
