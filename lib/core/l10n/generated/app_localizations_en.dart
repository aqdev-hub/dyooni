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
  String get reportsEmpty => 'No data to show in the report';

  @override
  String get reportsOpenTooltip => 'Reports';

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
  String get voiceRecordingTitle => 'Recording in progress';

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

  @override
  String get voiceStartListening => 'Tap to start recording';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceProcessing => 'Understanding your words…';

  @override
  String get voiceConfirmTitle => 'Confirm details';

  @override
  String get voiceConfirmQuestion => 'Are these details correct?';

  @override
  String get voiceConfirm => 'Yes, save';

  @override
  String get voiceEdit => 'Edit';

  @override
  String get voiceRetry => 'Try again';

  @override
  String get voiceSaved => 'Entry saved successfully';

  @override
  String get voiceNeedAccount =>
      'I could not match an account name. Choose an account or try again.';

  @override
  String get voiceNeedAmount =>
      'I could not recognize a valid amount. Say the amount and try again.';

  @override
  String get voiceNeedDirection =>
      'I couldn\'t tell if this is credit or debit. Choose one.';

  @override
  String get voiceNoSpeechCaptured =>
      'I didn\'t capture any speech. Speak clearly near the microphone and try again.';

  @override
  String get voiceTranscriptLabel => 'Heard';

  @override
  String get voiceBluetoothConnecting => 'Connecting to Bluetooth headset…';

  @override
  String get voiceBluetoothConnected => 'Bluetooth headset connected';

  @override
  String get voiceBluetoothWaitingWakeWord => 'Waiting for “Dyooni”';

  @override
  String get voiceBluetoothWakeWordDetected => '“Dyooni” detected';

  @override
  String get voiceBluetoothListeningCommand => 'Listening for your command…';

  @override
  String get voiceBluetoothDisconnected =>
      'Bluetooth connection was interrupted';

  @override
  String get voiceBluetoothRetry => 'Retry';

  @override
  String get voiceNoSpeechPermission =>
      'Microphone or speech recognition is unavailable.';

  @override
  String get voiceNetworkError =>
      'A network error interrupted speech recognition.';

  @override
  String get voiceRecognitionError =>
      'Couldn\'t process the audio, please try speaking again.';

  @override
  String get voiceAudioUnavailable =>
      'The recording file is unavailable on this device';

  @override
  String get voiceDirectionLabel => 'Type';

  @override
  String get voiceAccountLabel => 'Account';

  @override
  String voiceRecordingDuration(int seconds) {
    return 'Recording: ${seconds}s';
  }

  @override
  String get voiceUseAppLanguage => 'Recognition language: English';

  @override
  String get voiceConfirmationListening => 'Listening for your confirmation…';

  @override
  String get voiceConfirmationHint =>
      'Say “yes” to save or “edit” to repeat the command';

  @override
  String get voiceConfirmationNotUnderstood =>
      'I did not understand the confirmation. Say “yes” or “edit”.';

  @override
  String get voiceContinueSpeakingHint => 'Keep talking';

  @override
  String get voiceIdleSubtitle => 'Speak, and we\'ll turn your words into text';

  @override
  String get voiceInfoTitle => 'About voice recording';

  @override
  String get voiceInfoBody =>
      'Tap the mic for a quick voice-recorded entry. Long-press to enable Bluetooth headset mode, where the app listens for the wake word \"Dyooni\" before recording a command.';

  @override
  String get voiceLanguageArabic => 'Arabic';

  @override
  String get voiceLanguageEnglish => 'English';

  @override
  String get voicePauseAction => 'Pause';

  @override
  String get voicePausedHint => 'You can continue recording';

  @override
  String get voicePausedTitle => 'Paused';

  @override
  String get voicePreparing => 'Getting ready…';

  @override
  String get voiceRecordAnother => 'Record another entry';

  @override
  String get voiceRecordingResumedTitle => 'Recording again';

  @override
  String get voiceRecordingTimerIdleLabel => 'Recording timer';

  @override
  String get voiceResumeAction => 'Resume';

  @override
  String get voiceSavingHint => 'Saving your data now';

  @override
  String get reportsSheetTitle => 'Reports';

  @override
  String get reportTypeTotalAmounts => 'Total amounts';

  @override
  String get reportTypeAllAmountsDetails => 'All amounts details';

  @override
  String get reportTypeMonthlyTotals => 'Monthly totals';

  @override
  String get reportTypeCategoryAndCurrencyTotals =>
      'Category and currency totals';

  @override
  String get reportTypeMonthlyDetailsCurrentCategory =>
      'Monthly details for current category';

  @override
  String get reportTypeStatement => 'Account statement';

  @override
  String get reportTypeMonthlyStatement => 'Monthly account statement';

  @override
  String get reportShowSortOptions => 'Show sort options';

  @override
  String get reportSetDateRange => 'Set date range';

  @override
  String get reportSortSheetTitle => 'Report sort order';

  @override
  String get reportSortDateAsc => 'Ascending by date';

  @override
  String get reportSortDateDesc => 'Descending by date';

  @override
  String get reportSortBalanceAsc => 'Ascending by balance';

  @override
  String get reportSortBalanceDesc => 'Descending by balance';

  @override
  String get reportSortNameAsc => 'Ascending by account name';

  @override
  String get reportSortNameDesc => 'Descending by account name';

  @override
  String get reportShareFormatTitle => 'Share file type';

  @override
  String get reportShareFormatExcel => 'Excel';

  @override
  String get reportShareFormatPdf => 'PDF';

  @override
  String get reportFeatureNotReadyMessage =>
      'This report type is still under development';

  @override
  String get voiceScreenTitle => 'Voice recording';

  @override
  String get voiceShortPressHint => 'Speak now, clearly';

  @override
  String get voiceLongPressHint => 'Long press for Bluetooth headset mode';

  @override
  String get imageOptionsTitle => 'Image options';

  @override
  String get imageSourceCamera => 'Camera';

  @override
  String get imageSourceGallery => 'Gallery';

  @override
  String get confirm => 'Confirm';

  @override
  String get calculatorTitle => 'Calculator';

  @override
  String get calculatorApply => 'Use result';

  @override
  String get editTransactionTitle => 'Edit entry';

  @override
  String get transactionUpdatedSuccessMessage => 'Entry updated successfully';

  @override
  String get transactionDeletedSuccessMessage => 'Entry deleted successfully';

  @override
  String get deleteTransactionConfirmTitle => 'Delete entry';

  @override
  String get deleteTransactionConfirmBody =>
      'Are you sure you want to delete this entry? This can\'t be undone';

  @override
  String get shareAction => 'Share';

  @override
  String get transferAction => 'Transfer';

  @override
  String get selectOne => 'Select';

  @override
  String get selectAllAction => 'Select all';

  @override
  String selectedCountLabel(int count) {
    return '$count selected';
  }

  @override
  String get deleteSelectedAccountsConfirmBody =>
      'Are you sure you want to delete the selected accounts? This can\'t be undone';

  @override
  String get deleteSelectedTransactionsConfirmBody =>
      'Are you sure you want to delete the selected entries? This can\'t be undone';

  @override
  String get editAccountTitle => 'Edit account';

  @override
  String get accountUpdatedSuccessMessage => 'Account updated successfully';

  @override
  String get transactionSearchHint => 'Search by amount, date, or details';

  @override
  String get callAction => 'Call';

  @override
  String get callFailedMessage => 'Couldn\'t open the phone app';

  @override
  String get contactPickFailedMessage => 'Couldn\'t open contacts';

  @override
  String get accountNameMustBeTwoWords =>
      'Enter at least a first and last name';

  @override
  String get attachmentRotateAction => 'Rotate';

  @override
  String get attachmentPresentLabel => '(has attachment)';

  @override
  String get navHome => 'Home';

  @override
  String get navVoice => 'Voice';

  @override
  String get searchNoResults => 'No entries match your search';

  @override
  String get accountNameAlreadyExists =>
      'This name is already used by another account';

  @override
  String get accountNameFullHint => 'Full account name (first and last name)';

  @override
  String get contactPermissionDeniedMessage =>
      'Couldn\'t access contacts — check the app\'s permissions';

  @override
  String get localBackupScreenTitle => 'Local Backup';

  @override
  String get localBackupExplanation =>
      'Creates a password-encrypted backup containing every account, entry, and personal-data field, saved automatically inside a \"Dyooni\" folder in your device\'s Downloads. Note: voice-recording audio files themselves are not included — only the text linked to that entry.';

  @override
  String get localBackupNeverLabel => 'No backup yet';

  @override
  String localBackupLastLabel(String date) {
    return 'Last backup: $date';
  }

  @override
  String get localBackupCreateButton => 'Create backup now';

  @override
  String get localBackupSetPasswordTitle => 'Backup password';

  @override
  String get localBackupSetPasswordHint =>
      'This password encrypts the file — keep it safe, you won\'t be able to restore your data without it';

  @override
  String get localBackupPasswordLabel => 'Password';

  @override
  String get localBackupConfirmPasswordLabel => 'Confirm password';

  @override
  String get localBackupPasswordTooShort =>
      'Password must be at least 5 letters and/or digits';

  @override
  String get localBackupPasswordsDontMatch => 'Passwords don\'t match';

  @override
  String get localBackupSavedToDownloadsMessage =>
      'Backup created and saved to the Dyooni folder in Downloads';

  @override
  String get localBackupSavedToAppFolderMessage =>
      'Backup created, but Downloads wasn\'t reachable on this device, so it was saved inside the app\'s own storage instead — use the share button to move it anywhere you like';

  @override
  String get localBackupShareLastTooltip => 'Share last backup';

  @override
  String get localBackupRestoreButton => 'Restore from file';

  @override
  String get localBackupRestoreConfirmTitle => 'Restore a backup';

  @override
  String get localBackupModeMerge => 'Merge with current data';

  @override
  String get localBackupModeMergeHint =>
      'Only adds or updates — nothing in your current data is deleted';

  @override
  String get localBackupModeReplace => 'Replace all data';

  @override
  String get localBackupModeReplaceHint =>
      'Permanently deletes all your current accounts and entries, then restores only what\'s in the file — this can\'t be undone';

  @override
  String get localBackupRestoredSuccessMessage => 'Data restored successfully';

  @override
  String get localBackupInvalidFileMessage =>
      'This file is not a valid Dyooni backup';

  @override
  String get localBackupIncompatibleMessage =>
      'This backup was made with a newer version of the app and can\'t be restored here';

  @override
  String get localBackupWrongPasswordMessage => 'Incorrect password';

  @override
  String get driveBackupScreenTitle => 'Google Drive Backup';

  @override
  String get driveBackupExplanation =>
      'The app automatically keeps the last 7 daily snapshots of your data on your own Google Drive, separate from normal syncing — these are historical restore points to protect against deletion or corruption, not a way to sync between your devices.';

  @override
  String get driveBackupStatusLabel => 'Status';

  @override
  String get driveBackupStatusEnabled => 'Enabled';

  @override
  String get driveBackupStatusNeedsAccount =>
      'Needs a connected Google account';

  @override
  String get driveBackupLastSuccessLabel => 'Last successful backup';

  @override
  String get driveBackupTodayLabel => 'Current version';

  @override
  String get driveBackupTodayReady => 'Today';

  @override
  String get driveBackupConnectButton => 'Connect Google account';

  @override
  String get driveBackupSaveNowButton => 'Save backup now';

  @override
  String get driveBackupSavedSuccessMessage => 'Backup saved successfully';

  @override
  String get driveBackupRestoreButton => 'Restore a backup';

  @override
  String get driveBackupNoAccountMessage =>
      'This requires connecting a Google account first';

  @override
  String get driveBackupListTitle => 'Drive Backups';

  @override
  String get driveBackupListEmpty => 'No Drive backups yet';

  @override
  String get driveBackupTypeDaily => 'Daily backup';

  @override
  String get driveBackupTypeManual => 'Manual backup';

  @override
  String get voiceModelDownloadingHint =>
      'Downloading the offline Arabic speech model for the first time (~300MB) — after this, voice commands work fully offline forever';

  @override
  String get voiceModelDownloadFailedMessage =>
      'Couldn\'t download the speech recognition model, check your internet connection and try again';
}
