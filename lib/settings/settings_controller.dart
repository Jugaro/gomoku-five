import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

export 'app_settings.dart';

class SettingsController extends ChangeNotifier {
  static const double minBoardScale = 28;
  static const double maxBoardScale = 112;

  static const String _boardScaleKey = 'settings.boardScale';
  static const String _soundEnabledKey = 'settings.soundEnabled';
  static const String _musicEnabledKey = 'settings.musicEnabled';
  static const String _musicVolumeKey = 'settings.musicVolume';
  static const String _vibrationEnabledKey = 'settings.vibrationEnabled';
  static const String _showCoordinatesKey = 'settings.showCoordinates';
  static const String _difficultyKey = 'settings.difficulty';

  AppSettings _value = const AppSettings();
  Future<void> _pendingWrite = Future<void>.value();

  AppSettings get value => _value;

  Future<void> load() async {
    await _pendingWrite.catchError((_) {});
    final preferences = await SharedPreferences.getInstance();
    final loaded = AppSettings(
      boardScale: _validBoardScale(
        _doubleValue(preferences, _boardScaleKey, 56),
      ),
      soundEnabled: _boolValue(preferences, _soundEnabledKey, true),
      musicEnabled: _boolValue(preferences, _musicEnabledKey, true),
      musicVolume: _validVolume(
        _doubleValue(preferences, _musicVolumeKey, 0.5),
      ),
      vibrationEnabled: _boolValue(preferences, _vibrationEnabledKey, true),
      showCoordinates: _boolValue(preferences, _showCoordinatesKey, false),
      difficulty: _difficultyValue(preferences.get(_difficultyKey)),
    );
    if (loaded == _value) return;
    _value = loaded;
    notifyListeners();
  }

  Future<void> setBoardScale(double scale) {
    return _update(_value.copyWith(boardScale: _validBoardScale(scale)));
  }

  Future<void> setSoundEnabled(bool enabled) {
    return _update(_value.copyWith(soundEnabled: enabled));
  }

  Future<void> setMusicEnabled(bool enabled) {
    return _update(_value.copyWith(musicEnabled: enabled));
  }

  Future<void> setMusicVolume(double volume) {
    return _update(_value.copyWith(musicVolume: _validVolume(volume)));
  }

  Future<void> setVibrationEnabled(bool enabled) {
    return _update(_value.copyWith(vibrationEnabled: enabled));
  }

  Future<void> setShowCoordinates(bool enabled) {
    return _update(_value.copyWith(showCoordinates: enabled));
  }

  Future<void> setDifficulty(AiDifficulty difficulty) {
    return _update(_value.copyWith(difficulty: difficulty));
  }

  Future<void> reset() => _update(const AppSettings());

  Future<void> _update(AppSettings value) {
    if (value == _value) return Future<void>.value();
    _value = value;
    notifyListeners();
    final write = _pendingWrite.catchError((_) {}).then((_) => _write(value));
    _pendingWrite = write;
    return write;
  }

  Future<void> _write(AppSettings value) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setDouble(_boardScaleKey, value.boardScale),
      preferences.setBool(_soundEnabledKey, value.soundEnabled),
      preferences.setBool(_musicEnabledKey, value.musicEnabled),
      preferences.setDouble(_musicVolumeKey, value.musicVolume),
      preferences.setBool(_vibrationEnabledKey, value.vibrationEnabled),
      preferences.setBool(_showCoordinatesKey, value.showCoordinates),
      preferences.setString(_difficultyKey, value.difficulty.name),
    ]);
  }

  static double _doubleValue(
    SharedPreferences preferences,
    String key,
    double fallback,
  ) {
    final value = preferences.get(key);
    return value is num ? value.toDouble() : fallback;
  }

  static bool _boolValue(
    SharedPreferences preferences,
    String key,
    bool fallback,
  ) {
    final value = preferences.get(key);
    return value is bool ? value : fallback;
  }

  static double _validBoardScale(double value) {
    if (!value.isFinite) return 56;
    return value.clamp(minBoardScale, maxBoardScale).toDouble();
  }

  static double _validVolume(double value) {
    if (!value.isFinite) return 0.5;
    return value.clamp(0, 1).toDouble();
  }

  static AiDifficulty _difficultyValue(Object? value) {
    if (value is! String) return AiDifficulty.medium;
    return AiDifficulty.values.asNameMap()[value] ?? AiDifficulty.medium;
  }
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    SettingsController? controller,
    SettingsController? notifier,
    required super.child,
  }) : assert(
         controller != null || notifier != null,
         'Укажите контроллер настроек',
       ),
       super(notifier: notifier ?? controller);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope отсутствует в дереве виджетов');
    return scope!.notifier!;
  }
}
