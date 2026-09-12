import '../../core/l10n/generated/app_localizations.dart';
import '../../data/models/general_settings.dart';

/// عبارة "دائن" (له) الفعلية المعروضة الآن — تعود تلقائيًا للنص الافتراضي من الترجمة
/// (l10n.directionCredit) إن لم يُخصَّص شيء في general_settings.
String resolveCreditLabel(AppLocalizations l10n, GeneralSettings? settings) {
  final custom = settings?.customCreditLabel?.trim();
  return (custom != null && custom.isNotEmpty) ? custom : l10n.directionCredit;
}

/// عبارة "مدين" (عليه) الفعلية المعروضة الآن.
String resolveDebitLabel(AppLocalizations l10n, GeneralSettings? settings) {
  final custom = settings?.customDebitLabel?.trim();
  return (custom != null && custom.isNotEmpty) ? custom : l10n.directionDebit;
}
