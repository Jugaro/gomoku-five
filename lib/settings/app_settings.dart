enum AiDifficulty { easy, medium, hard }

class AppSettings {
  const AppSettings({
    this.boardScale = 56,
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.musicVolume = 0.5,
    this.vibrationEnabled = true,
    this.showCoordinates = false,
    this.difficulty = AiDifficulty.medium,
  });

  final double boardScale;
  final bool soundEnabled;
  final bool musicEnabled;
  final double musicVolume;
  final bool vibrationEnabled;
  final bool showCoordinates;
  final AiDifficulty difficulty;

  AppSettings copyWith({
    double? boardScale,
    bool? soundEnabled,
    bool? musicEnabled,
    double? musicVolume,
    bool? vibrationEnabled,
    bool? showCoordinates,
    AiDifficulty? difficulty,
  }) {
    return AppSettings(
      boardScale: boardScale ?? this.boardScale,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.boardScale == boardScale &&
        other.soundEnabled == soundEnabled &&
        other.musicEnabled == musicEnabled &&
        other.musicVolume == musicVolume &&
        other.vibrationEnabled == vibrationEnabled &&
        other.showCoordinates == showCoordinates &&
        other.difficulty == difficulty;
  }

  @override
  int get hashCode => Object.hash(
    boardScale,
    soundEnabled,
    musicEnabled,
    musicVolume,
    vibrationEnabled,
    showCoordinates,
    difficulty,
  );
}
