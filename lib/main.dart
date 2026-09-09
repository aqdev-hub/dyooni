import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models/general_settings.dart';
import 'firebase_options.dart';
import 'logic/onboarding/onboarding_provider.dart';
import 'logic/settings/general_settings_provider.dart';
import 'logic/settings/locale_provider.dart';
import 'logic/settings/theme_mode_provider.dart';
import 'view/screens/app_lock/app_lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // REQUIRED before this compiles: run `flutterfire configure` in the project root to generate
  // `lib/firebase_options.dart` for your Firebase project. See README "خطوات ربط Firebase" —
  // this is step 1, before `flutter pub get`.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  /// `false` = مقفل، `true` = فُتح بنجاح خلال هذه الجلسة. تبدأ `false` عمدًا، وهذا وحده ما يجعل
  /// القفل يظهر عند بدء تشغيل التطبيق (Cold start) دون أي منطق تنقّل إضافي — انظر [_isLocked].
  bool _unlockedThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // إعادة القفل عند تصغير التطبيق (paused) إن كانت أي حماية مفعّلة — الخروج من التطبيق أو
    // تصغيره ثم العودة إليه يجب أن يعيد طلب المصادقة، لا مرة واحدة فقط عند أول تشغيل.
    if (state == AppLifecycleState.paused) {
      final settings = ref.read(generalSettingsProvider).value;
      if (settings != null && (settings.passwordEnabled || settings.biometricEnabled)) {
        setState(() => _unlockedThisSession = false);
      }
    }
  }

  bool _isLocked(AsyncValue<GeneralSettings> settingsAsync) {
    final settings = settingsAsync.value;
    if (settings == null) return false; // لم تُحمَّل الإعدادات بعد — لا تحجب المستخدم بشاشة قفل
    final lockEnabled = settings.passwordEnabled || settings.biometricEnabled;
    return lockEnabled && !_unlockedThisSession;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final settingsAsync = ref.watch(generalSettingsProvider);

    return MaterialApp.router(
      title: 'ديوني',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        if (_isLocked(settingsAsync)) {
          return AppLockScreen(onUnlocked: () => setState(() => _unlockedThisSession = true));
        }
        return child;
      },
    );
  }
}
