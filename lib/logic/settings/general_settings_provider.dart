import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_lock_password.dart';
import '../../core/utils/biometric_auth_service.dart';
import '../../data/local/settings/general_settings_local_datasource.dart';
import '../../data/models/general_settings.dart';
import '../../data/repositories/settings/general_settings_repository.dart';
import '../../data/repositories/settings/general_settings_repository_impl.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

final generalSettingsLocalDataSourceProvider = Provider<GeneralSettingsLocalDataSource>(
  (ref) => GeneralSettingsLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

final generalSettingsRepositoryProvider = Provider<GeneralSettingsRepository>(
  (ref) => GeneralSettingsRepositoryImpl(ref.watch(generalSettingsLocalDataSourceProvider)),
);

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) => BiometricAuthService());

/// حالة "الإعدادات العامة" الحية — كل شاشة/منطق في التطبيق يقرأ من هنا مباشرة، فلا توجد نسخة
/// ثانية من الإعدادات في أي مكان (نفس مبدأ logic/settings/personal_data_provider.dart).
final generalSettingsProvider = AsyncNotifierProvider<GeneralSettingsController, GeneralSettings>(
  GeneralSettingsController.new,
);

class GeneralSettingsController extends AsyncNotifier<GeneralSettings> {
  @override
  Future<GeneralSettings> build() async {
    final saved = await ref.read(generalSettingsRepositoryProvider).get();
    return saved ?? const GeneralSettings();
  }

  Future<void> _update(GeneralSettings Function(GeneralSettings current) updater) async {
    final current = state.value ?? const GeneralSettings();
    final next = updater(current);
    await ref.read(generalSettingsRepositoryProvider).save(next);
    state = AsyncData(next);
  }

  /// يُستدعى فقط بعد أن تحقّقت الشاشة فعليًا من دعم الجهاز للبصمة وصادقت مرة واحدة — هذا
  /// المزوّد نفسه لا يفحص دعم الجهاز؛ ذلك مسؤولية الشاشة (انظر
  /// view/screens/settings/general_settings_screen.dart).
  Future<void> setBiometricEnabled(bool value) => _update((s) => s.copyWith(biometricEnabled: value));

  Future<void> setPassword(String rawPassword) =>
      _update((s) => s.copyWith(passwordEnabled: true, passwordHash: hashAppLockPassword(rawPassword)));

  Future<void> disablePassword() => _update((s) => s.copyWith(passwordEnabled: false, clearPasswordHash: true));

  /// مقارنة فورية بالتجزئة — تُستخدم من شاشة القفل لفتحها بمجرد وصول الرقم الصحيح، بلا زر تأكيد.
  bool verifyPassword(String rawPassword) {
    final hash = state.value?.passwordHash;
    return hash != null && hash == hashAppLockPassword(rawPassword);
  }

  Future<void> setPinMatchingAccountsOnSearch(bool value) =>
      _update((s) => s.copyWith(pinMatchingAccountsOnSearch: value));

  Future<void> setShowAmountInWordsWhileTyping(bool value) =>
      _update((s) => s.copyWith(showAmountInWordsWhileTyping: value));

  Future<void> setShowAccountCeilingOnAdd(bool value) => _update((s) => s.copyWith(showAccountCeilingOnAdd: value));

  Future<void> setVoiceNotificationsEnabled(bool value) =>
      _update((s) => s.copyWith(voiceNotificationsEnabled: value));

  Future<void> setShowTimeInOperations(bool value) => _update((s) => s.copyWith(showTimeInOperations: value));

  Future<void> setCreditLabel(String? value) => _update(
        (s) => s.copyWith(customCreditLabel: value, clearCreditLabel: value == null || value.trim().isEmpty),
      );

  Future<void> setDebitLabel(String? value) => _update(
        (s) => s.copyWith(customDebitLabel: value, clearDebitLabel: value == null || value.trim().isEmpty),
      );

  Future<void> setDefaultDirection(DefaultDirectionOption value) =>
      _update((s) => s.copyWith(defaultDirection: value));

  /// يُسجَّل بلا شرط في كل مرة يُحفظ فيها حساب/عملية — غير مضرّ إن لم يكن الخيار المُختار
  /// [DefaultDirectionOption.keepLast]، وهو الوحيد الذي يقرأ هذه القيمة فعليًا.
  Future<void> recordLastUsedDirection({required bool isCredit}) =>
      _update((s) => s.copyWith(lastUsedDirectionIsCredit: isCredit));

  Future<void> setAnnualClosingDate(DateTime? date) =>
      _update((s) => s.copyWith(annualClosingDate: date, clearAnnualClosingDate: date == null));
}
