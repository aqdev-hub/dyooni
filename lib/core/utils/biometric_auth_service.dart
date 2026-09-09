import 'package:local_auth/local_auth.dart';

/// غلاف رفيع حول `local_auth` — لا يعرف شيئًا عن معنى "الحماية" داخل التطبيق (ذلك في
/// logic/settings/general_settings_provider.dart)، فقط يجيب "هل الجهاز يدعم البصمة؟" و"صادِق
/// الآن" — نفس نمط الفصل بين data source "غبي" ومنطق أعلى المتّبع في كل هذا المشروع.
class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// `false` هنا صادقة تمامًا: إما أن الجهاز فعليًا لا يدعم أي بصمة/تعرّف بيومتري، أو أن فحص
  /// الدعم نفسه فشل — في كلتا الحالتين لا يجوز تفعيل الحماية بالبصمة.
  Future<bool> isDeviceSupported() async {
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      return deviceSupported && canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
