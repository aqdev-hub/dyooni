import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Saves/restores an in-progress form's field values as a small JSON blob in SharedPreferences —
/// a lightweight safety net against Android killing the app's process while a memory-heavy
/// native Activity (the camera) is in the foreground.
///
/// WHY THIS EXISTS: AddAccountScreen/AddTransactionScreen are opened via `showDialog(...)`, not
/// a GoRouter route — so when Android reclaims this app's process to free memory while the
/// native camera app is in the foreground (see AndroidManifest.xml's "Camera-crash mitigation
/// notes"), the Flutter engine restarts fresh at SplashGate → Home, and that dialog is gone for
/// good; there is no route history to resume into. A full, unconditional fix would mean
/// converting these dialogs into genuine restorable routes wired through Flutter's
/// RestorationMixin — a materially larger, separate change. This class is the pragmatic
/// alternative: it can't reopen the exact same screen automatically, but it DOES make sure the
/// person's typed data is waiting for them the next time they open the same form, instead of
/// silently vanishing.
///
/// Deliberately scoped to the CREATE flow only (never editing an existing account/transaction)
/// — see AddAccountScreen/AddTransactionScreen's own doc comments for why.
class FormDraftStorage {
  const FormDraftStorage(this._prefs, this._key);
  final SharedPreferences _prefs;
  final String _key;

  Future<void> save(Map<String, dynamic> fields) => _prefs.setString(_key, jsonEncode(fields));

  Map<String, dynamic>? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => _prefs.remove(_key);
}
