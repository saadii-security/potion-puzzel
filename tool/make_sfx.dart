// Generates the game's sound effects into assets/audio as 16-bit mono WAVs.
// Run: dart run tool/make_sfx.dart
//
// Everything is additive synthesis with exponential decay envelopes, which is
// what gives the bright marimba/bell timbre the candy theme wants. Tweak the
// numbers here and re-run rather than hand-editing binary assets.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 22050;

/// Bell-ish partials: strong fundamental, quiet upper harmonics.
const bell = <double>[1.0, 0.32, 0.12, 0.05];
const soft = <double>[1.0, 0.18];
const thick = <double>[1.0, 0.5, 0.3, 0.15];

class Track {
  Track(double seconds)
    : samples = List<double>.filled((seconds * sampleRate).round(), 0.0);

  final List<double> samples;

  void note({
    required double freq,
    required double dur,
    double at = 0,
    double amp = 0.6,
    double decay = 5.0,
    double? glideTo,
    List<double> harmonics = bell,
    double attack = 0.005,
    double vibratoHz = 0,
    double vibratoDepth = 0,
  }) {
    final start = (at * sampleRate).round();
    final n = (dur * sampleRate).round();
    // One phase accumulator per partial so glides stay click-free.
    final phases = List<double>.filled(harmonics.length, 0.0);

    for (var i = 0; i < n; i++) {
      final index = start + i;
      if (index < 0 || index >= samples.length) continue;
      final t = i / sampleRate;

      var f = glideTo == null ? freq : freq + (glideTo - freq) * (t / dur);
      if (vibratoHz > 0) {
        f *= 1 + vibratoDepth * sin(2 * pi * vibratoHz * t);
      }

      var env = exp(-decay * t);
      if (t < attack) env *= t / attack;

      var value = 0.0;
      for (var h = 0; h < harmonics.length; h++) {
        phases[h] += 2 * pi * f * (h + 1) / sampleRate;
        value += harmonics[h] * sin(phases[h]);
      }
      samples[index] += value * env * amp;
    }
  }

  /// Low-passed noise, used for the airy part of a pour.
  void noise({
    required double dur,
    double at = 0,
    double amp = 0.2,
    double decay = 6,
    double cutoff = 0.25,
    int seed = 7,
  }) {
    final rnd = Random(seed);
    final start = (at * sampleRate).round();
    final n = (dur * sampleRate).round();
    var last = 0.0;

    for (var i = 0; i < n; i++) {
      final index = start + i;
      if (index < 0 || index >= samples.length) continue;
      last += cutoff * ((rnd.nextDouble() * 2 - 1) - last);
      samples[index] += last * exp(-decay * (i / sampleRate)) * amp;
    }
  }

  /// Rising major arpeggio — the shared shape of every reward sound.
  void arpeggio(
    List<double> freqs, {
    double gap = 0.055,
    double dur = 0.42,
    double amp = 0.55,
    double decay = 5.5,
  }) {
    for (var i = 0; i < freqs.length; i++) {
      note(freq: freqs[i], at: gap * i, dur: dur, amp: amp, decay: decay);
    }
  }

  Uint8List toWav() {
    var peak = 0.0;
    for (final s in samples) {
      peak = max(peak, s.abs());
    }
    final gain = peak == 0 ? 0.0 : 0.89 / peak;

    // Fade the tail so nothing ends on a discontinuity.
    final fade = min(samples.length, (0.01 * sampleRate).round());
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      var v = samples[i] * gain;
      final fromEnd = samples.length - i;
      if (fromEnd < fade) v *= fromEnd / fade;
      pcm[i] = (v.clamp(-1.0, 1.0) * 32767).round();
    }

    final dataBytes = pcm.buffer.asUint8List();
    final out = BytesBuilder();
    void ascii(String s) => out.add(s.codeUnits);
    void u32(int v) => out.add(
      Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little),
    );
    void u16(int v) => out.add(
      Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little),
    );

    ascii('RIFF');
    u32(36 + dataBytes.length);
    ascii('WAVE');
    ascii('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2); // byte rate
    u16(2); // block align
    u16(16); // bits per sample
    ascii('data');
    u32(dataBytes.length);
    out.add(dataBytes);
    return out.toBytes();
  }
}

Track tap() =>
    Track(0.18)
      ..note(freq: 920, dur: 0.16, amp: 0.5, decay: 16, harmonics: soft);

Track button() => Track(0.16)
  ..note(
    freq: 340,
    glideTo: 760,
    dur: 0.13,
    amp: 0.55,
    decay: 14,
    harmonics: soft,
  );

Track nope() => Track(0.22)
  ..note(freq: 168, dur: 0.18, amp: 0.55, decay: 13, harmonics: thick)
  ..note(freq: 112, dur: 0.20, amp: 0.35, decay: 11, harmonics: thick);

Track vial() => Track(0.62)
  ..arpeggio([1046.5, 1318.5, 1568.0])
  ..note(freq: 261.6, dur: 0.4, amp: 0.22, decay: 8, harmonics: soft);

/// Escalating praise chords for combo 2..15. Each tier is a semitone above
/// the last so a long streak keeps climbing instead of looping the same five.
Track combo(int tier) {
  const base = 523.25; // C5
  final semis = (tier - 2).clamp(0, 13);
  double n(int s) => base * pow(2, s / 12);
  final root = n(semis);
  final chord = <double>[
    root,
    root * 5 / 4,
    root * 3 / 2,
    if (tier >= 8) root * 2,
    if (tier >= 12) root * 5 / 2,
  ];
  final track = Track(0.72)
    ..arpeggio(chord, gap: 0.04, dur: 0.48, decay: 5.0)
    ..note(freq: root / 4, dur: 0.38, amp: 0.26, decay: 7, harmonics: soft);
  if (tier >= 10) {
    track.note(freq: root * 4, at: 0.16, dur: 0.4, amp: 0.14, decay: 5);
  }
  return track;
}

Track win() => Track(1.5)
  ..arpeggio(
    [523.3, 659.3, 784.0, 1046.5],
    gap: 0.09,
    dur: 0.9,
    amp: 0.55,
    decay: 3.0,
  )
  ..note(freq: 1318.5, at: 0.42, dur: 1.0, amp: 0.32, decay: 2.6)
  ..note(freq: 1568.0, at: 0.42, dur: 1.0, amp: 0.26, decay: 2.6)
  ..note(freq: 2093.0, at: 0.60, dur: 0.85, amp: 0.20, decay: 3.0)
  ..note(freq: 130.8, dur: 0.7, amp: 0.24, decay: 5, harmonics: soft);

Track fail() => Track(0.95)
  ..note(
    freq: 392.0,
    at: 0.00,
    dur: 0.45,
    amp: 0.5,
    decay: 4.5,
    harmonics: soft,
  )
  ..note(
    freq: 329.6,
    at: 0.16,
    dur: 0.45,
    amp: 0.5,
    decay: 4.5,
    harmonics: soft,
  )
  ..note(
    freq: 261.6,
    at: 0.32,
    dur: 0.60,
    amp: 0.5,
    decay: 3.6,
    harmonics: soft,
  )
  ..note(
    freq: 246.9,
    at: 0.34,
    dur: 0.60,
    amp: 0.22,
    decay: 3.6,
    harmonics: soft,
  );

Track star() => Track(0.7)
  ..note(freq: 1760.0, dur: 0.6, amp: 0.5, decay: 4.2)
  ..note(freq: 2637.0, dur: 0.6, amp: 0.26, decay: 5.0);

/// Four-bar marimba loop over I-vi-IV-V. Deliberately sparse and quiet: it
/// plays under everything else forever, so it must not compete with the SFX.
Track music() {
  const bpm = 104.0;
  const beat = 60.0 / bpm;
  const bar = beat * 4;

  // Chord tones, low to high.
  const progression = <List<double>>[
    [261.63, 329.63, 392.00, 523.25], // C
    [220.00, 261.63, 329.63, 440.00], // Am
    [174.61, 220.00, 261.63, 349.23], // F
    [196.00, 246.94, 293.66, 392.00], // G
  ];
  const arp = <int>[0, 1, 2, 3, 2, 1, 0, 1];
  const melody = <List<double>>[
    // bar, beats offset, frequency, beats long
    [0, 0, 783.99, 2], [0, 2, 659.25, 2],
    [1, 0, 880.00, 2], [1, 2, 783.99, 2],
    [2, 0, 698.46, 2], [2, 2, 880.00, 2],
    [3, 0, 783.99, 1], [3, 1, 880.00, 1], [3, 2, 987.77, 2],
  ];

  final track = Track(bar * progression.length);

  for (var b = 0; b < progression.length; b++) {
    final chord = progression[b];
    final start = b * bar;

    for (var i = 0; i < arp.length; i++) {
      track.note(
        freq: chord[arp[i]] * 2,
        at: start + i * beat / 2,
        dur: beat,
        amp: 0.30,
        decay: 6.5,
      );
    }
    for (final beatIndex in [0, 2]) {
      track.note(
        freq: chord[0] / 2,
        at: start + beatIndex * beat,
        dur: beat * 1.6,
        amp: 0.34,
        decay: 2.6,
        harmonics: soft,
      );
    }
  }

  for (final m in melody) {
    track.note(
      freq: m[2],
      at: m[0] * bar + m[1] * beat,
      dur: m[3] * beat,
      amp: 0.26,
      decay: 2.2,
    );
  }
  return track;
}

Track coin() => Track(0.3)
  ..note(freq: 1568.0, dur: 0.14, amp: 0.5, decay: 11)
  ..note(freq: 2093.0, at: 0.06, dur: 0.2, amp: 0.42, decay: 9);

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);

  final sounds = <String, Track>{
    'tap': tap(),
    'button': button(),
    'nope': nope(),
    'vial': vial(),
    'win': win(),
    'fail': fail(),
    'star': star(),
    'coin': coin(),
    'music': music(),
    for (var tier = 2; tier <= 15; tier++) 'combo$tier': combo(tier),
  };

  sounds.forEach((name, track) {
    final file = File('${dir.path}/$name.wav');
    final bytes = track.toWav();
    file.writeAsBytesSync(bytes);
    stdout.writeln(
      '${file.path}  ${bytes.length} bytes  rms=${_verify(bytes).toStringAsFixed(3)}',
    );
  });
}

/// Re-reads a rendered clip: valid RIFF header, declared size matches, and the
/// audio is actually audible. Catches a silent or malformed render immediately.
double _verify(Uint8List bytes) {
  final ascii = String.fromCharCodes(bytes.sublist(0, 4));
  final wave = String.fromCharCodes(bytes.sublist(8, 12));
  if (ascii != 'RIFF' || wave != 'WAVE') {
    throw StateError('not a RIFF/WAVE file: $ascii/$wave');
  }

  final view = bytes.buffer.asByteData();
  final declared = view.getUint32(40, Endian.little);
  if (declared != bytes.length - 44) {
    throw StateError(
      'data chunk says $declared, file holds ${bytes.length - 44}',
    );
  }

  final pcm = bytes.buffer.asInt16List(44 ~/ 2, declared ~/ 2);
  var sum = 0.0;
  for (final s in pcm) {
    sum += (s / 32768) * (s / 32768);
  }
  final rms = sqrt(sum / pcm.length);
  if (rms < 0.01) throw StateError('clip is effectively silent (rms $rms)');
  return rms;
}
