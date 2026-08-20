import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_exception.dart';

/// Talks to local storage only. No business rules — the Repository decides what the flag means.
class OnboardingLocalDataSource {
  const OnboardingLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _seenKey = 'onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    try {
      return _prefs.getBool(_seenKey) ?? false;
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }

  Future<void> markOnboardingSeen() async {
    try {
      await _prefs.setBool(_seenKey, true);
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }
}
