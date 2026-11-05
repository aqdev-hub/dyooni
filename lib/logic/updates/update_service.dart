import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_links.dart';
import '../../core/utils/app_version.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import 'app_update.dart';

/// Result of one check. [failed] = couldn't reach/parse (offline, bad JSON) — distinct from
/// "you are up to date" so the manual button can say which.
class UpdateCheckResult {
  const UpdateCheckResult(this.decision, {this.failed = false});
  final UpdateDecision decision;
  final bool failed;
}

class UpdateService {
  UpdateService(this._prefs, {http.Client? client}) : _client = client ?? http.Client();

  final SharedPreferences _prefs;
  final http.Client _client;

  static const _lastCheckKey = 'update_last_check_ms';
  static const _dismissedBuildKey = 'update_dismissed_build';
  static const autoCheckInterval = Duration(hours: 24);

  InstalledVersion get installed => InstalledVersion.parse(kAppVersion);

  Future<UpdateCheckResult> check() async {
    final url = AppLinks.updateInfoUrl;
    if (url == null) return const UpdateCheckResult(UpdateDecision(UpdateKind.none, null), failed: true);
    try {
      final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        debugPrint('[update] HTTP ${res.statusCode}');
        return const UpdateCheckResult(UpdateDecision(UpdateKind.none, null), failed: true);
      }
      final release = RemoteRelease.tryParse(jsonDecode(utf8.decode(res.bodyBytes)));
      if (release == null) return const UpdateCheckResult(UpdateDecision(UpdateKind.none, null), failed: true);
      await _prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
      return UpdateCheckResult(decideUpdate(installed, release));
    } catch (e) {
      debugPrint('[update] check failed: $e');
      return const UpdateCheckResult(UpdateDecision(UpdateKind.none, null), failed: true);
    }
  }

  /// Startup check: at most once a day, and an optional update the person already dismissed is not
  /// shown again (a forced one always is).
  Future<UpdateDecision?> checkOnStartup() async {
    final last = _prefs.getInt(_lastCheckKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - last;
    if (age >= 0 && age < autoCheckInterval.inMilliseconds) return null;
    final result = await check();
    final d = result.decision;
    if (!d.available) return null;
    if (d.kind == UpdateKind.optional && _prefs.getInt(_dismissedBuildKey) == d.release!.build) return null;
    return d;
  }

  Future<void> dismiss(RemoteRelease release) => _prefs.setInt(_dismissedBuildKey, release.build);
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService(ref.watch(sharedPreferencesProvider)));
