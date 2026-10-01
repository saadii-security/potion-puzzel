import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';

import '../data/progress_store.dart';

/// Fire-and-forget sound effects.
///
/// WAV clips play from an [AudioPool] that already has the file loaded, so
/// a tap is a resume, not a load. The water MP3 is also pre-decoded by a
/// low-latency pool; its generation token prevents late starts after a pour
/// was cancelled. Music pause/resume keeps the loop loaded.
class Sfx {
  static bool _available = true;
  static bool _warmed = false;

  static const clips = <String>[
    'tap.wav',
    'button.wav',
    'water_pouring.mp3',
    'nope.wav',
    'vial.wav',
    'win.wav',
    'fail.wav',
    'star.wav',
    'coin.wav',
    'combo2.wav',
    'combo3.wav',
    'combo4.wav',
    'combo5.wav',
    'combo6.wav',
    'combo7.wav',
    'combo8.wav',
    'combo9.wav',
    'combo10.wav',
    'combo11.wav',
    'combo12.wav',
    'combo13.wav',
    'combo14.wav',
    'combo15.wav',
  ];

  static final _pools = <String, AudioPool>{};
  static AudioPool? _pourPool;
  static StopFunction? _activePour;
  static int _pourGeneration = 0;
  static Future<void> _musicGate = Future<void>.value();

  static bool get _hasPlatform =>
      WidgetsBinding.instance is WidgetsFlutterBinding;

  static bool get _sfxOn =>
      _available && _hasPlatform && ProgressStore.instance.sfx;

  static Future<void> warm() async {
    if (_warmed || !_hasPlatform) return;
    _warmed = true;
    try {
      await FlameAudio.bgm.initialize();
      await FlameAudio.audioCache.loadAll([...clips, 'music.wav']);

      final ctx = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build();
      for (final clip in clips) {
        if (!clip.endsWith('.wav')) continue;
        try {
          _pools[clip] = await AudioPool.create(
            source: AssetSource(clip),
            audioCache: FlameAudio.audioCache,
            minPlayers: 1,
            maxPlayers: 2,
            playerMode: PlayerMode.lowLatency,
            audioContext: ctx,
          );
        } catch (_) {
          // A damaged optional clip must not mute every other effect.
        }
      }

      try {
        _pourPool = await AudioPool.create(
          source: AssetSource('water_pouring.mp3'),
          audioCache: FlameAudio.audioCache,
          minPlayers: 2,
          maxPlayers: 2,
          playerMode: PlayerMode.lowLatency,
          audioContext: ctx,
        );
      } catch (_) {
        // Other SFX and music remain available without the pour channel.
      }
      await music(ProgressStore.instance.music);
    } catch (_) {
      _available = false;
    }
  }

  static void tap() => _play('tap.wav', 0.45);
  static void button() => _play('button.wav', 0.5);
  static void nope() => _play('nope.wav', 0.45);
  static void vialDone() => _play('vial.wav', 0.65);
  static void win() => _play('win.wav', 0.85);
  static void fail() => _play('fail.wav', 0.6);
  static void star() => _play('star.wav', 0.6);
  static void coin() => _play('coin.wav', 0.6);
  static void combo(int tier) => _play('combo${tier.clamp(2, 15)}.wav', 0.7);

  static void pour() {
    final pool = _pourPool;
    if (!_sfxOn || pool == null) return;
    final generation = ++_pourGeneration;
    final previous = _activePour;
    _activePour = null;
    if (previous != null) unawaited(previous());
    unawaited(_startPour(pool, generation));
  }

  static void stopPour() {
    _pourGeneration++;
    final stop = _activePour;
    _activePour = null;
    if (stop != null) unawaited(stop());
  }

  static Future<void> _startPour(AudioPool pool, int generation) async {
    try {
      final stop = await pool.start(volume: 0.85);
      if (generation != _pourGeneration || !_sfxOn) {
        await stop();
        return;
      }
      _activePour = stop;
    } catch (_) {}
  }

  /// Pause keeps the loop loaded so turning Music back on is a resume, not a
  /// fresh open. Toggles are queued so a fast off→on cannot pause after resume.
  static Future<void> music(bool on) {
    _musicGate = _musicGate.then((_) => _musicNow(on)).catchError((_) {});
    return _musicGate;
  }

  static Future<void> _musicNow(bool on) async {
    if (!_available || !_hasPlatform) return;
    try {
      if (!on) {
        await FlameAudio.bgm.pause();
        return;
      }
      final state = FlameAudio.bgm.audioPlayer.state;
      if (state == PlayerState.paused) {
        await FlameAudio.bgm.resume();
      } else if (state != PlayerState.playing) {
        await FlameAudio.bgm.play('music.wav', volume: 0.28);
      }
    } catch (_) {
      if (on) {
        try {
          await FlameAudio.bgm.play('music.wav', volume: 0.28);
        } catch (_) {}
      }
    }
  }

  static void _play(String clip, double volume) {
    if (!_sfxOn) return;
    final pool = _pools[clip];
    if (pool == null) return;
    unawaited(_playPooled(pool, clip, volume));
  }

  static Future<void> _playPooled(
    AudioPool pool,
    String clip,
    double volume,
  ) async {
    try {
      final stop = await pool.start(volume: volume);
      Timer(_clipDuration(clip), () => unawaited(stop()));
    } catch (_) {
      // One failed effect must not mute every later sound.
    }
  }

  /// Low-latency players do not emit completion events. These generated clip
  /// lengths return players to their pools instead of leaking one per sound.
  static Duration _clipDuration(String clip) {
    if (clip == 'tap.wav') return const Duration(milliseconds: 200);
    if (clip == 'button.wav') return const Duration(milliseconds: 180);
    if (clip == 'nope.wav') return const Duration(milliseconds: 240);
    if (clip == 'coin.wav') return const Duration(milliseconds: 320);
    if (clip == 'vial.wav') return const Duration(milliseconds: 640);
    if (clip == 'star.wav') return const Duration(milliseconds: 720);
    if (clip.startsWith('combo')) return const Duration(milliseconds: 740);
    if (clip == 'fail.wav') return const Duration(milliseconds: 970);
    if (clip == 'win.wav') return const Duration(milliseconds: 1520);
    return const Duration(seconds: 2);
  }
}
