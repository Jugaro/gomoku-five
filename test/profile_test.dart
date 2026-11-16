import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku5/profile/nickname_validator.dart';
import 'package:gomoku5/profile/profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NicknameValidator', () {
    test('отклоняет null и пустой ник после trim', () {
      for (final raw in <String?>[null, '', '   ', '\t\n\r']) {
        expect(
          NicknameValidator.validate(raw),
          'Введите никнейм.',
          reason: 'Значение: $raw',
        );
      }
    });

    test('нормализует внешние пробелы и проверяет канонический ник', () {
      expect(NicknameValidator.normalize(null), isEmpty);
      expect(NicknameValidator.normalize(' \tЁж_А-9z\n '), 'Ёж_А-9z');
      expect(NicknameValidator.validate(' \tЁж_А-9z\n '), isNull);
    });

    test('принимает границы 3 и 16 символов', () {
      expect(NicknameValidator.validate('Абв'), isNull);
      expect(NicknameValidator.validate('Абвгдеёжзийклмно'), isNull);
      expect(NicknameValidator.validate('Player_123-XYZ'), isNull);
      expect(NicknameValidator.validate('Ёж_А-9z'), isNull);
    });

    test('отклоняет длину 2 и больше 16 символов', () {
      expect(
        NicknameValidator.validate('Аб'),
        'Никнейм должен содержать не менее 3 символов.',
      );
      expect(
        NicknameValidator.validate('Абвгдеёжзийклмноп'),
        'Никнейм должен содержать не более 16 символов.',
      );
    });

    test('отклоняет пробелы, управляющие символы и пунктуацию', () {
      for (final raw in [
        'Иг рок',
        'Иг\tрок',
        'Иг\nрок',
        'Иг\u0000рок',
        'abc!',
      ]) {
        expect(
          NicknameValidator.validate(raw),
          isNotNull,
          reason: 'Значение: $raw',
        );
      }
    });

    test('отклоняет emoji и алфавиты вне русского и латинского', () {
      for (final raw in ['Игрок😀', '🙂🙂🙂', '玩家123', 'لاعب123']) {
        expect(
          NicknameValidator.validate(raw),
          isNotNull,
          reason: 'Значение: $raw',
        );
      }
    });
  });

  group('ProfileStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('возвращает null, если ник ещё не сохранён', () async {
      expect(await ProfileStore().loadNickname(), isNull);
    });

    test('загружает ник из SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'profile.nickname': 'Лесной_Волк',
      });

      expect(await ProfileStore().loadNickname(), 'Лесной_Волк');
    });

    test('сохраняет trimmed ник и заменяет предыдущий', () async {
      final store = ProfileStore();

      await store.saveNickname('  Ёж_А-9z\t');
      expect(await store.loadNickname(), 'Ёж_А-9z');

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('profile.nickname'), 'Ёж_А-9z');

      await store.saveNickname('Новый-ник');
      expect(await ProfileStore().loadNickname(), 'Новый-ник');
    });

    test('не сохраняет некорректный ник и не затирает прежний', () async {
      final store = ProfileStore();
      await store.saveNickname('Камень');

      for (final nickname in [
        '   ',
        'Аб',
        'Абвгдеёжзийклмноп',
        'bad nick',
        'emoji😀',
      ]) {
        await expectLater(store.saveNickname(nickname), throwsArgumentError);
      }

      expect(await store.loadNickname(), 'Камень');
    });

    test('очищает сохранённый ник', () async {
      final store = ProfileStore();
      await store.saveNickname('Игрок');

      await store.clearNickname();

      expect(await store.loadNickname(), isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('profile.nickname'), isFalse);
    });
  });
}
