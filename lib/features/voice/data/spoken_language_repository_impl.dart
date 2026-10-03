import 'package:shared_preferences/shared_preferences.dart';

import '../domain/spoken_language_repository.dart';

const String _localeKey = 'voice.spoken_language';

class SpokenLanguageRepositoryImpl implements SpokenLanguageRepository {
  SpokenLanguageRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> read() async => _prefs.getString(_localeKey);

  @override
  Future<void> write(String localeId) async {
    await _prefs.setString(_localeKey, localeId);
  }
}
