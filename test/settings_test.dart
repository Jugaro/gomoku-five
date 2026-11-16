import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/services/audio_service.dart';
import 'package:gomoku5/settings/settings_controller.dart';
import 'package:gomoku5/ui/settings_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('значения по умолчанию безопасны', () {
    final controller = SettingsController();
    addTearDown(controller.dispose);

    expect(controller.value.boardScale, 56);
    expect(controller.value.soundEnabled, isTrue);
    expect(controller.value.musicEnabled, isTrue);
    expect(controller.value.musicVolume, 0.5);
    expect(controller.value.vibrationEnabled, isTrue);
    expect(controller.value.showCoordinates, isFalse);
    expect(controller.value.difficulty, AiDifficulty.medium);
  });

  test('все сеттеры обновляют состояние и сохраняют его', () async {
    final controller = SettingsController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setBoardScale(72);
    await controller.setSoundEnabled(false);
    await controller.setMusicEnabled(false);
    await controller.setMusicVolume(0.25);
    await controller.setVibrationEnabled(false);
    await controller.setShowCoordinates(true);
    await controller.setDifficulty(AiDifficulty.hard);

    expect(notifications, 7);
    final restored = SettingsController();
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.value, controller.value);
    expect(restored.value.boardScale, 72);
    expect(restored.value.soundEnabled, isFalse);
    expect(restored.value.musicEnabled, isFalse);
    expect(restored.value.musicVolume, 0.25);
    expect(restored.value.vibrationEnabled, isFalse);
    expect(restored.value.showCoordinates, isTrue);
    expect(restored.value.difficulty, AiDifficulty.hard);
  });

  test('повреждённые настройки заменяются и ограничиваются', () async {
    SharedPreferences.setMockInitialValues({
      'settings.boardScale': 500.0,
      'settings.soundEnabled': 'да',
      'settings.musicEnabled': 1,
      'settings.musicVolume': -4.0,
      'settings.vibrationEnabled': 'нет',
      'settings.showCoordinates': 1,
      'settings.difficulty': 'unknown',
    });
    final controller = SettingsController();
    addTearDown(controller.dispose);
    await controller.load();

    expect(controller.value.boardScale, 112);
    expect(controller.value.soundEnabled, isTrue);
    expect(controller.value.musicEnabled, isTrue);
    expect(controller.value.musicVolume, 0);
    expect(controller.value.vibrationEnabled, isTrue);
    expect(controller.value.showCoordinates, isFalse);
    expect(controller.value.difficulty, AiDifficulty.medium);

    await controller.setBoardScale(double.nan);
    await controller.setMusicVolume(double.infinity);
    expect(controller.value.boardScale, 56);
    expect(controller.value.musicVolume, 0.5);
  });

  test('быстрые изменения сохраняются в порядке вызовов', () async {
    final controller = SettingsController();
    addTearDown(controller.dispose);

    await Future.wait([
      controller.setBoardScale(30),
      controller.setBoardScale(90),
      controller.setBoardScale(64),
      controller.setMusicEnabled(false),
      controller.setMusicEnabled(true),
      controller.setMusicVolume(0.1),
      controller.setMusicVolume(0.8),
    ]);

    final restored = SettingsController();
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.value.boardScale, 64);
    expect(restored.value.musicEnabled, isTrue);
    expect(restored.value.musicVolume, 0.8);
  });

  testWidgets('экран меняет размер клетки, громкость и переключатели', (
    tester,
  ) async {
    final controller = await _pumpSettings(tester);

    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(2));
    tester.widget<Slider>(sliders.first).onChanged!(84);
    await tester.pump();
    expect(controller.value.boardScale, 84);
    expect(find.text('Размер клетки: 84 px'), findsOneWidget);

    tester.widget<Slider>(sliders.at(1)).onChanged!(0.75);
    await _tap(tester, find.text('Координаты на доске'));
    await _tap(tester, find.text('Музыка'));
    await _tap(tester, find.text('Звуки'));
    await _tap(tester, find.text('Вибрация'));

    expect(controller.value.musicVolume, 0.75);
    expect(controller.value.soundEnabled, isFalse);
    expect(controller.value.musicEnabled, isFalse);
    expect(controller.value.vibrationEnabled, isFalse);
    expect(controller.value.showCoordinates, isTrue);
    expect(tester.widget<Slider>(sliders.at(1)).onChanged, isNull);
  });

  testWidgets('можно выбрать сложность и прослушать звук хода', (tester) async {
    final audio = _FakeAudioService();
    final controller = await _pumpSettings(tester, audio: audio);

    await tester.tap(find.byType(DropdownButtonFormField<AiDifficulty>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сложный').last);
    await tester.pumpAndSettle();
    expect(controller.value.difficulty, AiDifficulty.hard);

    await _tap(tester, find.text('Прослушать звук хода'));
    expect(audio.moveCount, 1);
  });

  testWidgets('сброс подтверждается и возвращает дефолты', (tester) async {
    final controller = await _pumpSettings(tester);
    await controller.setBoardScale(96);
    await controller.setSoundEnabled(false);
    await controller.setDifficulty(AiDifficulty.easy);
    await tester.pump();

    await _tap(tester, find.text('Сбросить настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить настройки?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Сбросить'));
    await tester.pumpAndSettle();

    expect(controller.value, const AppSettings());
    expect(find.text('Настройки сброшены'), findsOneWidget);
  });

  test('музыка — слышимый бесшовный WAV-луп нужного формата', () async {
    final data = await rootBundle.load('assets/audio/music.wav');
    final samples = _checkWav(data);
    final duration = samples.length / 22050;
    expect(duration, inInclusiveRange(32, 48));

    final rms = sqrt(
      samples.fold<double>(0, (sum, sample) => sum + sample * sample) /
          samples.length,
    );
    final rmsDb = 20 * log(rms) / ln10;
    expect(rmsDb, inInclusiveRange(-20, -16));
    expect(rmsDb, closeTo(-18, 0.1));
    expect(
      samples.fold<double>(0, (maxValue, sample) {
        return max(maxValue, sample.abs());
      }),
      lessThanOrEqualTo(0.98),
    );

    final seamJump = (samples.first - samples.last).abs();
    expect(seamJump, lessThan(0.02));
  });

  test('короткие звуки хода и победы упакованы как локальные WAV', () async {
    final move = _checkWav(await rootBundle.load('assets/audio/move.wav'));
    final win = _checkWav(await rootBundle.load('assets/audio/win.wav'));
    expect(move.length / 22050, inInclusiveRange(0.08, 0.3));
    expect(win.length / 22050, inInclusiveRange(0.8, 2.5));
    expect(_rms(move), greaterThan(0.05));
    expect(_rms(win), greaterThan(0.05));
  });
}

Future<SettingsController> _pumpSettings(
  WidgetTester tester, {
  AudioService? audio,
}) async {
  final controller = SettingsController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsScope(
        controller: controller,
        child: SettingsScreen(audioService: audio),
      ),
    ),
  );
  return controller;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(finder);
  await tester.pump();
}

List<double> _checkWav(ByteData data) {
  expect(String.fromCharCodes(data.buffer.asUint8List(0, 4)), 'RIFF');
  expect(String.fromCharCodes(data.buffer.asUint8List(8, 4)), 'WAVE');
  expect(data.getUint16(20, Endian.little), 1);
  expect(data.getUint16(22, Endian.little), 1);
  expect(data.getUint32(24, Endian.little), 22050);
  expect(data.getUint16(32, Endian.little), 2);
  expect(data.getUint16(34, Endian.little), 16);
  expect(String.fromCharCodes(data.buffer.asUint8List(36, 4)), 'data');
  final byteCount = data.getUint32(40, Endian.little);
  expect(data.lengthInBytes, 44 + byteCount);
  return [
    for (var offset = 44; offset < data.lengthInBytes; offset += 2)
      data.getInt16(offset, Endian.little) / 32768,
  ];
}

double _rms(List<double> samples) {
  return sqrt(
    samples.fold<double>(0, (sum, sample) => sum + sample * sample) /
        samples.length,
  );
}

class _FakeAudioService extends AudioService {
  int moveCount = 0;

  @override
  void playMove() {
    moveCount++;
  }
}
