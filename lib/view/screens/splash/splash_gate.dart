import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/interrupted_form_recovery.dart';
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
          return;
        }
        if (!isSignedIn) {
          context.go('/login');
          return;
        }

        context.go('/home');

        // FIX for the reported "camera kills the app process mid-capture, and the person just
        // lands back on an empty-looking Home having seemingly lost their in-progress entry"
        // bug. A create-flow draft (see FormDraftStorage) is written straight to disk via
        // SharedPreferences the instant the camera/gallery picker is about to open, and
        // SharedPreferences survives a full process kill even though the in-memory dialog that
        // held "Add Account"/"Add Transaction" does not (see AndroidManifest.xml's
        // "Camera-crash mitigation notes" for the fuller story on why that kill happens at all).
        // If one is still sitting there on a fresh cold start, it can only mean the person was
        // interrupted mid-entry — so they're taken straight back to finish it, where
        // AddAccountScreen/AddTransactionScreen's own `_restoreDraftIfAny()` (and, for a photo
        // the camera genuinely finished capturing right before the kill,
        // `_recoverLostCameraCapture()`) do the actual recovery.
        final recovery = findInterruptedFormDraft(ref.read(sharedPreferencesProvider));
        switch (recovery) {
          case ResumeAddAccount():
            context.push('/add-account');
          case ResumeAddTransaction(:final accountId):
            context.push('/add-transaction', extra: accountId);
          case null:
            break;
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
