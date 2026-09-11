/// كيف يُختار الاتجاه (له/عليه) الافتراضي عند فتح شاشة إضافة حساب/عملية جديدة.
enum DefaultDirectionOption { credit, debit, keepLast }

/// كل إعدادات "الإعدادات العامة" — مخزّنة محليًا (SharedPreferences)، تخص هذا الجهاز فقط، وليست
/// جزءًا من النسخ الاحتياطي السحابي (نفس مبدأ PersonalData في هذا المشروع — انظر
/// data/models/personal_data.dart).
///
/// لا نصوص هنا إطلاقًا — هذا الملف بيانات بحتة، كل نص معروض للمستخدم يعيش في core/l10n/*.arb
/// (انظر view/screens/settings/general_settings_screen.dart).
class GeneralSettings {
  const GeneralSettings({
    this.biometricEnabled = false,
    this.passwordEnabled = false,
    this.passwordHash,
    this.pinMatchingAccountsOnSearch = true,
    this.showAmountInWordsWhileTyping = true,
    this.showAccountCeilingOnAdd = false,
    this.voiceNotificationsEnabled = true,
    this.showTimeInOperations = true,
    this.customCreditLabel,
    this.customDebitLabel,
    this.defaultDirection = DefaultDirectionOption.keepLast,
    this.lastUsedDirectionIsCredit,
    this.annualClosingDate,
  });

  final bool biometricEnabled;
  final bool passwordEnabled;

  /// تجزئة (hash) كلمة مرور قفل التطبيق — لا تُخزَّن أبدًا كنص صريح (انظر
  /// core/utils/app_lock_password.dart، بنفس مبدأ عدم تخزين أسرار خام كـ backup_crypto.dart).
  final String? passwordHash;

  final bool pinMatchingAccountsOnSearch;
  final bool showAmountInWordsWhileTyping;
  final bool showAccountCeilingOnAdd;
  final bool voiceNotificationsEnabled;
  final bool showTimeInOperations;

  /// عبارة "دائن"/"مدين" المخصّصة — `null` تعني "استخدم النص الافتراضي من الترجمة"
  /// (directionCredit/directionDebit في core/l10n).
  final String? customCreditLabel;
  final String? customDebitLabel;

  final DefaultDirectionOption defaultDirection;

  /// آخر اتجاه استُخدم فعليًا عند حفظ عملية — يُقرأ فقط عندما يكون [defaultDirection] هو
  /// [DefaultDirectionOption.keepLast].
  final bool? lastUsedDirectionIsCredit;

  /// تاريخ الإغلاق السنوي المُختار. حدّ معروف صريح لهذه الدفعة: يُحفظ التاريخ فعليًا، لكن لا
  /// يوجد بعد منطق "تنفيذ إغلاق" فعلي (أرشفة/تصفير أرصدة) — هذا يحتاج قرار عمل صريح (هل الإغلاق
  /// يؤرشف العمليات؟ يُصفّر الرصيد؟) قبل بنائه، تمامًا كما تُوثَّق حدود مشابهة في
  /// personal_data.dart لهذا المشروع.
  final DateTime? annualClosingDate;

  GeneralSettings copyWith({
    bool? biometricEnabled,
    bool? passwordEnabled,
    String? passwordHash,
    bool clearPasswordHash = false,
    bool? pinMatchingAccountsOnSearch,
    bool? showAmountInWordsWhileTyping,
    bool? showAccountCeilingOnAdd,
    bool? voiceNotificationsEnabled,
    bool? showTimeInOperations,
    String? customCreditLabel,
    bool clearCreditLabel = false,
    String? customDebitLabel,
    bool clearDebitLabel = false,
    DefaultDirectionOption? defaultDirection,
    bool? lastUsedDirectionIsCredit,
    DateTime? annualClosingDate,
    bool clearAnnualClosingDate = false,
  }) {
    return GeneralSettings(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      passwordEnabled: passwordEnabled ?? this.passwordEnabled,
      passwordHash: clearPasswordHash ? null : (passwordHash ?? this.passwordHash),
      pinMatchingAccountsOnSearch: pinMatchingAccountsOnSearch ?? this.pinMatchingAccountsOnSearch,
      showAmountInWordsWhileTyping: showAmountInWordsWhileTyping ?? this.showAmountInWordsWhileTyping,
      showAccountCeilingOnAdd: showAccountCeilingOnAdd ?? this.showAccountCeilingOnAdd,
      voiceNotificationsEnabled: voiceNotificationsEnabled ?? this.voiceNotificationsEnabled,
      showTimeInOperations: showTimeInOperations ?? this.showTimeInOperations,
      customCreditLabel: clearCreditLabel ? null : (customCreditLabel ?? this.customCreditLabel),
      customDebitLabel: clearDebitLabel ? null : (customDebitLabel ?? this.customDebitLabel),
      defaultDirection: defaultDirection ?? this.defaultDirection,
      lastUsedDirectionIsCredit: lastUsedDirectionIsCredit ?? this.lastUsedDirectionIsCredit,
      annualClosingDate: clearAnnualClosingDate ? null : (annualClosingDate ?? this.annualClosingDate),
    );
  }

  Map<String, dynamic> toJson() => {
        'biometricEnabled': biometricEnabled,
        'passwordEnabled': passwordEnabled,
        'passwordHash': passwordHash,
        'pinMatchingAccountsOnSearch': pinMatchingAccountsOnSearch,
        'showAmountInWordsWhileTyping': showAmountInWordsWhileTyping,
        'showAccountCeilingOnAdd': showAccountCeilingOnAdd,
        'voiceNotificationsEnabled': voiceNotificationsEnabled,
        'showTimeInOperations': showTimeInOperations,
        'customCreditLabel': customCreditLabel,
        'customDebitLabel': customDebitLabel,
        'defaultDirection': defaultDirection.name,
        'lastUsedDirectionIsCredit': lastUsedDirectionIsCredit,
        'annualClosingDate': annualClosingDate?.toIso8601String(),
      };

  factory GeneralSettings.fromJson(Map<String, dynamic> json) => GeneralSettings(
        biometricEnabled: json['biometricEnabled'] as bool? ?? false,
        passwordEnabled: json['passwordEnabled'] as bool? ?? false,
        passwordHash: json['passwordHash'] as String?,
        pinMatchingAccountsOnSearch: json['pinMatchingAccountsOnSearch'] as bool? ?? true,
        showAmountInWordsWhileTyping: json['showAmountInWordsWhileTyping'] as bool? ?? true,
        showAccountCeilingOnAdd: json['showAccountCeilingOnAdd'] as bool? ?? false,
        voiceNotificationsEnabled: json['voiceNotificationsEnabled'] as bool? ?? true,
        showTimeInOperations: json['showTimeInOperations'] as bool? ?? true,
        customCreditLabel: json['customCreditLabel'] as String?,
        customDebitLabel: json['customDebitLabel'] as String?,
        defaultDirection: DefaultDirectionOption.values.byName(json['defaultDirection'] as String? ?? 'keepLast'),
        lastUsedDirectionIsCredit: json['lastUsedDirectionIsCredit'] as bool?,
        annualClosingDate:
            json['annualClosingDate'] is String ? DateTime.tryParse(json['annualClosingDate'] as String) : null,
      );
}
