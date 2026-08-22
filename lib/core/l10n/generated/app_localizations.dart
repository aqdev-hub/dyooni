import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// Confirmed brand name (user override, see project notes on the prior name-conflict flag)
  ///
  /// In ar, this message translates to:
  /// **'ديوني'**
  String get appName;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا بك في'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitlePrefix.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق ذكي يساعدك على إدارة ديونك ومتابعتها بسهولة وأمان'**
  String get onboardingWelcomeSubtitlePrefix;

  /// No description provided for @onboardingTitle2.
  ///
  /// In ar, this message translates to:
  /// **'سجل ديونك بسهولة'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In ar, this message translates to:
  /// **'أضف ديونك وتفاصيلها في ثوانٍ وبكل سهولة عبر التطبيق'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In ar, this message translates to:
  /// **'مساعد ذكي يفهمك'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In ar, this message translates to:
  /// **'ذكاء اصطناعي يساعدك ويتأكد من التفاصيل قبل حفظها'**
  String get onboardingBody3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In ar, this message translates to:
  /// **'آمن وموثوق دائمًا'**
  String get onboardingTitle4;

  /// No description provided for @onboardingBody4.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك محمية ومتزامنة تلقائيًا على جميع أجهزتك'**
  String get onboardingBody4;

  /// No description provided for @onboardingNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get onboardingNext;

  /// No description provided for @onboardingPrevious.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get onboardingPrevious;

  /// No description provided for @onboardingStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get onboardingStart;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'👋 مرحبًا بعودتك'**
  String get loginWelcomeTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل دخولك لمتابعة ديونك'**
  String get loginSubtitle;

  /// No description provided for @loginIdentifierLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو رقم الهاتف'**
  String get loginIdentifierLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginButton;

  /// No description provided for @orLoginWith.
  ///
  /// In ar, this message translates to:
  /// **'أو سجل دخولك باستخدام'**
  String get orLoginWith;

  /// No description provided for @noAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get noAccount;

  /// No description provided for @createAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get createAccount;

  /// No description provided for @signupTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ رحلتك في إدارة ديونك بسهولة وأمان'**
  String get signupSubtitle;

  /// No description provided for @lastNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم العائلة'**
  String get lastNameLabel;

  /// No description provided for @firstNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الأول'**
  String get firstNameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPasswordLabel;

  /// No description provided for @agreeToTermsPrefix.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على '**
  String get agreeToTermsPrefix;

  /// No description provided for @termsAndConditions.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get termsAndConditions;

  /// No description provided for @and.
  ///
  /// In ar, this message translates to:
  /// **' و'**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @signupButton.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get signupButton;

  /// No description provided for @haveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟'**
  String get haveAccount;

  /// No description provided for @loginSuccessMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدخول بنجاح'**
  String get loginSuccessMessage;

  /// No description provided for @signupSuccessMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الحساب بنجاح'**
  String get signupSuccessMessage;

  /// No description provided for @forgotPasswordEmailSentMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني'**
  String get forgotPasswordEmailSentMessage;

  /// No description provided for @forgotPasswordDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين كلمة المرور'**
  String get forgotPasswordDialogTitle;

  /// No description provided for @forgotPasswordDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور'**
  String get forgotPasswordDialogBody;

  /// No description provided for @sendResetLink.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرابط'**
  String get sendResetLink;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @fieldRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get fieldRequired;

  /// No description provided for @networkUnreachable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالإنترنت، حاول مرة أخرى'**
  String get networkUnreachable;

  /// No description provided for @unexpectedError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع'**
  String get unexpectedError;

  /// No description provided for @invalidEmail.
  ///
  /// In ar, this message translates to:
  /// **'صيغة البريد الإلكتروني غير صحيحة'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن تكون كلمة المرور 8 أحرف على الأقل'**
  String get passwordTooShort;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get passwordsDontMatch;

  /// No description provided for @mustAcceptTerms.
  ///
  /// In ar, this message translates to:
  /// **'يجب الموافقة على الشروط والأحكام'**
  String get mustAcceptTerms;

  /// No description provided for @invalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة'**
  String get invalidCredentials;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد الإلكتروني مستخدم بالفعل'**
  String get emailAlreadyInUse;

  /// No description provided for @tooManyRequests.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة جدًا، حاول لاحقًا'**
  String get tooManyRequests;

  /// No description provided for @userDisabled.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل هذا الحساب، تواصل مع الدعم'**
  String get userDisabled;

  /// No description provided for @userNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مرتبط بهذا البريد الإلكتروني'**
  String get userNotFound;

  /// No description provided for @homeSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث عن حساب...'**
  String get homeSearchHint;

  /// No description provided for @homeTabClients.
  ///
  /// In ar, this message translates to:
  /// **'عملاء'**
  String get homeTabClients;

  /// No description provided for @homeTabSuppliers.
  ///
  /// In ar, this message translates to:
  /// **'موردين'**
  String get homeTabSuppliers;

  /// No description provided for @homeTabGeneral.
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get homeTabGeneral;

  /// No description provided for @homeAccountsCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الحسابات'**
  String get homeAccountsCount;

  /// No description provided for @homeTotalBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الإجمالي'**
  String get homeTotalBalance;

  /// No description provided for @homeTotalCredit.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي له'**
  String get homeTotalCredit;

  /// No description provided for @homeTotalDebit.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي عليه'**
  String get homeTotalDebit;

  /// No description provided for @homeSortNewest.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب: الأحدث'**
  String get homeSortNewest;

  /// No description provided for @homeAddAccount.
  ///
  /// In ar, this message translates to:
  /// **'إضافة حساب'**
  String get homeAddAccount;

  /// No description provided for @homeEmptyAccounts.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حسابات بعد — اضغط \"إضافة حساب\" للبدء'**
  String get homeEmptyAccounts;

  /// No description provided for @homeTransactionsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} عملية'**
  String homeTransactionsCount(int count);

  /// No description provided for @comingSoonMessage.
  ///
  /// In ar, this message translates to:
  /// **'هذه الميزة قيد التطوير حاليًا'**
  String get comingSoonMessage;

  /// No description provided for @drawerAdsRemoval.
  ///
  /// In ar, this message translates to:
  /// **'المزايا وإزالة الإعلانات'**
  String get drawerAdsRemoval;

  /// No description provided for @drawerContactUs.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا'**
  String get drawerContactUs;

  /// No description provided for @drawerFreePoints.
  ///
  /// In ar, this message translates to:
  /// **'احصل على نقاط مجانية'**
  String get drawerFreePoints;

  /// No description provided for @drawerPersonalData.
  ///
  /// In ar, this message translates to:
  /// **'البيانات الشخصية'**
  String get drawerPersonalData;

  /// No description provided for @drawerSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get drawerSettings;

  /// No description provided for @drawerAutoBalanceAlerts.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات الرصيد التلقائية'**
  String get drawerAutoBalanceAlerts;

  /// No description provided for @drawerCategories.
  ///
  /// In ar, this message translates to:
  /// **'التصنيفات'**
  String get drawerCategories;

  /// No description provided for @drawerCurrencies.
  ///
  /// In ar, this message translates to:
  /// **'العملات'**
  String get drawerCurrencies;

  /// No description provided for @drawerLocalBackup.
  ///
  /// In ar, this message translates to:
  /// **'حفظ واسترجاع البيانات من الجهاز'**
  String get drawerLocalBackup;

  /// No description provided for @drawerGoogleBackup.
  ///
  /// In ar, this message translates to:
  /// **'حفظ/استرجاع البيانات من جوجل'**
  String get drawerGoogleBackup;

  /// No description provided for @drawerGoogleDriveSync.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة البيانات على جوجل درايف'**
  String get drawerGoogleDriveSync;

  /// No description provided for @drawerSendDatabase.
  ///
  /// In ar, this message translates to:
  /// **'إرسال قاعدة البيانات'**
  String get drawerSendDatabase;

  /// No description provided for @drawerShareApp.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة التطبيق'**
  String get drawerShareApp;

  /// No description provided for @drawerRateApp.
  ///
  /// In ar, this message translates to:
  /// **'قيّم التطبيق'**
  String get drawerRateApp;

  /// No description provided for @drawerPrivacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get drawerPrivacyPolicy;

  /// No description provided for @drawerSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم الفني'**
  String get drawerSupport;

  /// No description provided for @drawerLogout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get drawerLogout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد تسجيل الخروج'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد تسجيل الخروج؟'**
  String get logoutConfirmBody;

  /// No description provided for @addAccountTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة حساب جديد'**
  String get addAccountTitle;

  /// No description provided for @accountNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم الحساب'**
  String get accountNameLabel;

  /// No description provided for @amountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get amountLabel;

  /// No description provided for @currencyLabel.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get currencyLabel;

  /// No description provided for @dateLabel.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get dateLabel;

  /// No description provided for @detailsLabel.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get detailsLabel;

  /// No description provided for @directionCredit.
  ///
  /// In ar, this message translates to:
  /// **'له'**
  String get directionCredit;

  /// No description provided for @directionDebit.
  ///
  /// In ar, this message translates to:
  /// **'عليه'**
  String get directionDebit;

  /// No description provided for @saveButton.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get saveButton;

  /// No description provided for @invalidAmount.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغًا صحيحًا أكبر من صفر'**
  String get invalidAmount;

  /// No description provided for @accountSavedSuccessMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الحساب بنجاح'**
  String get accountSavedSuccessMessage;

  /// No description provided for @currencyLocal.
  ///
  /// In ar, this message translates to:
  /// **'محلي'**
  String get currencyLocal;

  /// No description provided for @currencyYER.
  ///
  /// In ar, this message translates to:
  /// **'ريال يمني'**
  String get currencyYER;

  /// No description provided for @currencyUSD.
  ///
  /// In ar, this message translates to:
  /// **'دولار أمريكي'**
  String get currencyUSD;

  /// No description provided for @currencySAR.
  ///
  /// In ar, this message translates to:
  /// **'ريال سعودي'**
  String get currencySAR;

  /// No description provided for @currencyAED.
  ///
  /// In ar, this message translates to:
  /// **'درهم إماراتي'**
  String get currencyAED;

  /// No description provided for @currencyEGP.
  ///
  /// In ar, this message translates to:
  /// **'جنيه مصري'**
  String get currencyEGP;

  /// No description provided for @currencyKWD.
  ///
  /// In ar, this message translates to:
  /// **'دينار كويتي'**
  String get currencyKWD;

  /// No description provided for @categoryLabel.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get categoryLabel;

  /// No description provided for @categoryClient.
  ///
  /// In ar, this message translates to:
  /// **'عميل'**
  String get categoryClient;

  /// No description provided for @categorySupplier.
  ///
  /// In ar, this message translates to:
  /// **'مورد'**
  String get categorySupplier;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد حذف هذا الحساب؟ لا يمكن التراجع عن هذا الإجراء'**
  String get deleteAccountConfirmBody;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @accountDeletedSuccessMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الحساب بنجاح'**
  String get accountDeletedSuccessMessage;

  /// No description provided for @addTransactionTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عملية'**
  String get addTransactionTitle;

  /// No description provided for @transactionSavedSuccessMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ العملية بنجاح'**
  String get transactionSavedSuccessMessage;

  /// No description provided for @noTransactionsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عمليات بعد'**
  String get noTransactionsYet;

  /// No description provided for @reportsTitle.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get reportsTitle;

  /// No description provided for @reportsGeneralSummary.
  ///
  /// In ar, this message translates to:
  /// **'الملخص العام'**
  String get reportsGeneralSummary;

  /// No description provided for @reportsAccountsBreakdown.
  ///
  /// In ar, this message translates to:
  /// **'تفصيل الحسابات'**
  String get reportsAccountsBreakdown;

  /// No description provided for @reportsFilterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get reportsFilterAll;

  /// No description provided for @reportsExportPdf.
  ///
  /// In ar, this message translates to:
  /// **'تصدير PDF'**
  String get reportsExportPdf;

  /// No description provided for @reportsExportExcel.
  ///
  /// In ar, this message translates to:
  /// **'تصدير Excel'**
  String get reportsExportExcel;

  /// No description provided for @reportsShareWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة عبر واتساب'**
  String get reportsShareWhatsapp;

  /// No description provided for @reportsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات لعرضها في التقرير'**
  String get reportsEmpty;

  /// No description provided for @reportsOpenTooltip.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get reportsOpenTooltip;

  /// No description provided for @reportGeneratedOn.
  ///
  /// In ar, this message translates to:
  /// **'تم الإنشاء بتاريخ:'**
  String get reportGeneratedOn;

  /// No description provided for @reportBalanceHeader.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get reportBalanceHeader;

  /// No description provided for @reportEntriesHeader.
  ///
  /// In ar, this message translates to:
  /// **'عدد العمليات'**
  String get reportEntriesHeader;

  /// No description provided for @reportStatusHeader.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get reportStatusHeader;

  /// No description provided for @exportFailedMessage.
  ///
  /// In ar, this message translates to:
  /// **'فشل التصدير، حاول مرة أخرى'**
  String get exportFailedMessage;

  /// No description provided for @switchToLightMode.
  ///
  /// In ar, this message translates to:
  /// **'التبديل للوضع الفاتح'**
  String get switchToLightMode;

  /// No description provided for @switchToDarkMode.
  ///
  /// In ar, this message translates to:
  /// **'التبديل للوضع الداكن'**
  String get switchToDarkMode;

  /// No description provided for @saveAndExit.
  ///
  /// In ar, this message translates to:
  /// **'حفظ وخروج'**
  String get saveAndExit;

  /// No description provided for @saveAndAddAnother.
  ///
  /// In ar, this message translates to:
  /// **'حفظ وإضافة عملية جديدة'**
  String get saveAndAddAnother;

  /// No description provided for @voiceRecordingTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل صوتي'**
  String get voiceRecordingTitle;

  /// No description provided for @voiceRecordingPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'ستتوفر ميزة التسجيل الصوتي هنا قريبًا.'**
  String get voiceRecordingPlaceholder;

  /// No description provided for @personalDataLogoLabel.
  ///
  /// In ar, this message translates to:
  /// **'الشعار'**
  String get personalDataLogoLabel;

  /// No description provided for @personalDataChangeLogo.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الشعار'**
  String get personalDataChangeLogo;

  /// No description provided for @personalDataDeleteLogo.
  ///
  /// In ar, this message translates to:
  /// **'حذف الشعار'**
  String get personalDataDeleteLogo;

  /// No description provided for @personalDataReportHeaderNote.
  ///
  /// In ar, this message translates to:
  /// **'البيانات التي تظهر في ترويسة التقارير'**
  String get personalDataReportHeaderNote;

  /// No description provided for @nameArLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإسم (عربي)'**
  String get nameArLabel;

  /// No description provided for @nameEnLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإسم (إنجليزي)'**
  String get nameEnLabel;

  /// No description provided for @addressArLabel.
  ///
  /// In ar, this message translates to:
  /// **'العنوان (عربي)'**
  String get addressArLabel;

  /// No description provided for @addressEnLabel.
  ///
  /// In ar, this message translates to:
  /// **'العنوان (إنجليزي)'**
  String get addressEnLabel;

  /// No description provided for @personalDataAddSignature.
  ///
  /// In ar, this message translates to:
  /// **'إضافة توقيع'**
  String get personalDataAddSignature;

  /// No description provided for @personalDataChooseStamp.
  ///
  /// In ar, this message translates to:
  /// **'اختيار الختم'**
  String get personalDataChooseStamp;

  /// No description provided for @personalDataSavedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ البيانات بنجاح'**
  String get personalDataSavedMessage;

  /// No description provided for @personalDataFeatureNote.
  ///
  /// In ar, this message translates to:
  /// **'سيتم استخدام هذه البيانات في رأس تقارير PDF قريبًا'**
  String get personalDataFeatureNote;

  /// No description provided for @signatureScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'التوقيع'**
  String get signatureScreenTitle;

  /// No description provided for @signaturePromptLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء التوقيع هنا'**
  String get signaturePromptLabel;

  /// No description provided for @signatureRetryLabel.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get signatureRetryLabel;

  /// No description provided for @signatureEmptyMessage.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء رسم التوقيع أولًا'**
  String get signatureEmptyMessage;

  /// No description provided for @voiceStartListening.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لبدء التسجيل'**
  String get voiceStartListening;

  /// No description provided for @voiceListening.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاستماع…'**
  String get voiceListening;

  /// No description provided for @voiceProcessing.
  ///
  /// In ar, this message translates to:
  /// **'جاري فهم كلامك…'**
  String get voiceProcessing;

  /// No description provided for @voiceConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد البيانات'**
  String get voiceConfirmTitle;

  /// No description provided for @voiceConfirmQuestion.
  ///
  /// In ar, this message translates to:
  /// **'هل هذه البيانات صحيحة؟'**
  String get voiceConfirmQuestion;

  /// No description provided for @voiceConfirm.
  ///
  /// In ar, this message translates to:
  /// **'نعم، احفظ'**
  String get voiceConfirm;

  /// No description provided for @voiceEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get voiceEdit;

  /// No description provided for @voiceCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get voiceCancel;

  /// No description provided for @voiceRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get voiceRetry;

  /// No description provided for @voiceSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ العملية بنجاح'**
  String get voiceSaved;

  /// No description provided for @voiceNeedAccount.
  ///
  /// In ar, this message translates to:
  /// **'لم أتعرف على اسم حساب مطابق. اختر حسابًا أو أعد المحاولة.'**
  String get voiceNeedAccount;

  /// No description provided for @voiceNeedAmount.
  ///
  /// In ar, this message translates to:
  /// **'لم أتعرف على مبلغ صحيح. قل المبلغ ثم أعد المحاولة.'**
  String get voiceNeedAmount;

  /// No description provided for @voiceTranscriptLabel.
  ///
  /// In ar, this message translates to:
  /// **'ما تم سماعه'**
  String get voiceTranscriptLabel;

  /// No description provided for @voiceBluetoothConnecting.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاتصال بسماعة البلوتوث…'**
  String get voiceBluetoothConnecting;

  /// No description provided for @voiceBluetoothConnected.
  ///
  /// In ar, this message translates to:
  /// **'تم الاتصال بسماعة البلوتوث'**
  String get voiceBluetoothConnected;

  /// No description provided for @voiceBluetoothWaitingWakeWord.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار كلمة «ديوني»'**
  String get voiceBluetoothWaitingWakeWord;

  /// No description provided for @voiceBluetoothWakeWordDetected.
  ///
  /// In ar, this message translates to:
  /// **'تم اكتشاف كلمة «ديوني»'**
  String get voiceBluetoothWakeWordDetected;

  /// No description provided for @voiceBluetoothListeningCommand.
  ///
  /// In ar, this message translates to:
  /// **'الاستماع للأمر…'**
  String get voiceBluetoothListeningCommand;

  /// No description provided for @voiceBluetoothDisconnected.
  ///
  /// In ar, this message translates to:
  /// **'انقطع اتصال البلوتوث'**
  String get voiceBluetoothDisconnected;

  /// No description provided for @voiceBluetoothRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get voiceBluetoothRetry;

  /// No description provided for @voiceNoSpeechPermission.
  ///
  /// In ar, this message translates to:
  /// **'تعذر الوصول إلى الميكروفون أو التعرف على الكلام.'**
  String get voiceNoSpeechPermission;

  /// No description provided for @voiceAudioRecording.
  ///
  /// In ar, this message translates to:
  /// **'التسجيل الأصلي'**
  String get voiceAudioRecording;

  /// No description provided for @voiceAudioUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'ملف التسجيل غير متوفر على هذا الجهاز'**
  String get voiceAudioUnavailable;

  /// No description provided for @voiceDirectionLabel.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get voiceDirectionLabel;

  /// No description provided for @voiceAccountLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get voiceAccountLabel;

  /// No description provided for @voiceRecordingDuration.
  ///
  /// In ar, this message translates to:
  /// **'مدة التسجيل: {seconds} ث'**
  String voiceRecordingDuration(int seconds);

  /// No description provided for @voiceBluetoothMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع البلوتوث'**
  String get voiceBluetoothMode;

  /// No description provided for @voiceUseAppLanguage.
  ///
  /// In ar, this message translates to:
  /// **'لغة التعرف: العربية'**
  String get voiceUseAppLanguage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
