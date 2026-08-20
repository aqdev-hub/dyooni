import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../logic/auth/auth_provider.dart';
import '../../../logic/onboarding/onboarding_provider.dart';
import '../../widgets/shared/app_logo.dart';

/// Root route ('/'). Reads the onboarding-completed flag AND live Firebase auth state, then
/// redirects once — kept as a plain widget (not a GoRouter `redirect`) so both async reads have
/// a natural loading state to show instead of a blank screen during the decision.
class SplashGate extends ConsumerWidget {
  const SplashGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(onboardingCompletedProvider);
    final authAsync = ref.watch(authStateProvider);

    // Wait for both reads before deciding — resolves to a single AsyncValue<void> that carries
    // whichever error happened first, if any.
    final ready = onboardingAsync.hasValue && authAsync.hasValue;
    final failed = onboardingAsync.hasError || authAsync.hasError;

    if (ready || failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (failed) {
          // Either read failed — fail safe to onboarding rather than blocking app start.
          context.go('/onboarding');
          return;
        }
        final hasSeenOnboarding = onboardingAsync.value!;
        final isSignedIn = authAsync.value!;
        if (!hasSeenOnboarding) {
          context.go('/onboarding');
        } else {
          context.go(isSignedIn ? '/home' : '/login');
        }
      });
    }

    return const _SplashBody();
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppGradientBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(size: 96),
              SizedBox(height: 24),
              CircularProgressIndicator(color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}
