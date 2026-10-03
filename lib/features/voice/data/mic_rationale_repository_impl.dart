import 'package:shared_preferences/shared_preferences.dart';

import '../domain/mic_rationale_repository.dart';

const String _shownKey = 'voice.mic_rationale_shown';

class MicRationaleRepositoryImpl implements MicRationaleRepository {
  MicRationaleRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<bool> hasBeenShown() async => _prefs.getBool(_shownKey) ?? false;

  @override
  Future<void> markShown() async {
    await _prefs.setBool(_shownKey, true);
  }
}
