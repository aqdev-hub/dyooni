import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../view/screens/accounts/account_details_screen.dart';
import '../../view/screens/accounts/add_account_screen.dart';
import '../../view/screens/auth/login_screen.dart';
import '../../view/screens/auth/signup_screen.dart';
import '../../view/screens/home/home_screen.dart';
import '../../view/screens/onboarding/onboarding_screen.dart';
import '../../view/screens/reports/reports_screen.dart';
import '../../view/screens/settings/personal_data_screen.dart';
import '../../view/screens/settings/signature_capture_screen.dart';
import '../../view/screens/splash/splash_gate.dart';
import '../../view/screens/transactions/add_transaction_screen.dart';
import '../../view/screens/voice/voice_command_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashGate()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/voice', builder: (_, state) => VoiceCommandScreen(bluetoothMode: state.extra as bool? ?? false)),
      GoRoute(path: '/add-account', builder: (_, __) => const AddAccountScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/personal-data', builder: (_, __) => const PersonalDataScreen()),
      GoRoute(path: '/signature-capture', builder: (_, __) => const SignatureCaptureScreen()),
      GoRoute(
        path: '/account-details',
        builder: (_, state) => AccountDetailsScreen(account: state.extra! as Account),
      ),
      GoRoute(
        path: '/add-transaction',
        builder: (_, state) => AddTransactionScreen(accountId: state.extra! as String),
      ),
    ],
  );
});
