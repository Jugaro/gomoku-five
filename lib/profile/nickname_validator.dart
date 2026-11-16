abstract final class NicknameValidator {
  static const int minLength = 3;
  static const int maxLength = 16;

  static final RegExp _allowedCharacters = RegExp(r'^[A-Za-zА-Яа-яЁё0-9_-]+$');

  static String normalize(String? raw) => raw?.trim() ?? '';

  static String? validate(String? raw) {
    final nickname = normalize(raw);
    if (nickname.isEmpty) {
      return 'Введите никнейм.';
    }
    if (nickname.runes.length < minLength) {
      return 'Никнейм должен содержать не менее $minLength символов.';
    }
    if (nickname.runes.length > maxLength) {
      return 'Никнейм должен содержать не более $maxLength символов.';
    }
    if (!_allowedCharacters.hasMatch(nickname)) {
      return 'Используйте только русские и латинские буквы, цифры, '
          'символы _ и -, без пробелов.';
    }
    return null;
  }
}
