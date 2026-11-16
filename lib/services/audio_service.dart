import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';

import '../settings/app_settings.dart';

class AudioService with WidgetsBindingObserver {
  AppSettings _settings = const AppSettings();
  AudioPlayer? _musicPlayer;
  AudioPlayer? _movePlayer;
  AudioPlayer? _winPlayer;
  Future<void> _musicOperation = Future<void>.value();
  Future<void> _soundOperation = Future<void>.value();
  int _musicRevision = 0;
  bool _musicStarted = false;
  bool _lifecyclePaused = false;
  bool _observerAttached = false;
  bool _disposed = false;

  void initialize() {
    if (_observerAttached || _disposed) return;
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _observerAttached = true;
    final state = binding.lifecycleState;
    _lifecyclePaused = state != null && state != AppLifecycleState.resumed;
  }

  void applySettings(AppSettings settings) {
    if (_disposed) return;
    _settings = settings;
    _syncMusic();
    if (!settings.soundEnabled) {
      _enqueueSound(() async {
        await _movePlayer?.stop();
        await _winPlayer?.stop();
      });
    }
  }

  void playMove() {
    if (_disposed || _lifecyclePaused || !_settings.soundEnabled) return;
    _enqueueSound(() async {
      final player = _movePlayer ??= AudioPlayer();
      await player.play(
        AssetSource('audio/move.wav'),
        mode: PlayerMode.lowLatency,
      );
    });
  }

  void playWin() {
    if (_disposed || _lifecyclePaused || !_settings.soundEnabled) return;
    _enqueueSound(() async {
      final player = _winPlayer ??= AudioPlayer();
      await player.play(AssetSource('audio/win.wav'));
    });
  }

  void pauseMusic() {
    if (_disposed || _lifecyclePaused) return;
    _lifecyclePaused = true;
    _syncMusic();
  }

  void resumeMusic() {
    if (_disposed || !_lifecyclePaused) return;
    _lifecyclePaused = false;
    _syncMusic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resumeMusic();
    } else {
      pauseMusic();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _musicRevision++;
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
    }
    await _musicOperation;
    await _soundOperation;
    await Future.wait([
      ?_musicPlayer?.dispose(),
      ?_movePlayer?.dispose(),
      ?_winPlayer?.dispose(),
    ]);
  }

  void _syncMusic() {
    final revision = ++_musicRevision;
    _musicOperation = _musicOperation.then((_) async {
      if (revision != _musicRevision || _disposed) return;
      try {
        if (!_settings.musicEnabled || _lifecyclePaused) {
          if (_musicStarted) await _musicPlayer?.pause();
          return;
        }
        final player = _musicPlayer ??= AudioPlayer();
        await player.setVolume(_settings.musicVolume.clamp(0, 1));
        if (revision != _musicRevision || _disposed) return;
        if (_musicStarted) {
          await player.resume();
        } else {
          await player.setReleaseMode(ReleaseMode.loop);
          if (revision != _musicRevision || _disposed) return;
          await player.play(AssetSource('audio/music.wav'));
          _musicStarted = true;
        }
      } catch (_) {
        if (!_musicStarted) _musicPlayer = null;
      }
    });
  }

  void _enqueueSound(Future<void> Function() operation) {
    _soundOperation = _soundOperation.then((_) async {
      if (_disposed) return;
      try {
        await operation();
      } catch (_) {}
    });
  }
}
