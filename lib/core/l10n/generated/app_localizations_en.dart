// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Duyoni';

  @override
  String get onboardingWelcomeTitle => 'Welcome to';

  @override
  String get onboardingWelcomeSubtitlePrefix =>
      'A smart app that helps you manage and track your debts easily and securely';

  @override
  String get onboardingTitle2 => 'Record your debts easily';

  @override
  String get onboardingBody2 =>
      'Add your debts and their details in seconds, right from the app';

  @override
  String get onboardingTitle3 => 'A smart assistant that understands you';

  @override
  String get onboardingBody3 =>
      'AI that helps you and double-checks the details before saving';

  @override
  String get onboardingTitle4 => 'Always safe and trusted';

  @override
  String get onboardingBody4 =>
      'Your data is protected and synced automatically across all your devices';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingPrevious => 'Previous';

  @override
  String get onboardingStart => 'Get Started';

  @override
  String get loginWelcomeTitle => '👋 Welcome back';

  @override
  String get loginSubtitle => 'Sign in to continue tracking your debts';

  @override
  String get loginIdentifierLabel => 'Email or phone number';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get loginButton => 'Sign In';

  @override
  String get orLoginWith => 'Or sign in with';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get createAccount => 'Create a new account';

  @override
  String get signupTitle => 'Create your account';

  @override
  String get signupSubtitle =>
      'Start your journey managing debts easily and securely';

  @override
  String get lastNameLabel => 'Last name';

  @override
  String get firstNameLabel => 'First name';

  @override
  String get emailLabel => 'Email';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get agreeToTermsPrefix => 'I agree to the ';

  @override
  String get termsAndConditions => 'Terms & Conditions';

  @override
  String get and => ' and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get signupButton => 'Create Account';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get loginSuccessMessage => 'Signed in successfully';

  @override
  String get signupSuccessMessage => 'Account created successfully';

  @override
  String get forgotPasswordEmailSentMessage =>
      'A reset link has been sent to your email';

  @override
  String get forgotPasswordDialogTitle => 'Reset Password';

  @override
  String get forgotPasswordDialogBody =>
      'Enter your email and we\'ll send you a password reset link';

  @override
  String get sendResetLink => 'Send Link';

  @override
  String get cancel => 'Cancel';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get networkUnreachable =>
      'Couldn\'t connect to the internet, please try again';

  @override
  String get unexpectedError => 'An unexpected error occurred';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get mustAcceptTerms => 'You must accept the Terms & Conditions';

  @override
  String get invalidCredentials => 'Incorrect email or password';

  @override
  String get emailAlreadyInUse => 'This email is already in use';

  @override
  String get tooManyRequests => 'Too many attempts, please try again later';

  @override
  String get userDisabled => 'This account has been disabled, contact support';

  @override
  String get userNotFound => 'No account found with this email';

  @override
  String get homeSearchHint => 'Search for an account...';

  @override
  String get homeTabClients => 'Clients';

  @override
  String get homeTabSuppliers => 'Suppliers';

  @override
  String get homeTabGeneral => 'General';

  @override
  String get homeAccountsCount => 'Accounts';

  @override
  String get homeTotalBalance => 'Total balance';

  @override
  String get homeTotalCredit => 'Total credit';

  @override
  String get homeTotalDebit => 'Total debit';

  @override
  String get homeSortNewest => 'Sort: Newest';

  @override
  String get homeAddAccount => 'Add account';

  @override
  String get homeEmptyAccounts =>
      'No accounts yet — tap \"Add account\" to start';

  @override
  String homeTransactionsCount(int count) {
    return '$count entries';
  }

  @override
  String get comingSoonMessage => 'This feature is still under development';

  @override
  String get drawerAdsRemoval => 'Perks & remove ads';

  @override
  String get drawerContactUs => 'Contact us';

  @override
  String get drawerFreePoints => 'Get free points';

  @override
  String get drawerPersonalData => 'Personal data';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get drawerAutoBalanceAlerts => 'Automatic balance alerts';

  @override
  String get drawerCategories => 'Categories';

  @override
  String get drawerCurrencies => 'Currencies';

  @override
  String get drawerLocalBackup => 'Backup & restore from device';

  @override
  String get drawerGoogleBackup => 'Backup/restore from Google';

  @override
  String get drawerGoogleDriveSync => 'Sync data to Google Drive';

  @override
  String get drawerSendDatabase => 'Send database';

  @override
  String get drawerShareApp => 'Share app';

  @override
  String get drawerRateApp => 'Rate app';

  @override
  String get drawerPrivacyPolicy => 'Privacy policy';

  @override
  String get drawerSupport => 'Support';

  @override
  String get drawerLogout => 'Log out';

  @override
  String get logoutConfirmTitle => 'Confirm log out';

  @override
  String get logoutConfirmBody => 'Are you sure you want to log out?';

  @override
  String get addAccountTitle => 'Add new account';

  @override
  String get accountNameLabel => 'Account name';

  @override
  String get amountLabel => 'Amount';

  @override
  String get currencyLabel => 'Currency';

  @override
  String get dateLabel => 'Date';

  @override
  String get detailsLabel => 'Details';

  @override
  String get directionCredit => 'Credit';

  @override
  String get directionDebit => 'Debit';

  @override
  String get saveButton => 'Save';

  @override
  String get invalidAmount => 'Enter a valid amount greater than zero';

  @override
  String get accountSavedSuccessMessage => 'Account saved successfully';

  @override
  String get currencyLocal => 'Local';

  @override
  String get currencyYER => 'Yemeni Rial';

  @override
  String get currencyUSD => 'US Dollar';

  @override
  String get currencySAR => 'Saudi Riyal';

  @override
  String get currencyAED => 'UAE Dirham';

  @override
  String get currencyEGP => 'Egyptian Pound';

  @override
  String get currencyKWD => 'Kuwaiti Dinar';

  @override
  String get categoryLabel => 'Category';

  @override
  String get categoryClient => 'Client';

  @override
  String get categorySupplier => 'Supplier';

  @override
  String get deleteAccountConfirmTitle => 'Delete account';

  @override
  String get deleteAccountConfirmBody =>
      'Are you sure you want to delete this account? This can\'t be undone';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get accountDeletedSuccessMessage => 'Account deleted successfully';

  @override
  String get addTransactionTitle => 'Add entry';

  @override
  String get transactionSavedSuccessMessage => 'Entry saved successfully';

  @override
  String get noTransactionsYet => 'No entries yet';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsGeneralSummary => 'General summary';

  @override
  String get reportsAccountsBreakdown => 'Accounts breakdown';

  @override
  String get reportsFilterAll => 'All';

  @override
  String get reportsExportPdf => 'Export PDF';

  @override
  String get reportsExportExcel => 'Export Excel';

  @override
  String get reportsShareWhatsapp => 'Share via WhatsApp';

  @override
  String get reportsEmpty => 'No data to show in the report';

  @override
  String get reportsOpenTooltip => 'Reports';

  @override
  String get reportGeneratedOn => 'Generated on:';

  @override
  String get reportBalanceHeader => 'Balance';

  @override
  String get reportEntriesHeader => 'Entries';

  @override
  String get reportStatusHeader => 'Status';

  @override
  String get exportFailedMessage => 'Export failed, please try again';

  @override
  String get switchToLightMode => 'Switch to light mode';

  @override
  String get switchToDarkMode => 'Switch to dark mode';

  @override
  String get saveAndExit => 'Save & exit';

  @override
  String get saveAndAddAnother => 'Save & add another';

  @override
  String get voiceRecordingTitle => 'Voice recording';

  @override
  String get voiceRecordingPlaceholder =>
      'Voice recording will be available here soon.';

  @override
  String get personalDataLogoLabel => 'Logo';

  @override
  String get personalDataChangeLogo => 'Change logo';

  @override
  String get personalDataDeleteLogo => 'Delete logo';

  @override
  String get personalDataReportHeaderNote =>
      'Details shown in the report header';

  @override
  String get nameArLabel => 'Name (Arabic)';

  @override
  String get nameEnLabel => 'Name (English)';

  @override
  String get addressArLabel => 'Address (Arabic)';

  @override
  String get addressEnLabel => 'Address (English)';

  @override
  String get personalDataAddSignature => 'Add signature';

  @override
  String get personalDataChooseStamp => 'Choose stamp';

  @override
  String get personalDataSavedMessage => 'Data saved successfully';

  @override
  String get personalDataFeatureNote =>
      'This info will be used in PDF report headers soon';

  @override
  String get signatureScreenTitle => 'Signature';

  @override
  String get signaturePromptLabel => 'Please sign here';

  @override
  String get signatureRetryLabel => 'Retry';

  @override
  String get signatureEmptyMessage => 'Please draw your signature first';
}
