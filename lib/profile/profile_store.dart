import 'package:shared_preferences/shared_preferences.dart';

import 'nickname_validator.dart';

class ProfileStore {
  static const String _nicknameKey = 'profile.nickname';

  Future<String?> loadNickname() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_nicknameKey);
  }

  Future<void> saveNickname(String nickname) async {
    final canonicalNickname = NicknameValidator.normalize(nickname);
    final error = NicknameValidator.validate(canonicalNickname);
    if (error != null) {
      throw ArgumentError.value(nickname, 'nickname', error);
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_nicknameKey, canonicalNickname);
  }

  Future<void> clearNickname() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_nicknameKey);
  }
}
